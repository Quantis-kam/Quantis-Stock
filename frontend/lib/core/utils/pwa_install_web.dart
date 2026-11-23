// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:js_util' as js_util;

Object? _pwaBridge() {
  try {
    if (js_util.hasProperty(html.window, 'quantisPwa')) {
      return js_util.getProperty<Object?>(html.window, 'quantisPwa');
    }
  } catch (_) {}
  return null;
}

void registerPwaStateListener(void Function() onChange) {
  try {
    html.window.addEventListener('quantis-pwa-state', (_) => onChange());
  } catch (_) {}
}

bool isStandalone() {
  try {
    final bridge = _pwaBridge();
    if (bridge != null) {
      return js_util.callMethod<bool>(bridge, 'isStandalone', const []);
    }
  } catch (_) {}
  return false;
}

bool canPrompt() {
  try {
    final bridge = _pwaBridge();
    if (bridge != null) {
      return js_util.callMethod<bool>(bridge, 'canPrompt', const []);
    }
  } catch (_) {}
  return false;
}

bool isIos() {
  try {
    final bridge = _pwaBridge();
    if (bridge != null) {
      return js_util.callMethod<bool>(bridge, 'isIos', const []);
    }
  } catch (_) {}
  return false;
}

Future<String> triggerInstall() async {
  try {
    final bridge = _pwaBridge();
    if (bridge == null) return 'unavailable';
    final promise = js_util.callMethod<Object>(bridge, 'triggerInstall', const []);
    final result = await js_util.promiseToFuture<Object?>(promise);
    return result?.toString() ?? 'unavailable';
  } catch (_) {
    return 'unavailable';
  }
}

