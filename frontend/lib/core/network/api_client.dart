import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

/// Client HTTP Dio configuré pour l'API Quantis.
/// Gère l'injection Bearer, le refresh automatique, et la redirection login.
class ApiClient {
  static final ValueNotifier<bool> authStateNotifier = ValueNotifier<bool>(false);
  static Dio? _dio;
  static String? _accessToken;
  static String? _refreshToken;
  static String? _userRole;
  static String? _userName;
  static String? _userEmail;
  static String? _entrepriseNom;
  static String? _entrepriseNif;
  static String? _entrepriseMonnaie;
  static String? _formatFacture;
  static String? _logoUrl;
  static String? _entrepriseId;
  static bool _isSuperAdmin = false;
  static List<String> _userPermissions = [];
  static bool _isRefreshing = false;
  static final _storage = const FlutterSecureStorage();
  static Function? onSessionExpired;

  static Future<void> initialize() async {
    _accessToken = await _storage.read(key: 'access_token');
    _refreshToken = await _storage.read(key: 'refresh_token');
    _userRole = await _storage.read(key: 'user_role');
    _userName = await _storage.read(key: 'user_name');
    _userEmail = await _storage.read(key: 'user_email');
    _entrepriseId = await _storage.read(key: 'entreprise_id');
    _isSuperAdmin = (await _storage.read(key: 'is_super_admin')) == 'true' ||
                    _userRole == 'SUPER_ADMIN' || _userRole == 'ROLE_SUPER_ADMIN';
    _entrepriseNom = await _storage.read(key: 'entreprise_nom');
    _entrepriseNif = await _storage.read(key: 'entreprise_nif');
    _entrepriseMonnaie = await _storage.read(key: 'entreprise_monnaie');
    _formatFacture = await _storage.read(key: 'format_facture');
    _logoUrl = await _storage.read(key: 'logo_url');
    final permsString = await _storage.read(key: 'user_permissions');
    if (permsString != null) {
      _userPermissions = permsString.split(',');
    }
    authStateNotifier.value = isAuthenticated;
  }

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

  static Future<void> setUserInfo(
    String role,
    String name,
    String email,
    List<String> permissions, {
    String? entrepriseNom,
    String? entrepriseMonnaie,
    String? formatFacture,
    String? logoUrl,
    String? entrepriseId,
    bool? isSuperAdmin,
  }) async {
    _userRole = role;
    _userName = name;
    _userEmail = email;
    _userPermissions = permissions;
    _entrepriseNom = entrepriseNom ?? 'Quantis SARL';
    _entrepriseMonnaie = entrepriseMonnaie ?? 'FCFA';
    _formatFacture = formatFacture ?? 'FAC-{YYYY}-{NNNNN}';
    _logoUrl = logoUrl;
    _entrepriseId = entrepriseId;
    _isSuperAdmin = isSuperAdmin ?? (role == 'SUPER_ADMIN' || role == 'ROLE_SUPER_ADMIN');

    await _storage.write(key: 'user_role', value: role);
    await _storage.write(key: 'user_name', value: name);
    await _storage.write(key: 'user_email', value: email);
    await _storage.write(key: 'user_permissions', value: permissions.join(','));
    await _storage.write(key: 'entreprise_nom', value: _entrepriseNom!);
    await _storage.write(key: 'entreprise_monnaie', value: _entrepriseMonnaie!);
    await _storage.write(key: 'format_facture', value: _formatFacture!);
    await _storage.write(key: 'is_super_admin', value: _isSuperAdmin ? 'true' : 'false');
    if (_entrepriseId != null) {
      await _storage.write(key: 'entreprise_id', value: _entrepriseId!);
    } else {
      await _storage.delete(key: 'entreprise_id');
    }
    if (_logoUrl != null) {
      await _storage.write(key: 'logo_url', value: _logoUrl!);
    }
    authStateNotifier.value = true;
  }

  static Future<void> updateEntrepriseInfo({
    required String nom,
    required String monnaie,
    required String formatFacture,
    String? logoUrl,
  }) async {
    _entrepriseNom = nom;
    _entrepriseMonnaie = monnaie;
    _formatFacture = formatFacture;
    _logoUrl = logoUrl;
    await _storage.write(key: 'entreprise_nom', value: nom);
    await _storage.write(key: 'entreprise_monnaie', value: monnaie);
    await _storage.write(key: 'format_facture', value: formatFacture);
    if (logoUrl != null && logoUrl.isNotEmpty) {
      await _storage.write(key: 'logo_url', value: logoUrl);
    } else {
      await _storage.delete(key: 'logo_url');
    }
  }

  static void clearToken() {
    _accessToken = null;
    _refreshToken = null;
    _userRole = null;
    _userName = null;
    _userEmail = null;
    _entrepriseId = null;
    _isSuperAdmin = false;
    _entrepriseNom = null;
    _entrepriseMonnaie = null;
    _formatFacture = null;
    _logoUrl = null;
    _userPermissions = [];
    _storage.delete(key: 'access_token');
    _storage.delete(key: 'refresh_token');
    _storage.delete(key: 'user_role');
    _storage.delete(key: 'user_name');
    _storage.delete(key: 'user_email');
    _storage.delete(key: 'entreprise_id');
    _storage.delete(key: 'is_super_admin');
    _storage.delete(key: 'entreprise_nom');
    _storage.delete(key: 'entreprise_monnaie');
    _storage.delete(key: 'format_facture');
    _storage.delete(key: 'logo_url');
    _storage.delete(key: 'user_permissions');
    authStateNotifier.value = false;
  }

  static bool get isAuthenticated => _accessToken != null;
  static bool get isSuperAdmin => _isSuperAdmin || _userRole == 'SUPER_ADMIN' || _userRole == 'ROLE_SUPER_ADMIN';
  static String? get entrepriseId => _entrepriseId;
  static String? get userRole => _userRole;
  static String? get userName => _userName;
  static String? get userEmail => _userEmail;
  static String get entrepriseNom => _entrepriseNom ?? (_isSuperAdmin ? 'Quantis-Stock Platform' : 'Quantis SARL');
  static String get entrepriseNif => _entrepriseNif ?? 'BF000123456A';
  static String get entrepriseMonnaie => _entrepriseMonnaie ?? 'FCFA';
  static String get formatFacture => _formatFacture ?? 'FAC-{YYYY}-{NNNNN}';
  static String? get logoUrl => _logoUrl;
  static List<String> get userPermissions => _userPermissions;
  static bool get isAdmin => isSuperAdmin || _userRole == 'ADMIN' || _userRole == 'ROLE_ADMIN' || _userRole == 'GERANT' || _userRole == 'ROLE_GERANT';

  // Méthodes d'instance pour simplifier les appels d'API
  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? queryParameters, Options? options}) =>
      instance.get<T>(path, queryParameters: queryParameters, options: options);

  Future<Response<T>> post<T>(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) =>
      instance.post<T>(path, data: data, queryParameters: queryParameters, options: options);

  Future<Response<T>> put<T>(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) =>
      instance.put<T>(path, data: data, queryParameters: queryParameters, options: options);

  Future<Response<T>> delete<T>(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) =>
      instance.delete<T>(path, data: data, queryParameters: queryParameters, options: options);
}
