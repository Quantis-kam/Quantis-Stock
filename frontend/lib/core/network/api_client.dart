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
  static bool _tvaActive = true;
  static double _tauxTvaDefaut = 18.0;
  static bool _suiviPrixAchat = true;
  static bool _isSuperAdmin = false;
  static bool _hasQuickPin = false;
  static bool _accountHasPin = false;
  static List<String> _userPermissions = [];
  static List<String> _recentServerUrls = [];
  static Future<bool>? _activeRefreshFuture;
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
    final hasLocal = await PinService.instance.hasPin(_userEmail);
    _hasQuickPin = _accountHasPin || hasLocal;
  }

  /// Enregistre le code PIN (4 chiffres) sur le compte utilisateur côté serveur (BCrypt).
  /// Retourne `true` si la synchronisation serveur a réussi, `false` en mode hors-ligne.
  static Future<bool> saveAccountPin(String pin) async {
    if (!isAuthenticated || !PinService.isValidPinFormat(pin)) return false;
    try {
      await refreshSessionIfNeeded();
      if (!isAuthenticated || JwtTokenUtils.isExpired(_accessToken)) return false;
      final res = await instance.post(
        '/auth/pin',
        data: {'pin': pin},
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          extra: const {'_skipAuthRetry': true},
        ),
      );
      if (res.statusCode == 200 && res.data is Map && (res.data as Map)['success'] == true) {
        _accountHasPin = true;
        _hasQuickPin = true;
        await _writeStorage('account_has_pin', 'true');
        return true;
      }
    } catch (e) {
      debugPrint('Notice saveAccountPin (mode hors-ligne ou indisponible): $e');
    }
    return false;
  }

  /// Réveille silencieusement le serveur et rafraîchit le JWT expiré en arrière-plan
  /// (pendant que l'utilisateur saisit son code PIN ou revient sur l'application).
  static Future<void> warmUpInBackground() async {
    if (!isAuthenticated || _refreshToken == null) return;
    if (JwtTokenUtils.isExpired(
      _accessToken,
      skew: AppConstants.proactiveRefreshThreshold,
    )) {
      await refreshSessionIfNeeded();
    }
  }

  /// Vérifie le code PIN côté serveur (source de vérité multi-appareils).
  /// Retourne `true` (valide), `false` (incorrect), ou `null` si serveur hors-ligne /
  /// en réveil ou compte pas encore migré (dans ce cas le client retombe sur le cache local).
  static Future<bool?> verifyAccountPin(
    String pin, {
    Duration maxWait = const Duration(seconds: 20),
  }) async {
    if (!isAuthenticated || !PinService.isValidPinFormat(pin)) return null;
    try {
      if (JwtTokenUtils.isExpired(
        _accessToken,
        skew: AppConstants.proactiveRefreshThreshold,
      )) {
        final refreshed = await _performRefresh().timeout(
          maxWait,
          onTimeout: () => false,
        );
        // Ne jamais lancer /auth/pin/verify avec un JWT encore expiré (évite un 2e cycle de timeout)
        if (!refreshed || !isAuthenticated || JwtTokenUtils.isExpired(_accessToken)) {
          return null;
        }
      }
      if (!isAuthenticated) return null;
      final res = await instance.post(
        '/auth/pin/verify',
        data: {'pin': pin},
        options: Options(
          sendTimeout: maxWait,
          receiveTimeout: maxWait,
          extra: const {'_skipAuthRetry': true},
        ),
      );
      if (res.statusCode == 200 && res.data is Map) {
        final data = (res.data as Map)['data'];
        if (data is Map && data['valid'] is bool) {
          final serverHasPin = data['hasPin'] == true;
          _accountHasPin = serverHasPin;
          await _writeStorage('account_has_pin', serverHasPin ? 'true' : 'false');
          if (!serverHasPin) {
            return null;
          }
          return data['valid'] as bool;
        }
      }
    } catch (e) {
      debugPrint('Notice verifyAccountPin (fallback local): $e');
    }
    return null;
  }

  /// Migre silencieusement un ancien PIN purement local vers le compte serveur.
  static Future<void> syncLocalPinToAccountIfNeeded(String pin) async {
    if (_accountHasPin || !isAuthenticated || !PinService.isValidPinFormat(pin)) return;
    await saveAccountPin(pin);
  }

  /// Verrouille l'application avec le code PIN rapide sans perdre la session ni l'écran courant.
  static void lockSession({String? reason}) {
    if (!isAuthenticated) return;
    SessionManager.instance.stopSession();
    lockReasonMessage = reason ?? 'Déverrouillage rapide';
    sessionLockedNotifier.value = true;
  }

  /// Déverrouille instantanément la session après validation du code PIN 4 chiffres.
  /// Le rafraîchissement du JWT s'effectue silencieusement en arrière-plan pour ne jamais
  /// bloquer l'écran PIN lors d'un réveil serveur Cloud (Render).
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

    lockReasonMessage = null;
    sessionLockedNotifier.value = false;
    SessionManager.instance.startSession();
    // Rafraîchir le JWT silencieusement en arrière-plan sans bloquer l'entrée dans l'app
    unawaited(refreshSessionIfNeeded());
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
      final savedTvaActive = await _readStorage('tva_active');
      _tvaActive = savedTvaActive == null ? true : savedTvaActive != 'false';
      final savedTauxTva = await _readStorage('taux_tva_defaut');
      _tauxTvaDefaut = double.tryParse(savedTauxTva ?? '') ?? (_tvaActive ? 18.0 : 0.0);
      final savedSuiviPa = await _readStorage('suivi_prix_achat');
      _suiviPrixAchat = savedSuiviPa == null ? true : savedSuiviPa != 'false';
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
      if (_accessToken != null || _refreshToken != null) {
        _accountHasPin = (await _readStorage('account_has_pin')) == 'true';
        _hasQuickPin = _accountHasPin || await PinService.instance.hasPin(_userEmail);
        final lastActivity = await readLastActivity();
        final isInactiveTooLong = lastActivity == null ||
            DateTime.now().difference(lastActivity) >=
                AppConstants.sessionInactivityTimeout;

        final accessExpired = JwtTokenUtils.isExpired(_accessToken);
        final refreshExpired =
            _refreshToken == null || JwtTokenUtils.isExpired(_refreshToken);

        // Si même le refresh token (365 jours glissants) est expiré → reconnexion complète obligatoire
        if (accessExpired && refreshExpired) {
          clearToken(
            expiredMessage: 'Votre session a expiré. Veuillez vous reconnecter.',
          );
          return;
        }

        // Dès qu'un code PIN est configuré : à chaque ouverture de l'app,
        // on demande UNIQUEMENT le code PIN à 4 chiffres (jamais email/mot de passe)
        if (_hasQuickPin) {
          lockReasonMessage = isInactiveTooLong
              ? 'Verrouillé après ${AppConstants.sessionInactivityTimeout.inMinutes} min d\'inactivité'
              : 'Déverrouillage rapide';
          sessionLockedNotifier.value = true;
          authStateNotifier.value = true;
          return;
        }

        // Utilisateur déjà connecté sans PIN (ex: migration depuis une ancienne version)
        if (!isInactiveTooLong) {
          pendingPinSetupPrompt = true;
          SessionManager.instance.restoreSession(lastActivity);
        } else {
          clearToken(
            expiredMessage:
                'Votre session a expiré après ${AppConstants.sessionInactivityTimeout.inMinutes} minutes d\'inactivité. Veuillez vous reconnecter.',
          );
          return;
        }
      }
    } catch (e) {
      debugPrint('Notice storage read in initialize: $e');
    }
    authStateNotifier.value = isAuthenticated;
  }

  /// Exécute un rafraîchissement unique (single-flight) du token d'accès.
  /// Toutes les requêtes 401 concurrentes partagent ce même appel sans jamais
  /// déconnecter l'utilisateur par erreur de concurrence.
  static Future<bool> _performRefresh({bool force = false}) {
    if (_activeRefreshFuture != null) {
      return _activeRefreshFuture!;
    }
    final completer = Completer<bool>();
    _activeRefreshFuture = completer.future;

    () async {
      try {
        if (!isAuthenticated || _refreshToken == null) {
          completer.complete(false);
          return;
        }
        if (!force &&
            !JwtTokenUtils.isExpired(
              _accessToken,
              skew: AppConstants.proactiveRefreshThreshold,
            )) {
          completer.complete(true);
          return;
        }

        if (JwtTokenUtils.isExpired(_refreshToken)) {
          clearToken(
            expiredMessage: 'Votre session a expiré. Veuillez vous reconnecter.',
          );
          onSessionExpired?.call();
          completer.complete(false);
          return;
        }

        final isCloud = ApiConstants.isCloudUrl;
        final refreshDio = Dio(BaseOptions(
          baseUrl: ApiConstants.baseUrl,
          connectTimeout: Duration(seconds: isCloud ? 35 : 15),
          receiveTimeout: Duration(seconds: isCloud ? 45 : 20),
        ));
        final res = await refreshDio.post('/auth/refresh', data: {
          'refreshToken': _refreshToken,
        });
        final data = res.data['data'] as Map<String, dynamic>?;
        final newAccessToken = data?['accessToken'] as String?;
        final newRefreshToken = data?['refreshToken'] as String?;
        if (newAccessToken != null && newAccessToken.isNotEmpty) {
          _accessToken = newAccessToken;
          await _writeStorage('access_token', newAccessToken);
        }
        if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
          _refreshToken = newRefreshToken;
          await _writeStorage('refresh_token', newRefreshToken);
        }
        final refreshedUser = data?['utilisateur'] as Map<String, dynamic>?;
        if (refreshedUser != null) {
          await _applyEntrepriseFlags(
            tvaActive: refreshedUser['tvaActive'] as bool?,
            tauxTvaDefaut: (refreshedUser['tauxTvaDefaut'] as num?)?.toDouble(),
            suiviPrixAchat: refreshedUser['suiviPrixAchat'] as bool?,
          );
          if (refreshedUser['hasPin'] is bool) {
            _accountHasPin = refreshedUser['hasPin'] as bool;
            if (_accountHasPin) _hasQuickPin = true;
            await _writeStorage('account_has_pin', _accountHasPin ? 'true' : 'false');
          }
        }
        completer.complete(newAccessToken != null && newAccessToken.isNotEmpty);
      } on DioException catch (e) {
        final code = e.response?.statusCode;
        if (code == 400 || code == 401 || code == 402 || code == 403) {
          final serverMsg = (e.response?.data is Map)
              ? (e.response!.data as Map)['message']?.toString()
              : null;
          clearToken(
            expiredMessage: serverMsg ??
                'Votre session a expiré. Veuillez vous reconnecter.',
          );
          onSessionExpired?.call();
        }
        // En cas d'erreur réseau passagère (timeout / hors-ligne), on conserve la session
        // et le code PIN pour éviter d'obliger le client à retaper ses identifiants.
        completer.complete(false);
      } catch (_) {
        completer.complete(false);
      } finally {
        _activeRefreshFuture = null;
      }
    }();

    return completer.future;
  }

  /// Rafraîchit silencieusement le JWT quand l'utilisateur est actif et que
  /// le token d'accès arrive à moins de 2 minutes de son expiration.
  static Future<void> refreshSessionIfNeeded() async {
    if (!isAuthenticated || _refreshToken == null) return;
    final needsRefresh = JwtTokenUtils.isExpired(
      _accessToken,
      skew: AppConstants.proactiveRefreshThreshold,
    );
    if (!needsRefresh) return;
    await _performRefresh();
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
      onRequest: (options, handler) async {
        // Toujours synchroniser l'URL courante (même pour les services ayant mis en cache ApiClient.instance)
        options.baseUrl = ApiConstants.baseUrl;
        final path = options.path;
        final skipAuthRetry = options.extra['_skipAuthRetry'] == true;
        final isPublicOrAuth = path.contains('/auth/login') ||
            path.contains('/auth/refresh') ||
            path.contains('/public/') ||
            path.contains('/health');
        if (!isPublicOrAuth && !skipAuthRetry && _refreshToken != null) {
          if (_activeRefreshFuture != null) {
            // Partager le rafraîchissement déjà en cours pour éviter une salve de 401 inutiles
            await _activeRefreshFuture;
          } else if (JwtTokenUtils.isExpired(_accessToken)) {
            await _performRefresh();
          }
        }
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

        // 2. 401 Unauthorized (ou 403 uniquement si le token d'accès est expiré) :
        //    tente un rafraîchissement unique (single-flight) partagé par toutes les requêtes concurrentes.
        final statusCode = error.response?.statusCode;
        final path = error.requestOptions.path;
        final alreadyRetried = error.requestOptions.extra['_authRetried'] == true;
        final skipAuthRetry = error.requestOptions.extra['_skipAuthRetry'] == true;
        final accessLooksExpired = JwtTokenUtils.isExpired(_accessToken);
        final isAuthFailure = statusCode == 401 || (statusCode == 403 && accessLooksExpired);

        if (isAuthFailure &&
            !alreadyRetried &&
            !skipAuthRetry &&
            _refreshToken != null &&
            !path.contains('/auth/login') &&
            !path.contains('/auth/refresh')) {
          final refreshSucceeded = await _performRefresh(force: true);
          if (refreshSucceeded && _accessToken != null) {
            try {
              error.requestOptions.extra['_authRetried'] = true;
              error.requestOptions.baseUrl = ApiConstants.baseUrl;
              error.requestOptions.headers['Authorization'] = 'Bearer $_accessToken';
              final retryResponse = await dio.fetch(error.requestOptions);
              return handler.resolve(retryResponse);
            } on DioException catch (retryErr) {
              return handler.next(retryErr);
            } catch (_) {
              return handler.next(error);
            }
          }
          return handler.next(error);
        } else if (statusCode == 401 && _refreshToken == null && !path.contains('/auth/')) {
          // Token absent ou invalide sans refresh token disponible
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
    bool? tvaActive,
    double? tauxTvaDefaut,
    bool? suiviPrixAchat,
    bool? hasPin,
    bool notifyAuth = true,
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
    _tvaActive = tvaActive ?? true;
    _tauxTvaDefaut = tauxTvaDefaut ?? (_tvaActive ? 18.0 : 0.0);
    _suiviPrixAchat = suiviPrixAchat ?? true;
    if (hasPin != null) {
      _accountHasPin = hasPin;
      if (hasPin) _hasQuickPin = true;
    }
    if (notifyAuth) {
      authStateNotifier.value = true;
    }

    try {
      await _writeStorage('user_role', role);
      await _writeStorage('user_name', name);
      await _writeStorage('user_email', email);
      await _writeStorage('user_permissions', permissions.join(','));
      await _writeStorage('entreprise_nom', _entrepriseNom!);
      await _writeStorage('entreprise_monnaie', _entrepriseMonnaie!);
      await _writeStorage('format_facture', _formatFacture!);
      await _writeStorage('is_super_admin', _isSuperAdmin ? 'true' : 'false');
      await _writeStorage('tva_active', _tvaActive ? 'true' : 'false');
      await _writeStorage('taux_tva_defaut', _tauxTvaDefaut.toString());
      await _writeStorage('suivi_prix_achat', _suiviPrixAchat ? 'true' : 'false');
      await _writeStorage('account_has_pin', _accountHasPin ? 'true' : 'false');
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

  static Future<void> _applyEntrepriseFlags({
    bool? tvaActive,
    double? tauxTvaDefaut,
    bool? suiviPrixAchat,
  }) async {
    if (tvaActive != null) {
      _tvaActive = tvaActive;
      await _writeStorage('tva_active', _tvaActive ? 'true' : 'false');
    }
    if (tauxTvaDefaut != null) {
      _tauxTvaDefaut = tauxTvaDefaut;
      await _writeStorage('taux_tva_defaut', _tauxTvaDefaut.toString());
    }
    if (suiviPrixAchat != null) {
      _suiviPrixAchat = suiviPrixAchat;
      await _writeStorage('suivi_prix_achat', _suiviPrixAchat ? 'true' : 'false');
    }
  }

  /// Synchronise discrètement les préférences fiscales/prix de l'entreprise depuis le backend.
  static Future<void> syncEntreprisePreferences() async {
    if (!isAuthenticated) return;
    try {
      final res = await instance.get('/entreprise');
      final data = res.data['data'] as Map<String, dynamic>?;
      if (data != null) {
        await _applyEntrepriseFlags(
          tvaActive: data['tvaActive'] as bool?,
          tauxTvaDefaut: (data['tauxTvaDefaut'] as num?)?.toDouble(),
          suiviPrixAchat: data['suiviPrixAchat'] as bool?,
        );
      }
    } catch (_) {}
  }

  static Future<void> updateEntrepriseInfo({
    required String nom,
    required String monnaie,
    required String formatFacture,
    String? logoUrl,
    bool? tvaActive,
    double? tauxTvaDefaut,
    bool? suiviPrixAchat,
  }) async {
    _entrepriseNom = nom;
    _entrepriseMonnaie = monnaie;
    _formatFacture = formatFacture;
    _logoUrl = logoUrl;
    if (tvaActive != null) _tvaActive = tvaActive;
    if (tauxTvaDefaut != null) _tauxTvaDefaut = tauxTvaDefaut;
    if (suiviPrixAchat != null) _suiviPrixAchat = suiviPrixAchat;
    try {
      await _writeStorage('entreprise_nom', nom);
      await _writeStorage('entreprise_monnaie', monnaie);
      await _writeStorage('format_facture', formatFacture);
      await _writeStorage('tva_active', _tvaActive ? 'true' : 'false');
      await _writeStorage('taux_tva_defaut', _tauxTvaDefaut.toString());
      await _writeStorage('suivi_prix_achat', _suiviPrixAchat ? 'true' : 'false');
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
    _accountHasPin = false;
    _entrepriseNom = null;
    _entrepriseMonnaie = null;
    _formatFacture = null;
    _logoUrl = null;
    _tvaActive = true;
    _tauxTvaDefaut = 18.0;
    _suiviPrixAchat = true;
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
      _deleteStorage('tva_active');
      _deleteStorage('taux_tva_defaut');
      _deleteStorage('suivi_prix_achat');
      _deleteStorage('account_has_pin');
      _deleteStorage('user_permissions');
    } catch (_) {}
  }

  /// Extrait un message lisible à afficher à l'utilisateur depuis une erreur Dio ou générique.
  static String formatErrorMessage(Object error, {String fallback = 'Une erreur est survenue.'}) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final msg = data['message']?.toString();
        if (msg != null && msg.trim().isNotEmpty) return msg.trim();
        final err = data['error']?.toString();
        if (err != null && err.trim().isNotEmpty) return err.trim();
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.connectionError) {
        return 'Impossible de joindre le serveur. Vérifiez votre connexion Internet.';
      }
      if (error.response?.statusCode != null) {
        return '$fallback (HTTP ${error.response!.statusCode})';
      }
    }
    return fallback;
  }

  static bool get isAuthenticated => _accessToken != null || _refreshToken != null;
  static bool get isSessionLocked => sessionLockedNotifier.value;
  static bool get hasQuickPin => _hasQuickPin;
  static bool get accountHasPin => _accountHasPin;
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
  static bool get tvaActive => _tvaActive;
  static double get tauxTvaDefaut => _tvaActive ? _tauxTvaDefaut : 0.0;
  static bool get suiviPrixAchat => _suiviPrixAchat;
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
