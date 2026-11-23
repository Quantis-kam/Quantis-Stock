import 'package:flutter/foundation.dart';
import 'pwa_install_stub.dart'
    if (dart.library.html) 'pwa_install_web.dart' as platform;

/// Résultat d'une tentative d'installation PWA depuis le navigateur.
enum PwaInstallOutcome { accepted, dismissed, unavailable }

/// Pont multiplateforme pour l'installation de l'application web (PWA) sur téléphone / PC.
/// Sur Android APK natif ou lorsque la PWA est déjà installée, `shouldShowButton` vaut `false`.
class PwaInstallHelper {
  PwaInstallHelper._();

  static final ValueNotifier<int> stateVersion = ValueNotifier<int>(0);
  static bool _initialized = false;

  static void init() {
    if (_initialized) return;
    _initialized = true;
    platform.registerPwaStateListener(() {
      stateVersion.value++;
    });
  }

  /// Vrai uniquement dans un navigateur Web non installé (pas dans l'APK ni en mode standalone).
  static bool get shouldShowButton => kIsWeb && !platform.isStandalone();

  /// Vrai lorsque Chrome / Edge / Samsung Internet a préparé le bouton natif en 1 clic.
  static bool get canPromptNatively => kIsWeb && platform.canPrompt();

  /// Vrai sur iPhone / iPad (Safari).
  static bool get isIos => kIsWeb && platform.isIos();

  /// Déclenche la boîte de dialogue d'installation native si disponible.
  static Future<PwaInstallOutcome> triggerInstall() async {
    if (!kIsWeb) return PwaInstallOutcome.unavailable;
    final res = await platform.triggerInstall();
    stateVersion.value++;
    return switch (res) {
      'accepted' => PwaInstallOutcome.accepted,
      'dismissed' => PwaInstallOutcome.dismissed,
      _ => PwaInstallOutcome.unavailable,
    };
  }
}

