/// Informations sur une interface réseau locale du téléphone ou du PC.
class LocalNetworkInfo {
  final String interfaceName;
  final String ip;
  final String subnetPrefix;
  final bool isHotspotLikely;
  final bool isCellular;
  final bool isVpn;

  const LocalNetworkInfo({
    required this.interfaceName,
    required this.ip,
    required this.subnetPrefix,
    this.isHotspotLikely = false,
    this.isCellular = false,
    this.isVpn = false,
  });

  bool get isScannableLan => !isCellular && !isVpn;

  String get displayLabel {
    if (isHotspotLikely) return 'Point d\'accès ($interfaceName) : $ip';
    if (isVpn) return 'VPN ($interfaceName) : $ip';
    if (isCellular) return 'Données mobiles ($interfaceName) : $ip';
    return 'Wi-Fi / LAN ($interfaceName) : $ip';
  }
}

/// Serveur Quantis Stock détecté et vérifié sur le réseau.
class DiscoveredServer {
  final String apiUrl;
  final String ip;
  final int port;
  final String source;
  final String? hostname;
  final int latencyMs;

  const DiscoveredServer({
    required this.apiUrl,
    required this.ip,
    required this.port,
    required this.source,
    this.hostname,
    this.latencyMs = 0,
  });

  String get sourceLabel {
    switch (source) {
      case 'udp_beacon':
      case 'udp_probe':
        return 'Auto-découverte UDP';
      case 'arp':
        return 'Voisinage Point d\'accès';
      case 'subnet_scan':
        return 'Scan réseau local';
      case 'usb':
        return 'Câble USB (ADB)';
      case 'direct':
      default:
        return 'Connexion directe';
    }
  }
}

/// Résultat complet d'une session de découverte.
class DiscoveryResult {
  final DiscoveredServer? server;
  final List<LocalNetworkInfo> localInterfaces;
  final bool hasActiveVpn;

  const DiscoveryResult({
    this.server,
    this.localInterfaces = const [],
    this.hasActiveVpn = false,
  });

  List<LocalNetworkInfo> get lanInterfaces =>
      localInterfaces.where((i) => i.isScannableLan).toList();
}

