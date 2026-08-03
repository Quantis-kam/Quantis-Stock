import 'package:dio/dio.dart';
import '../constants/app_constants.dart';

/// Client HTTP Dio configuré pour l'API Quantis.
class ApiClient {
  static Dio? _dio;
  static String? _accessToken;

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
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          // TODO: Phase 10 — refresh token automatique
          clearToken();
        }
        return handler.next(error);
      },
    ));

    return _dio!;
  }

  static void setToken(String token) {
    _accessToken = token;
  }

  static void clearToken() {
    _accessToken = null;
  }

  static bool get isAuthenticated => _accessToken != null;
}
