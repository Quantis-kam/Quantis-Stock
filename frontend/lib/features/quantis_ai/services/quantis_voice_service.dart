import 'dart:async';
import 'package:flutter/foundation.dart';

import 'quantis_voice_bridge.dart';

enum VoiceState {
  /// En veille — écoute les claps en arrière-plan
  standby,
  /// Activé — écoute la voix de l'utilisateur
  listening,
  /// Traitement — Quantis analyse et exécute
  processing,
  /// Parole — Quantis répond à voix haute
  speaking,
  /// Erreur
  error,
}

/// Représente une étape d'action visible dans le HUD
class ActionStep {
  final String id;
  final String label;
  final String icon;
  final ActionStatus status;
  final String? result;
  final DateTime timestamp;

  const ActionStep({
    required this.id,
    required this.label,
    this.icon = '⚙️',
    this.status = ActionStatus.running,
    this.result,
    required this.timestamp,
  });

  ActionStep copyWith({ActionStatus? status, String? result}) {
    return ActionStep(
      id: id,
      label: label,
      icon: icon,
      status: status ?? this.status,
      result: result ?? this.result,
      timestamp: timestamp,
    );
  }
}

enum ActionStatus { running, success, error }

/// Service Vocal Jarvis — Toujours prêt, activé par double clap
class QuantisVoiceService {
  static final QuantisVoiceService _instance = QuantisVoiceService._internal();
  factory QuantisVoiceService() => _instance;
  QuantisVoiceService._internal();

  bool _initialized = false;
  VoiceState _state = VoiceState.standby;
  VoiceState get state => _state;

  // Streams publics
  final _stateController = StreamController<VoiceState>.broadcast();
  Stream<VoiceState> get stateStream => _stateController.stream;

  final _partialTranscriptController = StreamController<String>.broadcast();
  Stream<String> get partialTranscriptStream => _partialTranscriptController.stream;

  final _finalTranscriptController = StreamController<String>.broadcast();
  Stream<String> get finalTranscriptStream => _finalTranscriptController.stream;

  final _audioLevelController = StreamController<double>.broadcast();
  Stream<double> get audioLevelStream => _audioLevelController.stream;

  final _wakeUpController = StreamController<void>.broadcast();
  Stream<void> get wakeUpStream => _wakeUpController.stream;

  final _speakWordController = StreamController<String>.broadcast();
  Stream<String> get speakWordStream => _speakWordController.stream;

  final _actionStepController = StreamController<List<ActionStep>>.broadcast();
  Stream<List<ActionStep>> get actionStepStream => _actionStepController.stream;

  final _silenceController = StreamController<void>.broadcast();
  Stream<void> get silenceStream => _silenceController.stream;

  // État interne
  bool _isMuted = false;
  bool get isMuted => _isMuted;
  set isMuted(bool val) {
    _isMuted = val;
    if (_isMuted) stopSpeaking();
  }

  final List<ActionStep> _currentActions = [];
  List<ActionStep> get currentActions => List.unmodifiable(_currentActions);

  String _lastSpokenWord = '';
  String get lastSpokenWord => _lastSpokenWord;

  void _setState(VoiceState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  /// Initialise le mode Jarvis — démarre la surveillance de claps
  void initJarvisMode() {
    if (!kIsWeb || _initialized) return;
    _initialized = true;

    try {
      _setupDartCallbacks();
      if (VoiceBridge.isSupported) {
        VoiceBridge.initJarvis();
        _setState(VoiceState.standby);
        debugPrint('[QuantisVoice] Mode Jarvis initialisé — surveillance double clap active');
      }
    } catch (e) {
      debugPrint('[QuantisVoice] Erreur init Jarvis: $e');
    }
  }

  void _setupDartCallbacks() {
    if (!kIsWeb) return;
    try {
      if (!VoiceBridge.isSupported) return;

      VoiceBridge.setupCallbacks(
        onWakeUp: () {
          debugPrint('[QuantisVoice] 👏👏 WAKE UP !');
          _wakeUpController.add(null);
          startListening();
        },
        onPartialTranscript: (text) {
          _partialTranscriptController.add(text);
        },
        onFinalTranscript: (text) {
          _finalTranscriptController.add(text);
        },
        onAudioLevel: (level) {
          _audioLevelController.add(level);
        },
        onListenStart: () {
          _setState(VoiceState.listening);
        },
        onListenEnd: () {
          if (_state == VoiceState.listening) {
            _setState(VoiceState.standby);
          }
        },
        onSpeakStart: () {
          _setState(VoiceState.speaking);
        },
        onSpeakWord: (word, charIndex, totalLength) {
          _lastSpokenWord = word;
          _speakWordController.add(word);
        },
        onSpeakEnd: () {
          if (_state == VoiceState.speaking) {
            _setState(VoiceState.standby);
          }
        },
        onSilenceTimeout: () {
          _silenceController.add(null);
          stopListening();
        },
        onError: (err) {
          debugPrint('[QuantisVoice] Erreur: $err');
          _setState(VoiceState.error);
          Future.delayed(const Duration(seconds: 2), () {
            if (_state == VoiceState.error) {
              _setState(VoiceState.standby);
            }
          });
        },
      );
    } catch (e) {
      debugPrint('[QuantisVoice] Erreur setup callbacks: $e');
    }
  }

  /// Démarre l'écoute vocale active
  void startListening({String lang = 'fr-FR'}) {
    if (!kIsWeb) return;
    try {
      stopSpeaking();
      if (VoiceBridge.isSupported) {
        VoiceBridge.startListening(lang);
        _setState(VoiceState.listening);
      }
    } catch (e) {
      debugPrint('[QuantisVoice] startListening error: $e');
      _setState(VoiceState.error);
    }
  }

  /// Arrête l'écoute et retourne en veille
  void stopListening() {
    if (!kIsWeb) return;
    try {
      if (VoiceBridge.isSupported) {
        VoiceBridge.stopListening();
      }
      if (_state == VoiceState.listening) {
        _setState(VoiceState.standby);
      }
    } catch (e) {
      debugPrint('[QuantisVoice] stopListening error: $e');
    }
  }

  /// Passe en mode processing (pendant l'appel API)
  void setProcessing() {
    _setState(VoiceState.processing);
  }

  /// Fait parler Quantis
  void speak(String text) {
    if (!kIsWeb || _isMuted) return;
    try {
      if (VoiceBridge.isSupported) {
        VoiceBridge.speak(text);
      }
    } catch (e) {
      debugPrint('[QuantisVoice] speak error: $e');
    }
  }

  /// Arrête la parole
  void stopSpeaking() {
    if (!kIsWeb) return;
    try {
      if (VoiceBridge.isSupported) {
        VoiceBridge.stopSpeaking();
      }
      if (_state == VoiceState.speaking) {
        _setState(VoiceState.standby);
      }
    } catch (e) {
      debugPrint('[QuantisVoice] stopSpeaking error: $e');
    }
  }

  // ═══════════════════════════════════════════
  // Timeline d'actions pour le HUD
  // ═══════════════════════════════════════════

  /// Ajoute une étape d'action visible dans le HUD
  void addAction(String id, String label, {String icon = '⚙️'}) {
    _currentActions.add(ActionStep(
      id: id,
      label: label,
      icon: icon,
      timestamp: DateTime.now(),
    ));
    _actionStepController.add(List.from(_currentActions));
  }

  /// Met à jour le statut d'une action
  void updateAction(String id, ActionStatus status, {String? result}) {
    final idx = _currentActions.indexWhere((a) => a.id == id);
    if (idx >= 0) {
      _currentActions[idx] = _currentActions[idx].copyWith(
        status: status,
        result: result,
      );
      _actionStepController.add(List.from(_currentActions));
    }
  }

  /// Efface toutes les actions (fin de cycle)
  void clearActions() {
    _currentActions.clear();
    _actionStepController.add([]);
  }

  void dispose() {
    _stateController.close();
    _partialTranscriptController.close();
    _finalTranscriptController.close();
    _audioLevelController.close();
    _wakeUpController.close();
    _speakWordController.close();
    _actionStepController.close();
    _silenceController.close();
  }
}
