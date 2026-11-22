import 'server_discovery_models.dart';
import 'server_discovery_stub.dart'
    if (dart.library.io) 'server_discovery_io.dart'
    if (dart.library.html) 'server_discovery_web.dart' as impl;

export 'server_discovery_models.dart';

/// Façade multiplateforme (Android, iOS, Desktop, Web) pour la détection automatique
/// du serveur backend Quantis Stock sur Wi-Fi et Point d'accès mobile.
class ServerDiscoveryService {
  ServerDiscoveryService._();

  static Future<List<LocalNetworkInfo>> getLocalNetworks() =>
      impl.getLocalNetworks();

  static Future<DiscoveredServer?> verifyServer(
    String urlOrIp, {
    Duration timeout = const Duration(seconds: 3),
    String source = 'direct',
  }) =>
      impl.verifyServer(urlOrIp, timeout: timeout, source: source);

  static Future<DiscoveryResult> discoverServer({
    List<String> priorityUrls = const [],
    void Function(String status)? onStatus,
    Duration udpWindow = const Duration(milliseconds: 2400),
    bool scanSubnets = true,
  }) =>
      impl.discoverServer(
        priorityUrls: priorityUrls,
        onStatus: onStatus,
        udpWindow: udpWindow,
        scanSubnets: scanSubnets,
      );
}

