// ignore: avoid_web_libraries_in_flutter
import 'dart:js_util' as js_util;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/foundation.dart';

dynamic _getBridge() {
  try {
    if (js_util.hasProperty(html.window, 'QuantisVoice')) {
      return js_util.getProperty(html.window, 'QuantisVoice');
    }
  } catch (_) {}
  return null;
}

bool isVoiceSupported() => _getBridge() != null;

void initJarvis() {
  final b = _getBridge();
  if (b != null) {
    js_util.callMethod(b, 'initJarvis', []);
  }
}

void setupVoiceCallbacks({
  required void Function() onWakeUp,
  required void Function(String text) onPartialTranscript,
  required void Function(String text) onFinalTranscript,
  required void Function(double level) onAudioLevel,
  required void Function() onListenStart,
  required void Function() onListenEnd,
  required void Function() onSpeakStart,
  required void Function(String word, int charIndex, int totalLength) onSpeakWord,
  required void Function() onSpeakEnd,
  required void Function() onSilenceTimeout,
  required void Function(dynamic error) onError,
}) {
  try {
    final b = _getBridge();
    if (b == null) return;
    final listeners = js_util.getProperty(b, 'listeners');
    if (listeners == null) return;

    js_util.setProperty(listeners, 'onWakeUp', js_util.allowInterop(() => onWakeUp()));
    js_util.setProperty(listeners, 'onPartialTranscript', js_util.allowInterop((dynamic text) => onPartialTranscript(text?.toString() ?? '')));
    js_util.setProperty(listeners, 'onFinalTranscript', js_util.allowInterop((dynamic text) => onFinalTranscript(text?.toString() ?? '')));
    js_util.setProperty(listeners, 'onAudioLevel', js_util.allowInterop((dynamic level) => onAudioLevel((level as num?)?.toDouble() ?? 0.0)));
    js_util.setProperty(listeners, 'onListenStart', js_util.allowInterop(() => onListenStart()));
    js_util.setProperty(listeners, 'onListenEnd', js_util.allowInterop(() => onListenEnd()));
    js_util.setProperty(listeners, 'onSpeakStart', js_util.allowInterop(() => onSpeakStart()));
    js_util.setProperty(listeners, 'onSpeakWord', js_util.allowInterop((dynamic word, dynamic charIndex, dynamic totalLength) {
      onSpeakWord(word?.toString() ?? '', (charIndex as num?)?.toInt() ?? 0, (totalLength as num?)?.toInt() ?? 0);
    }));
    js_util.setProperty(listeners, 'onSpeakEnd', js_util.allowInterop(() => onSpeakEnd()));
    js_util.setProperty(listeners, 'onSilenceTimeout', js_util.allowInterop(() => onSilenceTimeout()));
    js_util.setProperty(listeners, 'onError', js_util.allowInterop((dynamic err) => onError(err)));
  } catch (e) {
    debugPrint('[QuantisVoice] Erreur bridge setup callbacks: $e');
  }
}

void startListening(String lang) {
  final b = _getBridge();
  if (b != null) js_util.callMethod(b, 'startListening', [lang]);
}

void stopListening() {
  final b = _getBridge();
  if (b != null) js_util.callMethod(b, 'stopListening', []);
}

void speak(String text) {
  final b = _getBridge();
  if (b != null) js_util.callMethod(b, 'speak', [text]);
}

void stopSpeaking() {
  final b = _getBridge();
  if (b != null) js_util.callMethod(b, 'stopSpeaking', []);
}
