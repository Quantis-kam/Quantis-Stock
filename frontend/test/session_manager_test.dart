import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantis_stock/core/auth/session_manager.dart';
import 'package:quantis_stock/core/constants/app_constants.dart';

String _fakeJwt(DateTime expUtc) {
  final header = base64Url.encode(utf8.encode('{"alg":"HS256","typ":"JWT"}')).replaceAll('=', '');
  final payload = base64Url
      .encode(utf8.encode(jsonEncode({'sub': 'test@quantisbf.com', 'exp': expUtc.millisecondsSinceEpoch ~/ 1000})))
      .replaceAll('=', '');
  return '$header.$payload.signature';
}

void main() {
  test('Le délai d\'inactivité par défaut est bien de 30 minutes', () {
    expect(AppConstants.sessionInactivityTimeout, const Duration(minutes: 30));
  });

  test('JwtTokenUtils détecte correctement les tokens valides et expirés', () {
    final now = DateTime.utc(2026, 11, 22, 18, 0, 0);
    final validToken = _fakeJwt(now.add(const Duration(minutes: 15)));
    final expiredToken = _fakeJwt(now.subtract(const Duration(seconds: 10)));

    expect(JwtTokenUtils.isExpired(validToken, now: now), isFalse);
    expect(JwtTokenUtils.isExpired(expiredToken, now: now), isTrue);
    expect(
      JwtTokenUtils.isExpired(validToken, skew: const Duration(minutes: 16), now: now),
      isTrue,
    );
    expect(JwtTokenUtils.isExpired('not-a-jwt', now: now), isTrue);
    expect(JwtTokenUtils.isExpired(null, now: now), isTrue);
  });

  test('SessionManager expire la session au retour après 30 minutes en arrière-plan', () {
    var current = DateTime.utc(2026, 11, 22, 18, 0, 0);
    String? expiredReason;
    DateTime? persisted;

    final mgr = SessionManager.forTest(
      clock: () => current,
      timeout: const Duration(minutes: 30),
    );
    mgr.configure(
      onSessionExpired: (reason) => expiredReason = reason,
      onPersistLastActivity: (ts) async => persisted = ts,
      onProactiveRefresh: () async {},
      isAuthenticatedProvider: () => true,
    );

    mgr.startSession();
    expect(mgr.isActive, isTrue);
    expect(persisted, current);

    // Passage rapide sur WhatsApp (5 min) -> session toujours valide
    current = current.add(const Duration(minutes: 5));
    expect(mgr.onAppResumed(), isFalse);
    expect(mgr.isActive, isTrue);
    expect(expiredReason, isNull);

    // L'utilisateur enregistre une activité à t+5min puis met l'app en arrière-plan
    mgr.recordActivity();
    mgr.onAppBackgrounded();

    // 30 minutes plus tard (t+35min) -> expiration immédiate au retour
    current = current.add(const Duration(minutes: 30));
    expect(mgr.onAppResumed(), isTrue);
    expect(mgr.isActive, isFalse);
    expect(expiredReason, contains('30 minutes'));
  });

  test('restoreSession refuse une session fermée depuis 30+ minutes et accepte < 30 minutes', () {
    final now = DateTime.utc(2026, 11, 22, 19, 0, 0);
    final mgr = SessionManager.forTest(
      clock: () => now,
      timeout: const Duration(minutes: 30),
    );

    expect(mgr.restoreSession(null), isFalse);
    expect(mgr.restoreSession(now.subtract(const Duration(minutes: 31))), isFalse);
    expect(mgr.restoreSession(now.subtract(const Duration(minutes: 10))), isTrue);
    mgr.stopSession();
  });

  test('Une activité continue prolonge la session et déclenche le refresh proactif', () {
    var current = DateTime.utc(2026, 11, 22, 18, 0, 0);
    var refreshCalls = 0;
    String? expiredReason;

    final mgr = SessionManager.forTest(
      clock: () => current,
      timeout: const Duration(minutes: 30),
    );
    mgr.configure(
      onSessionExpired: (reason) => expiredReason = reason,
      onPersistLastActivity: (_) async {},
      onProactiveRefresh: () async => refreshCalls++,
      isAuthenticatedProvider: () => true,
    );

    mgr.startSession();

    // Interaction toutes les 20 minutes pendant 1 heure -> jamais déconnecté
    for (int i = 0; i < 3; i++) {
      current = current.add(const Duration(minutes: 20));
      mgr.recordActivity();
      expect(mgr.isActive, isTrue);
      expect(expiredReason, isNull);
    }
    expect(refreshCalls, 3);
    mgr.stopSession();
  });
}

