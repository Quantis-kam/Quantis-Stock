import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import '../constants/app_constants.dart';
import 'server_discovery_models.dart';

/// Inspecte les interfaces IPv4 actives du téléphone/PC (Point d'accès, Wi-Fi, USB, VPN).
Future<List<LocalNetworkInfo>> getLocalNetworks() async {
  final result = <LocalNetworkInfo>[];
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );

    for (final iface in interfaces) {
      final name = iface.name.toLowerCase();
      if (_isIgnoredVirtualInterface(name)) continue;

      for (final addr in iface.addresses) {
        final ip = addr.address;
        if (addr.isLoopback ||
            ip.startsWith('127.') ||
            ip.startsWith('169.254.') ||
            ip.startsWith('172.17.')) {
          continue;
        }
        final prefix = _subnetPrefix24(ip);
        if (prefix == null) continue;

        final isVpn = _isVpnInterface(name);
        final isCellular = !isVpn && _isCellularInterface(name);
        final isHotspot = !isVpn && !isCellular && _isHotspotLikely(name, ip);

        result.add(LocalNetworkInfo(
          interfaceName: iface.name,
          ip: ip,
          subnetPrefix: prefix,
          isHotspotLikely: isHotspot,
          isCellular: isCellular,
          isVpn: isVpn,
        ));
      }
    }
  } catch (_) {}

  // Priorité : Point d'accès / Tethering -> Wi-Fi/LAN -> VPN/Cellulaire (info diagnostic)
  result.sort((a, b) {
    int rank(LocalNetworkInfo i) {
      if (i.isHotspotLikely) return 0;
      if (i.isScannableLan) return 1;
      if (i.isVpn) return 2;
      return 3;
    }

    return rank(a).compareTo(rank(b));
  });

  return result;
}

/// Vérifie qu'une URL ou IP héberge bien Quantis Stock API via `/health`.
Future<DiscoveredServer?> verifyServer(
  String urlOrIp, {
  Duration timeout = const Duration(seconds: 3),
  String source = 'direct',
  String? hostname,
}) async {
  final apiUrl = ApiConstants.normalizeApiUrl(urlOrIp);
  final uri = Uri.tryParse(apiUrl);
  if (uri == null || uri.host.isEmpty) return null;

  final sw = Stopwatch()..start();
  final dio = Dio(BaseOptions(
    connectTimeout: timeout,
    receiveTimeout: timeout,
  ));

  try {
    final res = await dio.get('$apiUrl/health');
    sw.stop();
    if (res.statusCode == 200 && _isQuantisHealthPayload(res.data)) {
      return DiscoveredServer(
        apiUrl: apiUrl,
        ip: uri.host,
        port: uri.hasPort ? uri.port : ApiConstants.defaultApiPort,
        source: source,
        hostname: hostname,
        latencyMs: sw.elapsedMilliseconds,
      );
    }
  } catch (_) {
    // Repli /auth/health pour rétrocompatibilité
    try {
      final res2 = await dio.get('$apiUrl/auth/health');
      sw.stop();
      if (res2.statusCode == 200 && _isQuantisHealthPayload(res2.data)) {
        return DiscoveredServer(
          apiUrl: apiUrl,
          ip: uri.host,
          port: uri.hasPort ? uri.port : ApiConstants.defaultApiPort,
          source: source,
          hostname: hostname,
          latencyMs: sw.elapsedMilliseconds,
        );
      }
    } catch (_) {}
  }
  return null;
}

/// Pipeline multi-couches de découverte automatique du serveur Quantis Stock :
/// 1. Sondage ultra-rapide des URL prioritaires (actuelle, récentes, USB ADB 127.0.0.1)
/// 2. Découverte UDP bidirectionnelle (sonde active sur chaque interface + écoute balise PC)
///    EN PARALLÈLE avec la table ARP locale (/proc/net/arp)
/// 3. Scan TCP parallèle port 8080 sur les VRAIS sous-réseaux actifs du téléphone (Hotspot/Wi-Fi)
Future<DiscoveryResult> discoverServer({
  List<String> priorityUrls = const [],
  void Function(String status)? onStatus,
  Duration udpWindow = const Duration(milliseconds: 2400),
  bool scanSubnets = true,
}) async {
  final allInterfaces = await getLocalNetworks();
  final lanInterfaces = allInterfaces.where((i) => i.isScannableLan).toList();
  final hasActiveVpn = allInterfaces.any((i) => i.isVpn);
  final ownIps = allInterfaces.map((i) => i.ip).toSet();

  // ── Couche 1 : Vérification rapide des URL prioritaires & USB ADB ─────────
  onStatus?.call('Vérification des adresses récentes et câble USB...');
  final quickCandidates = <String>{
    ...priorityUrls
        .where((u) => u.trim().isNotEmpty)
        .map(ApiConstants.normalizeApiUrl),
    'http://127.0.0.1:${ApiConstants.defaultApiPort}/api/v1',
    if (!ApiConstants.isMobilePlatform)
      'http://localhost:${ApiConstants.defaultApiPort}/api/v1',
  };

  final quickMatch = await _checkUrlBatchFast(quickCandidates.toList());
  if (quickMatch != null) {
    return DiscoveryResult(
      server: quickMatch,
      localInterfaces: allInterfaces,
      hasActiveVpn: hasActiveVpn,
    );
  }

  // ── Couche 2 : Découverte UDP (sonde active + balise passerelle PC) + ARP ─
  final lanSummary = lanInterfaces.isNotEmpty
      ? lanInterfaces.map((i) => '${i.subnetPrefix}.x').toSet().join(', ')
      : 'réseau local';
  onStatus?.call('Auto-découverte UDP sur $lanSummary...');

  final phase2Completer = Completer<DiscoveredServer?>();
  void completePhase2(DiscoveredServer? found) {
    if (found != null && !phase2Completer.isCompleted) {
      phase2Completer.complete(found);
    }
  }

  // Lancer ARP + UDP en parallèle — le premier serveur vérifié gagne instantanément
  final arpFuture = _discoverViaArp(ownIps).then((s) {
    completePhase2(s);
    return s;
  });
  final udpFuture = _discoverViaUdp(lanInterfaces, ownIps, udpWindow).then((s) {
    completePhase2(s);
    return s;
  });

  // Attendre soit le premier trouvé, soit la fin des deux tâches
  final allDone = Future.wait([arpFuture, udpFuture]).then((results) {
    if (!phase2Completer.isCompleted) {
      final matches = results.whereType<DiscoveredServer>().toList();
      phase2Completer.complete(matches.isNotEmpty ? matches.first : null);
    }
  });

  final phase2Found = await phase2Completer.future;
  if (phase2Found != null) {
    unawaited(allDone);
    return DiscoveryResult(
      server: phase2Found,
      localInterfaces: allInterfaces,
      hasActiveVpn: hasActiveVpn,
    );
  }
  await allDone;

  // ── Couche 3 : Scan TCP parallèle port 8080 sur les sous-réseaux réels ────
  if (scanSubnets) {
    final scanFound = await _scanSubnetsTcp(lanInterfaces, ownIps, onStatus);
    if (scanFound != null) {
      return DiscoveryResult(
        server: scanFound,
        localInterfaces: allInterfaces,
        hasActiveVpn: hasActiveVpn,
      );
    }
  }

  return DiscoveryResult(
    server: null,
    localInterfaces: allInterfaces,
    hasActiveVpn: hasActiveVpn,
  );
}

Future<DiscoveredServer?> _checkUrlBatchFast(List<String> urls) async {
  if (urls.isEmpty) return null;

  final results = await Future.wait(urls.map((rawUrl) async {
    final url = ApiConstants.normalizeApiUrl(rawUrl);
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return null;
    final port = uri.hasPort ? uri.port : ApiConstants.defaultApiPort;

    final tcpOk = await _fastTcpOpen(
      uri.host,
      port,
      const Duration(milliseconds: 450),
    );
    if (!tcpOk) return null;

    final source = (uri.host == '127.0.0.1' && ApiConstants.isMobilePlatform)
        ? 'usb'
        : 'direct';
    return verifyServer(
      url,
      timeout: const Duration(milliseconds: 1200),
      source: source,
    );
  }));

  final matches = results.whereType<DiscoveredServer>().toList();
  return matches.isNotEmpty ? matches.first : null;
}

Future<DiscoveredServer?> _discoverViaArp(Set<String> ownIps) async {
  final neighbors = await _readArpNeighbors();
  final candidates = neighbors.where((ip) => !ownIps.contains(ip)).toList();
  if (candidates.isEmpty) return null;

  final openIps = <String>[];
  await Future.wait(candidates.map((ip) async {
    if (await _fastTcpOpen(ip, ApiConstants.defaultApiPort, const Duration(milliseconds: 450))) {
      openIps.add(ip);
    }
  }));

  for (final ip in openIps) {
    final verified = await verifyServer(
      'http://$ip:${ApiConstants.defaultApiPort}/api/v1',
      timeout: const Duration(milliseconds: 1500),
      source: 'arp',
    );
    if (verified != null) return verified;
  }
  return null;
}

Future<DiscoveredServer?> _discoverViaUdp(
  List<LocalNetworkInfo> lanInterfaces,
  Set<String> ownIps,
  Duration window,
) async {
  final completer = Completer<DiscoveredServer?>();
  final sockets = <RawDatagramSocket>[];
  final timers = <Timer>[];
  final testedKeys = <String>{};
  final probeBytes = utf8.encode(ApiConstants.discoveryMagic);

  Future<void> handleDatagram(Datagram dg, String sourceTag) async {
    if (completer.isCompleted) return;
    final rawMsg = utf8.decode(dg.data, allowMalformed: true).trim();
    if (rawMsg.isEmpty || rawMsg.startsWith(ApiConstants.discoveryMagic)) {
      return;
    }

    int port = ApiConstants.defaultApiPort;
    String contextPath = '/api/v1';
    String? hostname;
    final candidateIps = <String>[];

    // 1. L'IP source réelle du paquet UDP est l'IP garantie joignable sur l'interface courante !
    final senderIp = dg.address.address;
    if (!ownIps.contains(senderIp) && !senderIp.startsWith('127.')) {
      candidateIps.add(senderIp);
    }

    // 2. Extraire port, contextPath et IP supplémentaires du JSON
    try {
      final decoded = jsonDecode(rawMsg);
      if (decoded is Map<String, dynamic>) {
        final app = decoded['app']?.toString().toLowerCase() ?? '';
        final type = decoded['type']?.toString().toUpperCase() ?? '';
        if (app != 'quantis-stock' && type != 'QUANTIS_SERVER') {
          return;
        }
        if (decoded['port'] is int) port = decoded['port'] as int;
        if (decoded['contextPath'] is String && (decoded['contextPath'] as String).isNotEmpty) {
          contextPath = decoded['contextPath'] as String;
        }
        hostname = decoded['hostname']?.toString();

        final primaryIp = decoded['primaryIp']?.toString();
        if (primaryIp != null &&
            primaryIp.isNotEmpty &&
            primaryIp != 'localhost' &&
            !ownIps.contains(primaryIp) &&
            !candidateIps.contains(primaryIp)) {
          candidateIps.add(primaryIp);
        }
        final extraIps = decoded['ips'];
        if (extraIps is List) {
          for (final item in extraIps) {
            final ip = item.toString();
            if (ip.isNotEmpty &&
                ip != 'localhost' &&
                !ownIps.contains(ip) &&
                !candidateIps.contains(ip)) {
              candidateIps.add(ip);
            }
          }
        }
      }
    } catch (_) {
      // Paquet non JSON — ignorer
      return;
    }

    for (final ip in candidateIps) {
      if (completer.isCompleted) return;
      final key = '$ip:$port';
      if (!testedKeys.add(key)) continue;

      final verified = await verifyServer(
        'http://$ip:$port$contextPath',
        timeout: const Duration(milliseconds: 1400),
        source: sourceTag,
        hostname: hostname,
      );
      if (verified != null && !completer.isCompleted) {
        completer.complete(verified);
        return;
      }
    }
  }

  void attachListener(RawDatagramSocket sock, String sourceTag) {
    sock.listen(
      (event) {
        if (event != RawSocketEvent.read) return;
        Datagram? dg;
        while ((dg = sock.receive()) != null) {
          unawaited(handleDatagram(dg!, sourceTag));
        }
      },
      onError: (_) {},
      cancelOnError: false,
    );
  }

  try {
    // 1. Socket d'écoute passive sur le port 45808 (capte les balises unicast passerelle & broadcast du PC)
    try {
      final beaconSock = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        ApiConstants.discoveryUdpPort,
        reuseAddress: true,
      );
      beaconSock.broadcastEnabled = true;
      sockets.add(beaconSock);
      attachListener(beaconSock, 'udp_beacon');
    } catch (_) {
      // Port déjà utilisé localement — on continue avec les sockets de sonde éphémères
    }

    // 2. Un socket de sonde lié à CHAQUE interface LAN/Hotspot (contourne le routage 4G/5G Android !)
    final probePairs = <(RawDatagramSocket, List<String>)>[];
    for (final lan in lanInterfaces) {
      try {
        final sock = await RawDatagramSocket.bind(InternetAddress(lan.ip), 0);
        sock.broadcastEnabled = true;
        sockets.add(sock);
        attachListener(sock, 'udp_probe');

        final targets = <String>[
          if (lan.subnetPrefix == '172.20.10') '172.20.10.15',
          '${lan.subnetPrefix}.255',
        ];
        probePairs.add((sock, targets));
      } catch (_) {}
    }

    // 3. Socket générique 0.0.0.0 pour broadcast global 255.255.255.255
    try {
      final anySock = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      anySock.broadcastEnabled = true;
      sockets.add(anySock);
      attachListener(anySock, 'udp_probe');

      final targets = <String>{
        '255.255.255.255',
        for (final lan in lanInterfaces) '${lan.subnetPrefix}.255',
      }.toList();
      probePairs.add((anySock, targets));
    } catch (_) {}

    void sendProbes() {
      if (completer.isCompleted) return;
      for (final pair in probePairs) {
        final sock = pair.$1;
        for (final target in pair.$2) {
          try {
            sock.send(probeBytes, InternetAddress(target), ApiConstants.discoveryUdpPort);
          } catch (_) {}
        }
      }
    }

    // Envoi immédiat + 2 relances pour réveiller le Wi-Fi / SoftAP
    sendProbes();
    timers.add(Timer(const Duration(milliseconds: 450), sendProbes));
    timers.add(Timer(const Duration(milliseconds: 1100), sendProbes));
    timers.add(Timer(window, () {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    }));

    return await completer.future;
  } finally {
    for (final t in timers) {
      t.cancel();
    }
    for (final s in sockets) {
      try {
        s.close();
      } catch (_) {}
    }
  }
}

Future<DiscoveredServer?> _scanSubnetsTcp(
  List<LocalNetworkInfo> lanInterfaces,
  Set<String> ownIps,
  void Function(String status)? onStatus,
) async {
  // Utiliser les VRAIS sous-réseaux détectés sur le téléphone (Hotspot d'abord, puis Wi-Fi)
  final prefixes = <String>[];
  for (final lan in lanInterfaces) {
    if (!prefixes.contains(lan.subnetPrefix)) {
      prefixes.add(lan.subnetPrefix);
    }
  }

  // Repli uniquement si aucune interface LAN/Hotspot n'a été remontée par l'OS
  if (prefixes.isEmpty) {
    prefixes.addAll(const [
      '192.168.43',
      '172.20.10',
      '192.168.1',
      '192.168.0',
      '192.168.11',
    ]);
  }

  const batchSize = 64;
  for (final prefix in prefixes) {
    onStatus?.call('Scan rapide port ${ApiConstants.defaultApiPort} sur $prefix.x...');
    final hosts = _buildHostOrder(prefix, ownIps);

    for (int i = 0; i < hosts.length; i += batchSize) {
      final batch = hosts.skip(i).take(batchSize).toList();
      final openIps = <String>[];

      await Future.wait(batch.map((ip) async {
        final open = await _fastTcpOpen(
          ip,
          ApiConstants.defaultApiPort,
          const Duration(milliseconds: 420),
        );
        if (open) openIps.add(ip);
      }));

      for (final ip in openIps) {
        final verified = await verifyServer(
          'http://$ip:${ApiConstants.defaultApiPort}/api/v1',
          timeout: const Duration(milliseconds: 1600),
          source: 'subnet_scan',
        );
        if (verified != null) {
          return verified;
        }
      }
    }
  }
  return null;
}

List<String> _buildHostOrder(String prefix, Set<String> ownIps) {
  final hosts = <String>[];
  if (prefix == '172.20.10') {
    // Hotspot iPhone utilise un /28 (172.20.10.1 à .14)
    for (int i = 2; i <= 14; i++) {
      final ip = '$prefix.$i';
      if (!ownIps.contains(ip)) hosts.add(ip);
    }
    if (!ownIps.contains('$prefix.1')) hosts.add('$prefix.1');
    return hosts;
  }

  // Pour tout /24 (Point d'accès Android aléatoire 10.x.y.x / 192.168.x.x ou Wi-Fi)
  for (int i = 1; i <= 254; i++) {
    final ip = '$prefix.$i';
    if (!ownIps.contains(ip)) hosts.add(ip);
  }
  return hosts;
}

Future<bool> _fastTcpOpen(String host, int port, Duration timeout) async {
  try {
    final socket = await Socket.connect(host, port, timeout: timeout);
    socket.destroy();
    return true;
  } catch (_) {
    return false;
  }
}

Future<List<String>> _readArpNeighbors() async {
  final ips = <String>[];
  try {
    final arpFile = File('/proc/net/arp');
    if (!await arpFile.exists()) return ips;
    final lines = await arpFile.readAsLines();
    for (int i = 1; i < lines.length; i++) {
      final parts = lines[i].trim().split(RegExp(r'\s+'));
      if (parts.length < 4) continue;
      final ip = parts[0];
      final flags = parts[2];
      final mac = parts[3];
      if (flags != '0x0' &&
          mac != '00:00:00:00:00:00' &&
          _isPrivateIpv4(ip) &&
          !ips.contains(ip)) {
        ips.add(ip);
      }
    }
  } catch (_) {
    // SELinux sur Android 11+ peut restreindre /proc/net/arp : ignoré silencieusement
  }
  return ips;
}

bool _isQuantisHealthPayload(dynamic body) {
  if (body is! Map) return false;
  final data = body['data'];
  if (data is Map) {
    final app = data['application']?.toString().toLowerCase() ?? '';
    final status = data['status']?.toString().toUpperCase() ?? '';
    return app.contains('quantis') || status == 'UP';
  }
  return body['status']?.toString().toUpperCase() == 'UP';
}

bool _isIgnoredVirtualInterface(String name) {
  return name == 'lo' ||
      name.startsWith('docker') ||
      name.startsWith('br-') ||
      name.startsWith('veth') ||
      name.startsWith('virbr') ||
      name.startsWith('vboxnet') ||
      name.startsWith('vmnet') ||
      name.startsWith('cni') ||
      name.startsWith('flannel') ||
      name.startsWith('podman') ||
      name.startsWith('kube') ||
      name.startsWith('dummy');
}

bool _isVpnInterface(String name) {
  return name.startsWith('tun') ||
      name.startsWith('tap') ||
      name.startsWith('wg') ||
      name.startsWith('utun') ||
      name.startsWith('ppp') ||
      name.startsWith('tailscale');
}

bool _isCellularInterface(String name) {
  return name.startsWith('rmnet') ||
      name.startsWith('v4-rmnet') ||
      name.startsWith('ccmni') ||
      name.startsWith('pdp') ||
      name.startsWith('wwan') ||
      name.startsWith('clat') ||
      name.startsWith('seth_lte') ||
      name.startsWith('epdg');
}

bool _isHotspotLikely(String name, String ip) {
  return name.startsWith('ap') ||
      name.startsWith('swlan') ||
      name.startsWith('softap') ||
      name == 'wlan1' ||
      name == 'wlan2' ||
      name.startsWith('rndis') ||
      name.startsWith('usb') ||
      name.startsWith('bridge') ||
      ip.startsWith('192.168.43.') ||
      ip.startsWith('172.20.10.') ||
      ip.startsWith('192.168.42.');
}

bool _isPrivateIpv4(String ip) {
  if (ip.startsWith('192.168.') || ip.startsWith('10.')) return true;
  if (ip.startsWith('172.')) {
    final parts = ip.split('.');
    if (parts.length == 4) {
      final second = int.tryParse(parts[1]) ?? -1;
      return second >= 16 && second <= 31;
    }
  }
  return false;
}

String? _subnetPrefix24(String ip) {
  final lastDot = ip.lastIndexOf('.');
  return lastDot > 0 ? ip.substring(0, lastDot) : null;
}
