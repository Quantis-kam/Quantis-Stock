void registerPwaStateListener(void Function() onChange) {}

bool isStandalone() => true;

bool canPrompt() => false;

bool isIos() => false;

Future<String> triggerInstall() async => 'unavailable';

