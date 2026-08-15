import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

/// Client HTTP Dio configuré pour l'API Quantis.
/// Gère l'injection Bearer, le refresh automatique, et la redirection login.
class ApiClient {
  static Dio? _dio;
  static String? _accessToken;
  static String? _refreshToken;
  static bool _isRefreshing = false;
  static final _storage = const FlutterSecureStorage();
  static Function? onSessionExpired;

  static Dio get instance {
    _dio ??= Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: ApiConstants.connectTimeout),
      receiveTimeout: const Duration(seconds: ApiConstants.receiveTimeout),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    _dio!.interceptors.clear();
    _dio!.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_accessToken != null) {
          options.headers['Authorization'] = 'Bearer $_accessToken';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        // Token expiré → tenter un refresh
        if ((error.response?.statusCode == 401 || error.response?.statusCode == 403) &&
            _refreshToken != null &&
            !_isRefreshing) {
          _isRefreshing = true;
          try {
            final refreshDio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
            final res = await refreshDio.post('/auth/refresh', data: {
              'refreshToken': _refreshToken,
            });

            final newAccessToken = res.data['data']['accessToken'] as String;
            final newRefreshToken = res.data['data']['refreshToken'] as String?;

            _accessToken = newAccessToken;
            if (newRefreshToken != null) _refreshToken = newRefreshToken;

            // Sauvegarder les nouveaux tokens
            await _storage.write(key: 'access_token', value: _accessToken);
            if (newRefreshToken != null) {
              await _storage.write(key: 'refresh_token', value: newRefreshToken);
            }

            _isRefreshing = false;

            // Rejouer la requête originale avec le nouveau token
            error.requestOptions.headers['Authorization'] = 'Bearer $_accessToken';
            final retryResponse = await _dio!.fetch(error.requestOptions);
            return handler.resolve(retryResponse);
          } catch (_) {
            _isRefreshing = false;
            // Refresh échoué → session expirée
            clearToken();
            onSessionExpired?.call();
          }
        }
        return handler.next(error);
      },
    ));

    return _dio!;
  }

  static void setToken(String token) {
    _accessToken = token;
  }

  static void setRefreshToken(String token) {
    _refreshToken = token;
  }

  static void clearToken() {
    _accessToken = null;
    _refreshToken = null;
    _storage.delete(key: 'access_token');
    _storage.delete(key: 'refresh_token');
  }

  static bool get isAuthenticated => _accessToken != null;
}
