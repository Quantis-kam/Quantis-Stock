import 'dart:async';
import 'dart:convert';

import '../constants/app_constants.dart';

/// Utilitaires purs pour décoder l'expiration (`exp`) d'un JWT sans dépendance native.
class JwtTokenUtils {
  JwtTokenUtils._();

  /// Extrait la date d'expiration UTC du claim `exp` d'un JWT, ou `null` si illisible.
  static DateTime? getExpiration(String? token) {
    if (token == null || token.trim().isEmpty) return null;
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final normalized = base64Url.normalize(parts[1]);
      final payload = utf8.decode(base64Url.decode(normalized));
      final map = jsonDecode(payload);
      if (map is! Map<String, dynamic>) return null;
      final exp = map['exp'];
      if (exp is num) {
        return DateTime.fromMillisecondsSinceEpoch(
          exp.toInt() * 1000,
          isUtc: true,
        );
      }
    } catch (_) {}
    return null;
  }

  /// Retourne `true` si le token est absent, malformé ou expiré (avec marge [skew]).
  static bool isExpired(
    String? token, {
    Duration skew = Duration.zero,
    DateTime? now,
  }) {
    final exp = getExpiration(token);
    if (exp == null) return true;
    final currentUtc = (now ?? DateTime.now()).toUtc();
    return !exp.isAfter(currentUtc.add(skew));
  }
}

/// Gestionnaire central d'expiration de session par inactivité (30 min).
///
/// Fonctionne de façon cohérente que l'application reste ouverte, passe en
/// arrière-plan (ex: bascule rapide sur WhatsApp) ou soit complètement fermée.
class SessionManager {
  static final SessionManager instance = SessionManager._();
  SessionManager._();

  /// Constructeur dédié aux tests unitaires avec horloge injectable.
  SessionManager.forTest({
    DateTime Function()? clock,
    Duration? timeout,
    Duration? persistThrottle,
  })  : _clock = clock ?? DateTime.now,
        _timeout = timeout ?? AppConstants.sessionInactivityTimeout,
        _persistThrottle = persistThrottle ?? const Duration(seconds: 15);

  DateTime Function() _clock = DateTime.now;
  Duration _timeout = AppConstants.sessionInactivityTimeout;
  Duration _persistThrottle = const Duration(seconds: 15);

  DateTime? _lastActivityAt;
  DateTime? _lastPersistedAt;
  bool _isActive = false;
  Timer? _deadlineTimer;
  Timer? _heartbeatTimer;

  void Function(String reason)? _onSessionExpired;
  Future<void> Function(DateTime ts)? _onPersistLastActivity;
  Future<void> Function()? _onProactiveRefresh;
  bool Function()? _isAuthenticatedProvider;

  DateTime? get lastActivityAt => _lastActivityAt;
  bool get isActive => _isActive;

  void configure({
    required void Function(String reason) onSessionExpired,
    required Future<void> Function(DateTime ts) onPersistLastActivity,
    required Future<void> Function() onProactiveRefresh,
    required bool Function() isAuthenticatedProvider,
    Duration? timeout,
  }) {
    _onSessionExpired = onSessionExpired;
    _onPersistLastActivity = onPersistLastActivity;
    _onProactiveRefresh = onProactiveRefresh;
    _isAuthenticatedProvider = isAuthenticatedProvider;
    if (timeout != null) {
      _timeout = timeout;
    }
  }

  /// Démarre une nouvelle session après authentification.
  void startSession({DateTime? now}) {
    final ts = now ?? _clock();
    _isActive = true;
    _lastActivityAt = ts;
    _lastPersistedAt = ts;
    _persist(ts);
    _armTimers();
  }

  /// Restaure une session existante au démarrage à partir du dernier horodatage persisté.
  /// Retourne `false` si la session a déjà dépassé le délai d'inactivité.
  bool restoreSession(DateTime? lastActivity) {
    if (lastActivity == null) {
      return false;
    }
    final now = _clock();
    if (now.difference(lastActivity) >= _timeout) {
      return false;
    }
    _isActive = true;
    _lastActivityAt = lastActivity;
    _lastPersistedAt = lastActivity;
    _armTimers();
    return true;
  }

  /// Enregistre une interaction utilisateur réelle (clic, toucher, clavier, requête API).
  void recordActivity() {
    if (!_isActive) return;
    if (_isAuthenticatedProvider != null && !_isAuthenticatedProvider!()) {
      stopSession();
      return;
    }

    // Si le délai était déjà dépassé (ex: sortie de veille OS), expirer immédiatement
    if (checkExpiration()) return;

    final now = _clock();
    _lastActivityAt = now;
    _armTimers();

    if (_lastPersistedAt == null ||
        now.difference(_lastPersistedAt!) >= _persistThrottle) {
      _lastPersistedAt = now;
      _persist(now);
    }

    // Tant que l'utilisateur est actif, rafraîchir silencieusement si le JWT approche de sa fin
    final refresh = _onProactiveRefresh;
    if (refresh != null) {
      unawaited(refresh());
    }
  }

  /// Appelé lorsque l'application passe en arrière-plan ou se ferme :
  /// enregistre l'horodatage réel de la dernière activité sans prolonger la session.
  void onAppBackgrounded() {
    if (!_isActive || _lastActivityAt == null) return;
    _persist(_lastActivityAt!);
    _lastPersistedAt = _lastActivityAt;
  }

  /// Appelé au retour au premier plan : vérifie immédiatement si 30 min se sont écoulées.
  bool onAppResumed() {
    if (!_isActive) return false;
    if (checkExpiration()) {
      return true;
    }
    _armTimers();
    return false;
  }

  /// Vérifie si la session est expirée à l'instant courant.
  bool checkExpiration() {
    if (!_isActive) return false;
    final last = _lastActivityAt;
    if (last == null) {
      expireSession();
      return true;
    }
    final elapsed = _clock().difference(last);
    if (elapsed >= _timeout) {
      expireSession();
      return true;
    }
    return false;
  }

  /// Expire immédiatement la session et notifie l'application.
  void expireSession({String? customMessage}) {
    if (!_isActive) return;
    stopSession();
    final mins = _timeout.inMinutes;
    final msg = customMessage ??
        'Votre session a expiré après $mins minutes d\'inactivité. Veuillez vous reconnecter.';
    _onSessionExpired?.call(msg);
  }

  /// Arrête toute surveillance (après déconnexion volontaire ou expiration).
  void stopSession() {
    _isActive = false;
    _lastActivityAt = null;
    _lastPersistedAt = null;
    _deadlineTimer?.cancel();
    _deadlineTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _armTimers() {
    _deadlineTimer?.cancel();
    _heartbeatTimer?.cancel();

    final last = _lastActivityAt;
    if (!_isActive || last == null) return;

    final elapsed = _clock().difference(last);
    final remaining = _timeout - elapsed;
    if (remaining <= Duration.zero) {
      expireSession();
      return;
    }

    _deadlineTimer = Timer(remaining, checkExpiration);
    // Filet de sécurité si l'OS suspend temporairement le timer exact
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => checkExpiration(),
    );
  }

  void _persist(DateTime ts) {
    final persistFn = _onPersistLastActivity;
    if (persistFn != null) {
      unawaited(persistFn(ts));
    }
  }
}

