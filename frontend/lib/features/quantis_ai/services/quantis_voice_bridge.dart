import 'quantis_voice_bridge_stub.dart'
    if (dart.library.html) 'quantis_voice_bridge_web.dart' as bridge;

class VoiceBridge {
  static bool get isSupported => bridge.isVoiceSupported();
  static void initJarvis() => bridge.initJarvis();
  static void setupCallbacks({
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
  }) => bridge.setupVoiceCallbacks(
    onWakeUp: onWakeUp,
    onPartialTranscript: onPartialTranscript,
    onFinalTranscript: onFinalTranscript,
    onAudioLevel: onAudioLevel,
    onListenStart: onListenStart,
    onListenEnd: onListenEnd,
    onSpeakStart: onSpeakStart,
    onSpeakWord: onSpeakWord,
    onSpeakEnd: onSpeakEnd,
    onSilenceTimeout: onSilenceTimeout,
    onError: onError,
  );
  static void startListening(String lang) => bridge.startListening(lang);
  static void stopListening() => bridge.stopListening();
  static void speak(String text) => bridge.speak(text);
  static void stopSpeaking() => bridge.stopSpeaking();
}
