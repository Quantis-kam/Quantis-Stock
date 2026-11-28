import 'dart:convert';
import 'dart:math';

// ignore: depend_on_referenced_packages
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Résultat d'une tentative de vérification de code PIN.
class PinVerifyResult {
  final bool isValid;
  final int remainingAttempts;
  final bool isLockedOut;

  const PinVerifyResult({
    required this.isValid,
    required this.remainingAttempts,
    required this.isLockedOut,
  });
}

/// Interface simple de stockage clé/valeur (permet les tests unitaires en mémoire).
abstract class PinKeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class _SecurePinStore implements PinKeyValueStore {
  static const _storage = FlutterSecureStorage(
    webOptions: WebOptions(
      dbName: 'quantis_stock_db',
      publicKey: 'quantis_stock_public_key',
    ),
  );
  final Map<String, String> _fallback = {};

  @override
  Future<String?> read(String key) async {
    try {
      final val = await _storage.read(key: key);
      if (val != null) {
        _fallback[key] = val;
        return val;
      }
    } catch (_) {}
    return _fallback[key];
  }

  @override
  Future<void> write(String key, String value) async {
    _fallback[key] = value;
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {}
  }

  @override
  Future<void> delete(String key) async {
    _fallback.remove(key);
    try {
      await _storage.delete(key: key);
    } catch (_) {}
  }
}

/// Service de code PIN rapide à 4 chiffres (modèle Wave / Orange Money).
///
/// Le PIN n'est jamais enregistré en clair : il est protégé par un sel aléatoire
/// par utilisateur et des itérations HMAC-SHA256 dans le stockage sécurisé.
class PinService {
  static final PinService instance = PinService._(_SecurePinStore());

  static const int pinLength = 4;
  static const int maxFailedAttempts = 5;
  static const int _hashIterations = 2000;

  final PinKeyValueStore _store;

  PinService._(this._store);

  /// Constructeur dédié aux tests unitaires avec store en mémoire.
  PinService.withStore(this._store);

  static bool isValidPinFormat(String pin) => RegExp(r'^\d{4}$').hasMatch(pin);

  String _userScope(String email) {
    final normalized = email.trim().toLowerCase();
    return sha256.convert(utf8.encode(normalized)).toString().substring(0, 16);
  }

  String _hashKey(String email) => 'qpin_hash_${_userScope(email)}';
  String _saltKey(String email) => 'qpin_salt_${_userScope(email)}';
  String _attemptsKey(String email) => 'qpin_attempts_${_userScope(email)}';
  String _promptedKey(String email) => 'qpin_prompted_${_userScope(email)}';

  String _generateSalt() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return base64Url.encode(bytes);
  }

  String _deriveDigest(String email, String pin, String salt) {
    final normalizedEmail = email.trim().toLowerCase();
    final hmac = Hmac(sha256, utf8.encode(salt));
    List<int> current = utf8.encode('$salt:$normalizedEmail:$pin');
    for (var i = 0; i < _hashIterations; i++) {
      current = hmac.convert(current).bytes;
    }
    return base64Url.encode(current);
  }

  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  /// Indique si l'utilisateur a activé un code PIN rapide sur cet appareil.
  Future<bool> hasPin(String? email) async {
    if (email == null || email.trim().isEmpty) return false;
    final hash = await _store.read(_hashKey(email));
    final salt = await _store.read(_saltKey(email));
    return hash != null && hash.isNotEmpty && salt != null && salt.isNotEmpty;
  }

  /// Enregistre ou remplace le code PIN à 4 chiffres de l'utilisateur.
  Future<void> setPin(String email, String pin) async {
    if (!isValidPinFormat(pin)) {
      throw ArgumentError('Le code PIN doit contenir exactement 4 chiffres.');
    }
    final salt = _generateSalt();
    final digest = _deriveDigest(email, pin, salt);
    await _store.write(_saltKey(email), salt);
    await _store.write(_hashKey(email), digest);
    await _store.write(_attemptsKey(email), '0');
    await _store.write(_promptedKey(email), 'true');
  }

  /// Supprime le code PIN rapide de l'utilisateur sur cet appareil.
  Future<void> removePin(String email) async {
    await _store.delete(_hashKey(email));
    await _store.delete(_saltKey(email));
    await _store.delete(_attemptsKey(email));
  }

  /// Vérifie en lecture seule si [pin] correspond au condensat local sans toucher au compteur d'échecs.
  Future<bool> matchesPin(String email, String pin) async {
    if (!isValidPinFormat(pin)) return false;
    final expectedHash = await _store.read(_hashKey(email));
    final salt = await _store.read(_saltKey(email));
    if (expectedHash == null || salt == null) return false;
    final candidate = _deriveDigest(email, pin, salt);
    return _constantTimeEquals(candidate, expectedHash);
  }

  /// Vérifie un code PIN saisi et gère le compteur de tentatives (max 5).
  Future<PinVerifyResult> verifyPin(String email, String pin) async {
    final expectedHash = await _store.read(_hashKey(email));
    final salt = await _store.read(_saltKey(email));
    if (expectedHash == null || salt == null) {
      return const PinVerifyResult(
        isValid: false,
        remainingAttempts: 0,
        isLockedOut: true,
      );
    }

    if (isValidPinFormat(pin)) {
      final candidate = _deriveDigest(email, pin, salt);
      if (_constantTimeEquals(candidate, expectedHash)) {
        await resetFailedAttempts(email);
        return const PinVerifyResult(
          isValid: true,
          remainingAttempts: maxFailedAttempts,
          isLockedOut: false,
        );
      }
    }

    return recordFailedAttempt(email);
  }

  /// Enregistre un échec de saisie de code PIN et retourne le nombre d'essais restants.
  Future<PinVerifyResult> recordFailedAttempt(String email) async {
    final currentFailed = int.tryParse(await _store.read(_attemptsKey(email)) ?? '0') ?? 0;
    final nextFailed = currentFailed + 1;
    final remaining = (maxFailedAttempts - nextFailed).clamp(0, maxFailedAttempts);

    if (nextFailed >= maxFailedAttempts) {
      await _store.write(_attemptsKey(email), '0');
      return const PinVerifyResult(
        isValid: false,
        remainingAttempts: 0,
        isLockedOut: true,
      );
    }

    await _store.write(_attemptsKey(email), nextFailed.toString());
    return PinVerifyResult(
      isValid: false,
      remainingAttempts: remaining,
      isLockedOut: false,
    );
  }

  Future<int> getRemainingAttempts(String email) async {
    final failed = int.tryParse(await _store.read(_attemptsKey(email)) ?? '0') ?? 0;
    return (maxFailedAttempts - failed).clamp(0, maxFailedAttempts);
  }

  Future<void> resetFailedAttempts(String email) async {
    await _store.write(_attemptsKey(email), '0');
  }

  /// Retourne `true` si on doit proposer la création du PIN après la 1re connexion.
  Future<bool> shouldPromptPinSetup(String? email) async {
    if (email == null || email.trim().isEmpty) return false;
    if (await hasPin(email)) return false;
    final alreadyPrompted = await _store.read(_promptedKey(email));
    return alreadyPrompted != 'true';
  }

  Future<void> markPinSetupPrompted(String email) async {
    await _store.write(_promptedKey(email), 'true');
  }
}

