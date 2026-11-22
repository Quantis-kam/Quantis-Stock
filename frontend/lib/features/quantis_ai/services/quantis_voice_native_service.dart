import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Service vocal natif pour Android, iOS et Desktop (hors Web).
/// Encapsule Speech-to-Text pour la reconnaissance et FlutterTts pour la synthèse.
class QuantisVoiceNativeService {
  static final QuantisVoiceNativeService _instance = QuantisVoiceNativeService._internal();
  factory QuantisVoiceNativeService() => _instance;
  QuantisVoiceNativeService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _isSpeechInitialized = false;
  bool _isTtsInitialized = false;
  bool _isListening = false;
  bool _isSpeaking = false;

  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;

  // Callbacks connectés au QuantisVoiceService
  VoidCallback? onListenStart;
  VoidCallback? onListenEnd;
  ValueChanged<String>? onPartialTranscript;
  ValueChanged<String>? onFinalTranscript;
  ValueChanged<double>? onAudioLevel;
  VoidCallback? onSpeakStart;
  ValueChanged<String>? onSpeakWord;
  VoidCallback? onSpeakEnd;
  ValueChanged<String>? onError;

  /// Initialise la reconnaissance et la synthèse vocale native
  Future<bool> initialize() async {
    if (kIsWeb) return false;

    // Initialisation TTS
    if (!_isTtsInitialized) {
      try {
        await _tts.setLanguage('fr-FR');
        await _tts.setSpeechRate(0.5);
        await _tts.setVolume(1.0);
        await _tts.setPitch(1.0);

        // Sélection d'une voix française naturelle (priorité Henri)
        try {
          final voices = await _tts.getVoices;
          if (voices is List) {
            dynamic selected;
            for (final v in voices) {
              if (v is Map) {
                final name = (v['name'] ?? '').toString().toLowerCase();
                final locale = (v['locale'] ?? '').toString().toLowerCase();
                if (locale.startsWith('fr') || locale.contains('fra')) {
                  if (name.contains('henri') || name.contains('male') || name.contains('homme')) {
                    selected = v;
                    break;
                  }
                  selected ??= v;
                }
              }
            }
            if (selected != null) {
              await _tts.setVoice({
                "name": selected["name"]?.toString() ?? '',
                "locale": selected["locale"]?.toString() ?? 'fr-FR',
              });
              debugPrint('[QuantisVoiceNative] Voix TTS active: ${selected["name"]}');
            }
          }
        } catch (_) {}

        _tts.setStartHandler(() {
          _isSpeaking = true;
          onSpeakStart?.call();
        });

        _tts.setCompletionHandler(() {
          _isSpeaking = false;
          onSpeakEnd?.call();
        });

        _tts.setCancelHandler(() {
          _isSpeaking = false;
          onSpeakEnd?.call();
        });

        _tts.setProgressHandler((text, start, end, word) {
          onSpeakWord?.call(word);
        });

        _tts.setErrorHandler((msg) {
          _isSpeaking = false;
          onError?.call('TTS error: $msg');
        });

        _isTtsInitialized = true;
      } catch (e) {
        debugPrint('[QuantisVoiceNative] Erreur init TTS: $e');
      }
    }

    // Initialisation STT
    if (!_isSpeechInitialized) {
      try {
        _isSpeechInitialized = await _speech.initialize(
          onStatus: (status) {
            debugPrint('[QuantisVoiceNative] STT status: $status');
            if (status == 'listening') {
              _isListening = true;
              onListenStart?.call();
            } else if (status == 'notListening' || status == 'done') {
              _isListening = false;
              onListenEnd?.call();
            }
          },
          onError: (errorNotification) {
            debugPrint('[QuantisVoiceNative] STT error: ${errorNotification.errorMsg}');
            _isListening = false;
            onError?.call(errorNotification.errorMsg);
          },
        );
      } catch (e) {
        debugPrint('[QuantisVoiceNative] Erreur init Speech: $e');
      }
    }

    return _isSpeechInitialized;
  }

  /// Démarre l'écoute au micro
  Future<void> startListening({String lang = 'fr_FR'}) async {
    if (kIsWeb) return;

    if (!_isSpeechInitialized) {
      final ok = await initialize();
      if (!ok) {
        onError?.call('Permissions micro requises ou reconnaissance vocale indisponible');
        return;
      }
    }

    if (_isSpeaking) {
      await stopSpeaking();
    }

    try {
      _isListening = true;
      onListenStart?.call();

      await _speech.listen(
        onResult: (result) {
          final words = result.recognizedWords;
          if (words.isNotEmpty) {
            if (result.finalResult) {
              onFinalTranscript?.call(words);
            } else {
              onPartialTranscript?.call(words);
            }
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.confirmation,
          cancelOnError: false,
          partialResults: true,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(milliseconds: 1800),
          localeId: lang,
        ),
        onSoundLevelChange: (level) {
          // level est généralement entre -10 et 10 dB
          final normalized = ((level + 10.0) / 20.0).clamp(0.0, 1.0);
          onAudioLevel?.call(normalized);
        },
      );
    } catch (e) {
      _isListening = false;
      onError?.call('Erreur micro: $e');
    }
  }

  /// Arrête l'écoute du micro
  Future<void> stopListening() async {
    if (kIsWeb) return;
    try {
      await _speech.stop();
      _isListening = false;
      onListenEnd?.call();
    } catch (_) {}
  }

  /// Synthèse vocale : lit le texte à voix haute
  Future<void> speak(String text, {String lang = 'fr-FR'}) async {
    if (kIsWeb) return;

    if (!_isTtsInitialized) {
      await initialize();
    }

    // Nettoyer les balises Markdown avant la synthèse vocale
    final cleanText = text
        .replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1')
        .replaceAll(RegExp(r'\*([^*]+)\*'), r'$1')
        .replaceAll(RegExp(r'#+\s*'), '')
        .replaceAll(RegExp(r'`([^`]+)`'), r'$1')
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1')
        .replaceAll(RegExp(r'[\u{1F300}-\u{1F9FF}]', unicode: true), '') // Emojis
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (cleanText.isEmpty) return;

    try {
      _isSpeaking = true;
      await _tts.speak(cleanText);
    } catch (e) {
      _isSpeaking = false;
      onError?.call('Erreur TTS speak: $e');
    }
  }

  /// Arrête la synthèse vocale
  Future<void> stopSpeaking() async {
    if (kIsWeb) return;
    try {
      await _tts.stop();
      _isSpeaking = false;
      onSpeakEnd?.call();
    } catch (_) {}
  }
}
