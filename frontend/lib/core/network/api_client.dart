import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../auth/pin_service.dart';
import '../auth/session_manager.dart';
import '../constants/app_constants.dart';
import '../sync/sync_manager.dart';
import 'server_discovery_service.dart';

/// État courant de la connexion au serveur backend.
enum ServerConnectionStatus { unknown, searching, connected, offline }

/// Client HTTP Dio configuré pour l'API Quantis.
/// Gère l'injection Bearer, le refresh automatique, la redirection login,
/// et la redécouverte automatique du serveur en cas de changement de réseau (Wi-Fi / Point d'accès).
class ApiClient {
  static final ValueNotifier<bool> authStateNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> sessionLockedNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<String> serverUrlNotifier =
      ValueNotifier<String>(ApiConstants.baseUrl);
  static final ValueNotifier<ServerConnectionStatus> serverStatusNotifier =
      ValueNotifier<ServerConnectionStatus>(ServerConnectionStatus.unknown);

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
  static bool _hasQuickPin = false;
  static List<String> _userPermissions = [];
  static List<String> _recentServerUrls = [];
  static bool _isRefreshing = false;
  static Future<DiscoveredServer?>? _activeDiscovery;
  static DateTime? _lastAutoDiscoveryAt;

  /// Indique qu'il faut proposer la création du code PIN rapide juste après la connexion.
  static bool pendingPinSetupPrompt = false;

  /// Raison affichée sur l'écran de verrouillage PIN.
  static String? lockReasonMessage;

  static final _storage = const FlutterSecureStorage(
    webOptions: WebOptions(
      dbName: 'quantis_stock_db',
      publicKey: 'quantis_stock_public_key',
    ),
  );
  static final Map<String, String> _memoryStorage = {};
  static Function? onSessionExpired;

  /// Message informatif affiché sur l'écran de connexion lorsqu'une session a expiré.
  static String? sessionExpiredMessage;

  static String? consumeSessionExpiredMessage() {
    final msg = sessionExpiredMessage;
    sessionExpiredMessage = null;
    return msg;
  }

  static Future<void> saveLastActivity(DateTime ts) async {
    await _writeStorage(
      'last_activity_at',
      ts.toUtc().millisecondsSinceEpoch.toString(),
    );
  }

  static Future<DateTime?> readLastActivity() async {
    final raw = await _readStorage('last_activity_at');
    if (raw == null || raw.trim().isEmpty) return null;
    final ms = int.tryParse(raw.trim());
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
  }

  /// Mémorise le dernier email utilisé pour éviter au client de le retaper.
  static Future<void> saveRememberedEmail(String email) async {
    final clean = email.trim();
    if (clean.isEmpty) return;
    await _writeStorage('remembered_email', clean);
  }

  static Future<String?> readRememberedEmail() async {
    return await _readStorage('remembered_email');
  }

  static Future<void> refreshQuickPinStatus() async {
    _hasQuickPin = await PinService.instance.hasPin(_userEmail);
  }

  /// Verrouille l'application avec le code PIN rapide sans perdre la session ni l'écran courant.
  static void lockSession({String? reason}) {
    if (!isAuthenticated) return;
    SessionManager.instance.stopSession();
    lockReasonMessage = reason ?? 'Déverrouillage rapide';
    sessionLockedNotifier.value = true;
  }

  /// Déverrouille la session après validation du code PIN 4 chiffres.
  static Future<bool> unlockSessionWithPin() async {
    if (!isAuthenticated) return false;

    if (_refreshToken != null &&
        JwtTokenUtils.isExpired(_refreshToken) &&
        JwtTokenUtils.isExpired(_accessToken)) {
      clearToken(
        expiredMessage: 'Votre session a expiré. Veuillez vous reconnecter.',
      );
      return false;
    }

    // Rafraîchir le JWT silencieusement si l'access token a expiré pendant la veille
    await refreshSessionIfNeeded();
    if (!isAuthenticated) return false;

    lockReasonMessage = null;
    sessionLockedNotifier.value = false;
    SessionManager.instance.startSession();
    return true;
  }

  static List<String> get recentServerUrls => List.unmodifiable(_recentServerUrls);

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
    sessionExpiredMessage = null;
    await _writeStorage('access_token', access);
    await _writeStorage('refresh_token', refresh);
    await saveLastActivity(DateTime.now());
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
          _userRole == 'SUPER_ADMIN' ||
          _userRole == 'ROLE_SUPER_ADMIN';
      _entrepriseNom = await _readStorage('entreprise_nom');
      _entrepriseNif = await _readStorage('entreprise_nif');
      _entrepriseMonnaie = await _readStorage('entreprise_monnaie');
      _formatFacture = await _readStorage('format_facture');
      _logoUrl = await _readStorage('logo_url');
      final permsString = await _readStorage('user_permissions');
      if (permsString != null) {
        _userPermissions = permsString.split(',');
      }

      final recentRaw = await _readStorage('recent_server_urls');
      if (recentRaw != null && recentRaw.trim().isNotEmpty) {
        _recentServerUrls = recentRaw
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }

      final defaultUrl = ApiConstants.defaultBaseUrl;
      final isProductionCloud = defaultUrl.toLowerCase().startsWith('https://');
      final savedUrl = await _readStorage('custom_server_url');

      if (isProductionCloud) {
        // En production Cloud (APK & stock.quantisbf.com), toujours utiliser l'API officielle
        // et purger toute ancienne IP locale enregistrée en développement.
        if (savedUrl != null && savedUrl.trim().isNotEmpty) {
          await _deleteStorage('custom_server_url');
        }
        ApiConstants.baseUrl = defaultUrl;
      } else {
        // Sur mobile local, ignorer uniquement "localhost" (invalide sur téléphone).
        final isInvalidMobileUrl =
            ApiConstants.isMobilePlatform && (savedUrl?.contains('localhost') == true);
        if (savedUrl != null && savedUrl.trim().isNotEmpty && !isInvalidMobileUrl) {
          ApiConstants.baseUrl = ApiConstants.normalizeApiUrl(savedUrl);
        } else {
          if (isInvalidMobileUrl) {
            await _deleteStorage('custom_server_url');
          }
          ApiConstants.baseUrl = defaultUrl;
        }
      }
      _dio?.options.baseUrl = ApiConstants.baseUrl;
      serverUrlNotifier.value = ApiConstants.baseUrl;

      // Contrôle strict de l'expiration / verrouillage PIN au démarrage (app fermée / rouverte)
      if (_accessToken != null) {
        _hasQuickPin = await PinService.instance.hasPin(_userEmail);
        final lastActivity = await readLastActivity();
        final isInactiveTooLong = lastActivity == null ||
            DateTime.now().difference(lastActivity) >=
                AppConstants.sessionInactivityTimeout;

        final accessExpired = JwtTokenUtils.isExpired(_accessToken);
        final refreshExpired =
            _refreshToken == null || JwtTokenUtils.isExpired(_refreshToken);

        // Si même le refresh token (7 jours) est expiré → reconnexion complète obligatoire
        if (accessExpired && refreshExpired) {
          clearToken(
            expiredMessage: 'Votre session a expiré. Veuillez vous reconnecter.',
          );
          return;
        }

        // Si le client a activé le code PIN rapide (4 chiffres) → verrouillage instantané à l'ouverture
        if (_hasQuickPin) {
          lockReasonMessage = isInactiveTooLong
              ? 'Verrouillé après ${AppConstants.sessionInactivityTimeout.inMinutes} min d\'inactivité'
              : 'Déverrouillage rapide';
          sessionLockedNotifier.value = true;
          authStateNotifier.value = true;
          return;
        }

        // Sinon (pas encore de PIN) → déconnexion classique après 30 min d'inactivité
        if (isInactiveTooLong) {
          clearToken(
            expiredMessage:
                'Votre session a expiré après ${AppConstants.sessionInactivityTimeout.inMinutes} minutes d\'inactivité. Veuillez vous reconnecter.',
          );
          return;
        }

        SessionManager.instance.restoreSession(lastActivity);
      }
    } catch (e) {
      debugPrint('Notice storage read in initialize: $e');
    }
    authStateNotifier.value = isAuthenticated;
  }

  /// Rafraîchit silencieusement le JWT quand l'utilisateur est actif et que
  /// le token d'accès arrive à moins de 2 minutes de son expiration.
  static Future<void> refreshSessionIfNeeded() async {
    if (!isAuthenticated || _refreshToken == null || _isRefreshing) return;
    final needsRefresh = JwtTokenUtils.isExpired(
      _accessToken,
      skew: AppConstants.proactiveRefreshThreshold,
    );
    if (!needsRefresh) return;

    if (JwtTokenUtils.isExpired(_refreshToken)) {
      SessionManager.instance.expireSession(
        customMessage: 'Votre session a expiré. Veuillez vous reconnecter.',
      );
      return;
    }

    _isRefreshing = true;
    try {
      final refreshDio = Dio(BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
      ));
      final res = await refreshDio.post('/auth/refresh', data: {
        'refreshToken': _refreshToken,
      });
      final newAccessToken = res.data['data']['accessToken'] as String?;
      final newRefreshToken = res.data['data']['refreshToken'] as String?;
      if (newAccessToken != null && newAccessToken.isNotEmpty) {
        _accessToken = newAccessToken;
        await _writeStorage('access_token', newAccessToken);
      }
      if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
        _refreshToken = newRefreshToken;
        await _writeStorage('refresh_token', newRefreshToken);
      }
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 400 || code == 401 || code == 402 || code == 403) {
        clearToken(
          expiredMessage: 'Votre session a expiré. Veuillez vous reconnecter.',
        );
      }
    } catch (_) {
      // Erreur réseau passagère : on ne déconnecte pas l'utilisateur actif
    } finally {
      _isRefreshing = false;
    }
  }

  /// Met à jour l'URL serveur EN PLACE (tous les services utilisant ApiClient.instance
  /// basculent immédiatement sans redémarrer l'application).
  static Future<void> setCustomServerUrl(String url, {bool markConnected = false}) async {
    final cleanUrl = ApiConstants.normalizeApiUrl(url);
    ApiConstants.baseUrl = cleanUrl;
    _dio?.options.baseUrl = cleanUrl;
    serverUrlNotifier.value = cleanUrl;
    if (markConnected) {
      serverStatusNotifier.value = ServerConnectionStatus.connected;
    }
    await _writeStorage('custom_server_url', cleanUrl);

    // Mémoriser les 5 dernières URLs utilisées (Wi-Fi bureau, Point d'accès, USB...)
    _recentServerUrls.remove(cleanUrl);
    _recentServerUrls.insert(0, cleanUrl);
    if (_recentServerUrls.length > 5) {
      _recentServerUrls = _recentServerUrls.sublist(0, 5);
    }
    await _writeStorage('recent_server_urls', _recentServerUrls.join(','));
  }

  static Future<void> resetCustomServerUrl() async {
    ApiConstants.baseUrl = ApiConstants.defaultBaseUrl;
    _dio?.options.baseUrl = ApiConstants.baseUrl;
    serverUrlNotifier.value = ApiConstants.baseUrl;
    serverStatusNotifier.value = ServerConnectionStatus.unknown;
    await _deleteStorage('custom_server_url');
  }

  /// Vérifie au démarrage que le serveur répond ; en mode Cloud HTTPS, réveille
  /// silencieusement le backend en arrière-plan sans écraser l'URL Cloud par un scan LAN.
  static Future<void> autoConnectOnStartup() async {
    serverStatusNotifier.value = ServerConnectionStatus.searching;
    if (ApiConstants.isCloudUrl) {
      final cloudOk = await ServerDiscoveryService.verifyServer(
        ApiConstants.baseUrl,
        timeout: const Duration(seconds: 25),
      );
      serverStatusNotifier.value = cloudOk != null
          ? ServerConnectionStatus.connected
          : ServerConnectionStatus.offline;
      return;
    }
    if (kIsWeb) {
      final webOk = await ServerDiscoveryService.verifyServer(
        ApiConstants.baseUrl,
        timeout: const Duration(seconds: 4),
      );
      serverStatusNotifier.value = webOk != null
          ? ServerConnectionStatus.connected
          : ServerConnectionStatus.offline;
      return;
    }
    final currentOk = await ServerDiscoveryService.verifyServer(
      ApiConstants.baseUrl,
      timeout: const Duration(milliseconds: 1200),
    );
    if (currentOk != null) {
      serverStatusNotifier.value = ServerConnectionStatus.connected;
      return;
    }
    await tryAutoRediscover(force: true);
  }

  /// Tente de redécouvrir automatiquement le serveur backend (Point d'accès mobile ou Wi-Fi).
  /// Déduplique les appels simultanés et respecte un cooldown quand `force == false`.
  static Future<DiscoveredServer?> tryAutoRediscover({
    bool force = false,
    void Function(String status)? onStatus,
  }) async {
    if (kIsWeb) return null;

    if (_activeDiscovery != null) {
      return _activeDiscovery;
    }

    if (!force && _lastAutoDiscoveryAt != null) {
      final elapsed = DateTime.now().difference(_lastAutoDiscoveryAt!);
      if (elapsed < const Duration(seconds: 8)) {
        return null;
      }
    }

    _lastAutoDiscoveryAt = DateTime.now();
    serverStatusNotifier.value = ServerConnectionStatus.searching;

    final future = () async {
      try {
        final priority = <String>[
          ApiConstants.baseUrl,
          ..._recentServerUrls,
        ];
        final result = await ServerDiscoveryService.discoverServer(
          priorityUrls: priority,
          onStatus: onStatus,
        );
        final found = result.server;
        if (found != null) {
          await setCustomServerUrl(found.apiUrl, markConnected: true);
          return found;
        }
        serverStatusNotifier.value = ServerConnectionStatus.offline;
        return null;
      } catch (e) {
        debugPrint('Notice auto-rediscover: $e');
        serverStatusNotifier.value = ServerConnectionStatus.offline;
        return null;
      } finally {
        _activeDiscovery = null;
      }
    }();

    _activeDiscovery = future;
    return future;
  }

  static Dio get instance {
    if (_dio != null) {
      _dio!.options.baseUrl = ApiConstants.baseUrl;
      return _dio!;
    }

    final dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: ApiConstants.connectTimeout),
      receiveTimeout: const Duration(seconds: ApiConstants.receiveTimeout),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // Toujours synchroniser l'URL courante (même pour les services ayant mis en cache ApiClient.instance)
        options.baseUrl = ApiConstants.baseUrl;
        if (_accessToken != null) {
          options.headers['Authorization'] = 'Bearer $_accessToken';
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        if (serverStatusNotifier.value != ServerConnectionStatus.connected) {
          serverStatusNotifier.value = ServerConnectionStatus.connected;
        }
        return handler.next(response);
      },
      onError: (error, handler) async {
        // 1. Reconnexion automatique transparente en mode réseau local (Wi-Fi <-> Point d'accès)
        final isNetworkDown = error.type == DioExceptionType.connectionError ||
            error.type == DioExceptionType.connectionTimeout;
        if (isNetworkDown &&
            !kIsWeb &&
            !ApiConstants.isCloudUrl &&
            error.requestOptions.extra['_rediscoverRetried'] != true) {
          final discovered = await tryAutoRediscover();
          if (discovered != null) {
            try {
              error.requestOptions.extra['_rediscoverRetried'] = true;
              error.requestOptions.baseUrl = ApiConstants.baseUrl;
              final retryRes = await dio.fetch(error.requestOptions);
              return handler.resolve(retryRes);
            } on DioException catch (retryErr) {
              return handler.next(retryErr);
            } catch (_) {
              return handler.next(error);
            }
          }
        }

        // 2. 401 Unauthorized ou 403 Forbidden (token rejeté/expiré par Spring Security) tente un refresh de session
        final statusCode = error.response?.statusCode;
        final path = error.requestOptions.path;

        if ((statusCode == 401 || statusCode == 403) &&
            _refreshToken != null &&
            !_isRefreshing &&
            !path.contains('/auth/')) {
          _isRefreshing = true;
          bool refreshSucceeded = false;
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

            refreshSucceeded = true;
          } catch (_) {
            _isRefreshing = false;
            // Le refresh a échoué → session réellement expirée
            clearToken(
              expiredMessage: 'Votre session a expiré. Veuillez vous reconnecter.',
            );
            onSessionExpired?.call();
            return handler.next(error);
          } finally {
            _isRefreshing = false;
          }

          if (refreshSucceeded) {
            try {
              // Rejouer la requête originale avec le nouveau token
              error.requestOptions.baseUrl = ApiConstants.baseUrl;
              error.requestOptions.headers['Authorization'] = 'Bearer $_accessToken';
              final retryResponse = await dio.fetch(error.requestOptions);
              return handler.resolve(retryResponse);
            } on DioException catch (retryErr) {
              // Si la requête rejouée échoue, ne pas déconnecter l'utilisateur inutilement
              return handler.next(retryErr);
            } catch (e) {
              return handler.next(error);
            }
          }
        } else if ((statusCode == 401 || statusCode == 403) && !path.contains('/auth/')) {
          // Token absent ou invalide sans possibilité de refresh
          clearToken(
            expiredMessage: 'Votre session a expiré. Veuillez vous reconnecter.',
          );
          onSessionExpired?.call();
        }
        return handler.next(error);
      },
    ));

    _dio = dio;
    return dio;
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

  static void clearToken({String? expiredMessage}) {
    _accessToken = null;
    _refreshToken = null;
    _userRole = null;
    _userName = null;
    _userEmail = null;
    _entrepriseId = null;
    _isSuperAdmin = false;
    _hasQuickPin = false;
    _entrepriseNom = null;
    _entrepriseMonnaie = null;
    _formatFacture = null;
    _logoUrl = null;
    _userPermissions = [];
    sessionExpiredMessage = expiredMessage;
    lockReasonMessage = null;
    pendingPinSetupPrompt = false;
    SessionManager.instance.stopSession();
    SyncManager.instance.stop();
    sessionLockedNotifier.value = false;
    authStateNotifier.value = false;
    try {
      _deleteStorage('access_token');
      _deleteStorage('refresh_token');
      _deleteStorage('last_activity_at');
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
  static bool get isSessionLocked => sessionLockedNotifier.value;
  static bool get hasQuickPin => _hasQuickPin;
  static bool get hasValidRefreshToken =>
      _refreshToken != null && !JwtTokenUtils.isExpired(_refreshToken);
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
