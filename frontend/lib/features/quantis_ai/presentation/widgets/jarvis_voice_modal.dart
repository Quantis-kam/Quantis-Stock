import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/quantis_ai_controller.dart';
import '../../services/quantis_voice_service.dart';
import 'jarvis_orb_visualizer.dart';

/// Modal immersif plein écran — Mode Jarvis avancé (optionnel)
/// Accessible via long-press sur le HUD ou depuis le menu
class JarvisVoiceModal extends ConsumerStatefulWidget {
  const JarvisVoiceModal({super.key});

  static Future<void> show(BuildContext context) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Jarvis Voice Mode',
      barrierColor: Colors.black.withValues(alpha: 0.85),
      pageBuilder: (context, anim1, anim2) => const JarvisVoiceModal(),
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  ConsumerState<JarvisVoiceModal> createState() => _JarvisVoiceModalState();
}

class _JarvisVoiceModalState extends ConsumerState<JarvisVoiceModal> {
  final _voiceService = QuantisVoiceService();
  VoiceState _state = VoiceState.standby;
  double _audioLevel = 0.0;
  String _currentTranscript = '';
  String _lastAssistantResponse = '';
  List<ActionStep> _actions = [];

  final _manualInputController = TextEditingController();

  StreamSubscription? _stateSub;
  StreamSubscription? _audioSub;
  StreamSubscription? _partialSub;
  StreamSubscription? _finalSub;
  StreamSubscription? _actionSub;

  @override
  void initState() {
    super.initState();

    _stateSub = _voiceService.stateStream.listen((state) {
      if (mounted) setState(() => _state = state);
    });

    _audioSub = _voiceService.audioLevelStream.listen((level) {
      if (mounted) setState(() => _audioLevel = level);
    });

    _partialSub = _voiceService.partialTranscriptStream.listen((text) {
      if (mounted) setState(() => _currentTranscript = text);
    });

    _finalSub = _voiceService.finalTranscriptStream.listen((text) {
      if (mounted) {
        setState(() => _currentTranscript = text);
        _handleFinalSpeech(text);
      }
    });

    _actionSub = _voiceService.actionStepStream.listen((actions) {
      if (mounted) setState(() => _actions = actions);
    });

    // Démarrer l'écoute dès l'ouverture
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _voiceService.startListening();
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _audioSub?.cancel();
    _partialSub?.cancel();
    _finalSub?.cancel();
    _actionSub?.cancel();
    _manualInputController.dispose();
    _voiceService.stopListening();
    _voiceService.stopSpeaking();
    super.dispose();
  }

  void _toggleListening() {
    if (_state == VoiceState.listening) {
      final textToSubmit = _currentTranscript.trim();
      _voiceService.stopListening();
      if (textToSubmit.isNotEmpty) {
        _handleFinalSpeech(textToSubmit);
      }
    } else {
      setState(() {
        _currentTranscript = '';
        _lastAssistantResponse = '';
      });
      _voiceService.startListening();
    }
  }

  Future<void> _handleFinalSpeech(String speechText) async {
    final trimmed = speechText.trim();
    if (trimmed.isEmpty || _state == VoiceState.processing) return;

    _voiceService.stopListening();
    _voiceService.setProcessing();

    _voiceService.clearActions();
    _voiceService.addAction('analyze', 'Analyse de votre demande...', icon: '🧠');

    final response = await ref.read(quantisAiProvider.notifier).sendMessage(trimmed);

    _voiceService.updateAction('analyze', ActionStatus.success, result: 'Compris');

    if (response != null && mounted) {
      setState(() => _lastAssistantResponse = response.text);

      _voiceService.addAction('speak', 'Réponse vocale...', icon: '🔊');
      _voiceService.speak(response.text);

      Future.delayed(const Duration(seconds: 1), () {
        _voiceService.updateAction('speak', ActionStatus.success);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final aiState = ref.watch(quantisAiProvider);
    final isProcessing = aiState.isLoading || _state == VoiceState.processing;
    final effectiveState = isProcessing ? VoiceState.processing : _state;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [
              const Color(0xFF0F172A).withValues(alpha: 0.98),
              const Color(0xFF020617).withValues(alpha: 0.99),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF00E5FF),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            "QUANTIS // MODE JARVIS",
                            style: TextStyle(
                              color: Color(0xFF00E5FF),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        _voiceService.isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                        color: Colors.white70,
                      ),
                      onPressed: () {
                        setState(() {
                          _voiceService.isMuted = !_voiceService.isMuted;
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Orbe holographique
              JarvisOrbVisualizer(
                state: effectiveState,
                audioLevel: _audioLevel,
                size: 240,
                onTap: _toggleListening,
              ),

              const SizedBox(height: 32),

              // Statut
              Text(
                _getStatusText(effectiveState),
                style: TextStyle(
                  color: _getStatusColor(effectiveState),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),

              const SizedBox(height: 24),

              // Timeline d'actions
              if (_actions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _actions.map((action) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: action.status == ActionStatus.running
                                ? SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(
                                        _getStatusColor(effectiveState),
                                      ),
                                    ),
                                  )
                                : Icon(
                                    action.status == ActionStatus.success
                                        ? Icons.check_circle_rounded
                                        : Icons.error_rounded,
                                    color: action.status == ActionStatus.success
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFEF4444),
                                    size: 18,
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Text(action.icon, style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 8),
                          Text(
                            action.label,
                            style: TextStyle(
                              color: action.status == ActionStatus.running
                                  ? Colors.white
                                  : Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )).toList(),
                  ),
                ),

              const SizedBox(height: 16),

              // Transcription / Réponse
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  constraints: const BoxConstraints(minHeight: 80, maxHeight: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_currentTranscript.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(bottom: _lastAssistantResponse.isNotEmpty ? 8 : 0),
                            child: Text(
                              "🗣️ « $_currentTranscript »",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF00E5FF),
                                fontSize: 15,
                                fontStyle: FontStyle.italic,
                                height: 1.4,
                              ),
                            ),
                          ),
                        if (_lastAssistantResponse.isNotEmpty)
                          Text(
                            _lastAssistantResponse,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              height: 1.4,
                            ),
                          ),
                        if (_currentTranscript.isEmpty && _lastAssistantResponse.isEmpty)
                          const Text(
                            "Parlez pour interagir avec Quantis.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 15,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Vu-mètre audio en direct (affiche le volume réel capté par le micro)
              if (_state == VoiceState.listening)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _audioLevel > 0.04 ? Icons.graphic_eq_rounded : Icons.mic_none_rounded,
                            size: 16,
                            color: _audioLevel > 0.04 ? const Color(0xFF00E5FF) : Colors.white38,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _audioLevel > 0.04 ? 'Micro actif — Son capté' : 'En attente de votre voix...',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _audioLevel > 0.04 ? const Color(0xFF00E5FF) : Colors.white54,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (_audioLevel * 3.5).clamp(0.04, 1.0),
                          backgroundColor: Colors.white10,
                          valueColor: AlwaysStoppedAnimation(
                            _audioLevel > 0.04 ? const Color(0xFF00E5FF) : Colors.white24,
                          ),
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ),
                ),

              const Spacer(),

              // Champ de saisie / dictée immédiate
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _manualInputController,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: const InputDecoration(
                            hintText: 'Tapez votre commande ici (ex: Stock ciment, Ruptures)...',
                            hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                            border: InputBorder.none,
                          ),
                          onSubmitted: (val) {
                            if (val.trim().isNotEmpty) {
                              final text = val.trim();
                              _manualInputController.clear();
                              _handleFinalSpeech(text);
                            }
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send_rounded, color: Color(0xFF00E5FF), size: 20),
                        onPressed: () {
                          final val = _manualInputController.text.trim();
                          if (val.isNotEmpty) {
                            _manualInputController.clear();
                            _handleFinalSpeech(val);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Bouton principal
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                child: InkWell(
                  onTap: isProcessing ? null : _toggleListening,
                  borderRadius: BorderRadius.circular(40),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _state == VoiceState.listening
                            ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                            : [const Color(0xFF00E5FF), const Color(0xFF3B82F6)],
                      ),
                      borderRadius: BorderRadius.circular(40),
                      boxShadow: [
                        BoxShadow(
                          color: (_state == VoiceState.listening
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF00E5FF))
                              .withValues(alpha: 0.4),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _state == VoiceState.listening
                              ? Icons.stop_rounded
                              : Icons.mic_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _state == VoiceState.listening
                              ? "Arrêter & Valider"
                              : "Parler à Quantis",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getStatusText(VoiceState state) {
    switch (state) {
      case VoiceState.listening:
        return "🎙️ Quantis vous écoute...";
      case VoiceState.processing:
        return "🧠 Exécution en cours...";
      case VoiceState.speaking:
        return "🔊 Quantis vous répond...";
      case VoiceState.error:
        return "⚠️ Erreur. Cliquez pour réessayer.";
      case VoiceState.standby:
        return "💡 Prêt — Parlez ou cliquez le micro";
    }
  }

  Color _getStatusColor(VoiceState state) {
    switch (state) {
      case VoiceState.listening:
        return const Color(0xFF00E5FF);
      case VoiceState.processing:
        return const Color(0xFFA78BFA);
      case VoiceState.speaking:
        return const Color(0xFF34D399);
      case VoiceState.error:
        return const Color(0xFFF87171);
      case VoiceState.standby:
        return Colors.white70;
    }
  }
}
