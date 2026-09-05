bool isVoiceSupported() => false;
void initJarvis() {}
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
}) {}
void startListening(String lang) {}
void stopListening() {}
void speak(String text) {}
void stopSpeaking() {}
