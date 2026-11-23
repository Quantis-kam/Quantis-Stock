import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantis_stock/core/auth/pin_service.dart';
import 'package:quantis_stock/core/network/api_client.dart';
import 'package:quantis_stock/features/admin/presentation/platform_admin_portal.dart';
import 'package:quantis_stock/features/auth/presentation/login_screen.dart';
import 'package:quantis_stock/features/auth/presentation/pin_lock_screen.dart';
import 'package:quantis_stock/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    final storage = <String, String>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      final args = (call.arguments as Map?)?.cast<String, dynamic>() ?? {};
      final key = args['key'] as String?;
      switch (call.method) {
        case 'read':
          return key != null ? storage[key] : null;
        case 'write':
          if (key != null && args['value'] != null) {
            storage[key] = args['value'] as String;
          }
          return null;
        case 'delete':
          if (key != null) storage.remove(key);
          return null;
        default:
          return null;
      }
    });
  });

  testWidgets('Transition Login -> MainShell -> Verrouillage PIN -> Logout -> SuperAdmin', (tester) async {
    tester.view.physicalSize = const Size(2400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    ApiClient.clearToken();
    await tester.pumpWidget(const ProviderScope(child: QuantisStockApp()));
    await tester.pump();
    expect(find.byType(LoginScreen), findsOneWidget);

    const validJwt =
        'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ0ZXN0QHF1YW50aXNiZi5jb20iLCJleHAiOjQ3MDAwMDAwMDB9.sig';

    // 1. Connexion commerçant + proposition PIN post-login
    await ApiClient.saveTokens(validJwt, validJwt);
    await ApiClient.setUserInfo(
      'VENDEUR',
      'Moussa Diallo',
      'moussa@boutique.bf',
      [],
      isSuperAdmin: false,
      notifyAuth: false,
    );
    ApiClient.pendingPinSetupPrompt = true;
    ApiClient.authStateNotifier.value = true;

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(MainShell), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(PinSetupDialog), findsOneWidget);

    // Création du code PIN obligatoire dès la 1re connexion (aucun bouton "Plus tard")
    expect(find.text('Plus tard'), findsNothing);
    expect(find.text('Créez votre Code PIN (4 chiffres)'), findsOneWidget);

    // Étape 1/2 : saisir 2-4-6-8
    for (final digit in ['2', '4', '6', '8']) {
      await tester.tap(find.text(digit).last);
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 200));

    // Étape 2/2 : confirmer 2-4-6-8
    for (final digit in ['2', '4', '6', '8']) {
      await tester.tap(find.text(digit).last);
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.byType(PinSetupDialog), findsNothing);
    expect(ApiClient.hasQuickPin, isTrue);

    // 2. Simulation fermeture/réouverture de l'app -> uniquement le code PIN est demandé
    await ApiClient.initialize();
    await tester.pump();
    expect(find.byType(PinLockScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(MainShell), findsOneWidget);

    // 3. Déverrouillage PIN (saisie 2-4-6-8 sur le pavé numérique) -> retour direct à MainShell
    for (final digit in ['2', '4', '6', '8']) {
      await tester.tap(find.text(digit).last);
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.byType(PinLockScreen), findsNothing);
    expect(find.byType(MainShell), findsOneWidget);

    // 4. Déconnexion -> retour propre à LoginScreen
    ApiClient.clearToken();
    await tester.pump();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(MainShell), findsNothing);

    // 5. Connexion SuperAdmin -> PlatformAdminPortal
    await ApiClient.saveTokens(validJwt, validJwt);
    await ApiClient.setUserInfo(
      'SUPER_ADMIN',
      'Super Admin',
      'superadmin@quantisbf.com',
      [],
      isSuperAdmin: true,
      notifyAuth: false,
    );
    ApiClient.authStateNotifier.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(PlatformAdminPortal), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);

    // Nettoyage timers
    ApiClient.clearToken();
    await tester.pump();
  });

  testWidgets('Démarrage à froid avec PIN configuré : affiche directement PinLockScreen sans LoginScreen ni MainShell', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const validJwt =
        'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ0ZXN0QHF1YW50aXNiZi5jb20iLCJleHAiOjQ3MDAwMDAwMDB9.sig';

    // Simule une 1re connexion antérieure avec PIN 2468 enregistré
    ApiClient.clearToken();
    await ApiClient.saveTokens(validJwt, validJwt);
    await ApiClient.setUserInfo(
      'ADMIN',
      'Moussa Kaboré',
      'moussa@faso.bf',
      [],
      isSuperAdmin: false,
      notifyAuth: false,
    );
    await PinService.instance.setPin('moussa@faso.bf', '2468');

    // Simule un redémarrage à froid de l'application
    await ApiClient.initialize();
    await tester.pumpWidget(const ProviderScope(child: QuantisStockApp()));
    await tester.pump();

    // Uniquement l'écran Code PIN est visible : pas de LoginScreen, et MainShell pas encore monté
    expect(find.byType(PinLockScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(MainShell), findsNothing);

    // Saisie du code PIN 2-4-6-8 -> déverrouillage direct vers MainShell
    for (final digit in ['2', '4', '6', '8']) {
      await tester.tap(find.text(digit).last);
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.byType(PinLockScreen), findsNothing);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(MainShell), findsOneWidget);

    ApiClient.clearToken();
    await tester.pump();
  });
}
