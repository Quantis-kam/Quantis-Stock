import 'package:dio/dio.dart';
import '../constants/app_constants.dart';
import 'server_discovery_models.dart';

Future<List<LocalNetworkInfo>> getLocalNetworks() async => const [];

Future<DiscoveredServer?> verifyServer(
  String urlOrIp, {
  Duration timeout = const Duration(seconds: 3),
  String source = 'direct',
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
        latencyMs: sw.elapsedMilliseconds,
      );
    }
  } catch (_) {}
  return null;
}

Future<DiscoveryResult> discoverServer({
  List<String> priorityUrls = const [],
  void Function(String status)? onStatus,
  Duration udpWindow = const Duration(milliseconds: 2400),
  bool scanSubnets = true,
}) async {
  onStatus?.call('Vérification du serveur API...');
  final candidates = <String>{
    ...priorityUrls.where((u) => u.trim().isNotEmpty),
    ApiConstants.defaultBaseUrl,
    'http://localhost:${ApiConstants.defaultApiPort}/api/v1',
  };

  for (final cand in candidates) {
    final verified = await verifyServer(cand, timeout: const Duration(seconds: 2));
    if (verified != null) {
      return DiscoveryResult(server: verified);
    }
  }
  return const DiscoveryResult();
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

