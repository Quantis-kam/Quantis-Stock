import 'server_discovery_models.dart';

Future<List<LocalNetworkInfo>> getLocalNetworks() async => const [];

Future<DiscoveredServer?> verifyServer(
  String urlOrIp, {
  Duration timeout = const Duration(seconds: 3),
  String source = 'direct',
}) async =>
    null;

Future<DiscoveryResult> discoverServer({
  List<String> priorityUrls = const [],
  void Function(String status)? onStatus,
  Duration udpWindow = const Duration(milliseconds: 2400),
  bool scanSubnets = true,
}) async =>
    const DiscoveryResult();

