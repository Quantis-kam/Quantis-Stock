import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantis_stock/core/auth/pin_service.dart';
import 'package:quantis_stock/features/auth/presentation/pin_lock_screen.dart';

class _InMemoryPinStore implements PinKeyValueStore {
  final Map<String, String> data = {};

  @override
  Future<void> delete(String key) async => data.remove(key);

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async => data[key] = value;
}

void main() {
  test('PinService stocke uniquement un condensat salé et valide le PIN', () async {
    final store = _InMemoryPinStore();
    final pinService = PinService.withStore(store);

    expect(await pinService.hasPin('moussa@boutique.bf'), isFalse);

    await pinService.setPin('moussa@boutique.bf', '2468');
    expect(await pinService.hasPin('moussa@boutique.bf'), isTrue);
    expect(await pinService.hasPin('autre@boutique.bf'), isFalse);

    // Le code PIN en clair ne doit jamais apparaître dans le stockage
    expect(store.data.values.any((v) => v.contains('2468')), isFalse);

    expect(await pinService.matchesPin('moussa@boutique.bf', '2468'), isTrue);
    expect(await pinService.matchesPin('moussa@boutique.bf', '0000'), isFalse);
    // matchesPin en lecture seule ne doit pas consommer de tentative
    expect(await pinService.getRemainingAttempts('moussa@boutique.bf'), 5);

    final ok = await pinService.verifyPin('moussa@boutique.bf', '2468');
    expect(ok.isValid, isTrue);
    expect(ok.isLockedOut, isFalse);
  });

  test('PinService bloque après 5 tentatives erronées et réinitialise sur succès', () async {
    final store = _InMemoryPinStore();
    final pinService = PinService.withStore(store);
    await pinService.setPin('gerant@quantisbf.com', '1357');

    // 2 erreurs -> reste 3 essais
    var r = await pinService.verifyPin('gerant@quantisbf.com', '0000');
    expect(r.isValid, isFalse);
    expect(r.remainingAttempts, 4);
    expect(r.isLockedOut, isFalse);

    r = await pinService.verifyPin('gerant@quantisbf.com', '9999');
    expect(r.remainingAttempts, 3);

    // Bon PIN -> compteur remis à 5
    r = await pinService.verifyPin('gerant@quantisbf.com', '1357');
    expect(r.isValid, isTrue);
    expect(await pinService.getRemainingAttempts('gerant@quantisbf.com'), 5);

    // 5 erreurs consécutives -> verrouillage (retour mot de passe)
    for (int i = 1; i <= 4; i++) {
      r = await pinService.verifyPin('gerant@quantisbf.com', '1111');
      expect(r.isLockedOut, isFalse);
      expect(r.remainingAttempts, 5 - i);
    }
    r = await pinService.verifyPin('gerant@quantisbf.com', '1111');
    expect(r.isValid, isFalse);
    expect(r.isLockedOut, isTrue);
    expect(r.remainingAttempts, 0);
  });

  test('PinService refuse les formats invalides et gère la suppression', () async {
    final store = _InMemoryPinStore();
    final pinService = PinService.withStore(store);

    expect(() => pinService.setPin('a@b.com', '123'), throwsArgumentError);
    expect(() => pinService.setPin('a@b.com', '12ab'), throwsArgumentError);

    expect(await pinService.shouldPromptPinSetup('a@b.com'), isTrue);
    await pinService.markPinSetupPrompted('a@b.com');
    expect(await pinService.shouldPromptPinSetup('a@b.com'), isFalse);

    await pinService.setPin('a@b.com', '4321');
    expect(await pinService.hasPin('a@b.com'), isTrue);
    await pinService.removePin('a@b.com');
    expect(await pinService.hasPin('a@b.com'), isFalse);
  });

  testWidgets('PinLockScreen affiche le pavé numérique et l\'option mot de passe', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PinLockScreen()));

    expect(find.text('Saisissez votre code PIN à 4 chiffres'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('Effacer'), findsOneWidget);
    expect(find.text('Changer de compte / Code PIN oublié'), findsOneWidget);
  });
}

