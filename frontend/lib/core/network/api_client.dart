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
  static final _storage = const FlutterSecureStorage(
    webOptions: WebOptions(
      dbName: 'quantis_stock_db',
      publicKey: 'quantis_stock_public_key',
    ),
  );
  static final Map<String, String> _memoryStorage = {};
  static Function? onSessionExpired;

  static Future<void> _writeStorage(String key, String value) async {
    _memoryStorage[key] = value;
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {}
  }

  static Future<String?> _readStorage(String key) async {
    try {
      final val = await _storage.read(key: key);
      if (val != null) {
        _memoryStorage[key] = val;
        return val;
      }
    } catch (_) {}
    return _memoryStorage[key];
  }

  static Future<void> _deleteStorage(String key) async {
    _memoryStorage.remove(key);
    try {
      await _storage.delete(key: key);
    } catch (_) {}
  }

  static Future<void> saveTokens(String access, String refresh) async {
    _accessToken = access;
    _refreshToken = refresh;
    await _writeStorage('access_token', access);
    await _writeStorage('refresh_token', refresh);
  }

  static Future<void> initialize() async {
    try {
      _accessToken = await _readStorage('access_token');
      _refreshToken = await _readStorage('refresh_token');
      _userRole = await _readStorage('user_role');
      _userName = await _readStorage('user_name');
      _userEmail = await _readStorage('user_email');
      _entrepriseId = await _readStorage('entreprise_id');
      _isSuperAdmin = (await _readStorage('is_super_admin')) == 'true' ||
                      _userRole == 'SUPER_ADMIN' || _userRole == 'ROLE_SUPER_ADMIN';
      _entrepriseNom = await _readStorage('entreprise_nom');
      _entrepriseNif = await _readStorage('entreprise_nif');
      _entrepriseMonnaie = await _readStorage('entreprise_monnaie');
      _formatFacture = await _readStorage('format_facture');
      _logoUrl = await _readStorage('logo_url');
      final permsString = await _readStorage('user_permissions');
      if (permsString != null) {
        _userPermissions = permsString.split(',');
      }
      final savedUrl = await _readStorage('custom_server_url');
      if (savedUrl != null && savedUrl.trim().isNotEmpty && !savedUrl.contains('192.168.11.119')) {
        ApiConstants.baseUrl = savedUrl.trim();
      } else {
        if (savedUrl != null && savedUrl.contains('192.168.11.119')) {
          await _deleteStorage('custom_server_url');
        }
        ApiConstants.baseUrl = ApiConstants.defaultBaseUrl;
      }
    } catch (e) {
      debugPrint('Notice storage read in initialize: $e');
    }
    authStateNotifier.value = isAuthenticated;
  }

  static Future<void> setCustomServerUrl(String url) async {
    String cleanUrl = url.trim();
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }
    if (!cleanUrl.endsWith('/api/v1')) {
      cleanUrl = '$cleanUrl/api/v1';
    }
    ApiConstants.baseUrl = cleanUrl;
    await _writeStorage('custom_server_url', cleanUrl);
    _dio = null;
  }

  static Future<void> resetCustomServerUrl() async {
    ApiConstants.baseUrl = ApiConstants.defaultBaseUrl;
    await _deleteStorage('custom_server_url');
    _dio = null;
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
            await _writeStorage('access_token', _accessToken!);
            if (newRefreshToken != null) {
              await _writeStorage('refresh_token', newRefreshToken);
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
    authStateNotifier.value = true;

    try {
      await _writeStorage('user_role', role);
      await _writeStorage('user_name', name);
      await _writeStorage('user_email', email);
      await _writeStorage('user_permissions', permissions.join(','));
      await _writeStorage('entreprise_nom', _entrepriseNom!);
      await _writeStorage('entreprise_monnaie', _entrepriseMonnaie!);
      await _writeStorage('format_facture', _formatFacture!);
      await _writeStorage('is_super_admin', _isSuperAdmin ? 'true' : 'false');
      if (_entrepriseId != null) {
        await _writeStorage('entreprise_id', _entrepriseId!);
      } else {
        await _deleteStorage('entreprise_id');
      }
      if (_logoUrl != null) {
        await _writeStorage('logo_url', _logoUrl!);
      }
    } catch (e) {
      debugPrint('Notice storage write in setUserInfo: $e');
    }
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
    try {
      await _writeStorage('entreprise_nom', nom);
      await _writeStorage('entreprise_monnaie', monnaie);
      await _writeStorage('format_facture', formatFacture);
      if (logoUrl != null && logoUrl.isNotEmpty) {
        await _writeStorage('logo_url', logoUrl);
      } else {
        await _deleteStorage('logo_url');
      }
    } catch (_) {}
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
    authStateNotifier.value = false;
    try {
      _deleteStorage('access_token');
      _deleteStorage('refresh_token');
      _deleteStorage('user_role');
      _deleteStorage('user_name');
      _deleteStorage('user_email');
      _deleteStorage('entreprise_id');
      _deleteStorage('is_super_admin');
      _deleteStorage('entreprise_nom');
      _deleteStorage('entreprise_monnaie');
      _deleteStorage('format_facture');
      _deleteStorage('logo_url');
      _deleteStorage('user_permissions');
    } catch (_) {}
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
