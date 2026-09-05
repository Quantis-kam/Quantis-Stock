import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/quantis_ai_controller.dart';
import '../quantis_ai_launcher.dart';
import '../../services/quantis_voice_service.dart';
import 'jarvis_voice_modal.dart';

/// HUD Overlay Jarvis — superposé à l'app, transparent, toujours prêt
class QuantisHudOverlay extends ConsumerStatefulWidget {
  const QuantisHudOverlay({super.key});

  @override
  ConsumerState<QuantisHudOverlay> createState() => _QuantisHudOverlayState();
}

class _QuantisHudOverlayState extends ConsumerState<QuantisHudOverlay>
    with TickerProviderStateMixin {
  final _voiceService = QuantisVoiceService();

  VoiceState _state = VoiceState.standby;
  double _audioLevel = 0.0;
  String _partialTranscript = '';
  String _lastTranscript = '';
  String _assistantResponse = '';
  String _spokenWordsSoFar = '';
  List<ActionStep> _actions = [];

  bool _hudVisible = false;
  Timer? _hideTimer;

  late final AnimationController _fadeController;
  late final AnimationController _pulseController;

  StreamSubscription? _stateSub;
  StreamSubscription? _audioSub;
  StreamSubscription? _partialSub;
  StreamSubscription? _finalSub;
  StreamSubscription? _wakeUpSub;
  StreamSubscription? _speakWordSub;
  StreamSubscription? _actionSub;
  StreamSubscription? _silenceSub;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Initialiser Jarvis et démarrer la surveillance
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _voiceService.initJarvisMode();
      _subscribeStreams();
    });
  }

  void _subscribeStreams() {
    _stateSub = _voiceService.stateStream.listen((state) {
      if (!mounted) return;
      setState(() => _state = state);
      if (state != VoiceState.standby) {
        _showHud();
      }
    });

    _audioSub = _voiceService.audioLevelStream.listen((level) {
      if (mounted) setState(() => _audioLevel = level);
    });

    _partialSub = _voiceService.partialTranscriptStream.listen((text) {
      if (!mounted) return;
      setState(() => _partialTranscript = text);
      _showHud();
    });

    _finalSub = _voiceService.finalTranscriptStream.listen((text) {
      if (!mounted) return;
      setState(() {
        _partialTranscript = '';
        _lastTranscript = text;
      });
      _handleFinalSpeech(text);
    });

    _wakeUpSub = _voiceService.wakeUpStream.listen((_) {
      if (!mounted) return;
      _voiceService.startListening();
      _showHud();
    });

    _speakWordSub = _voiceService.speakWordStream.listen((word) {
      if (!mounted) return;
      setState(() => _spokenWordsSoFar += ' $word');
    });

    _actionSub = _voiceService.actionStepStream.listen((actions) {
      if (mounted) setState(() => _actions = actions);
    });

    _silenceSub = _voiceService.silenceStream.listen((_) {
      if (!mounted) return;
      if (_partialTranscript.trim().isNotEmpty && _state == VoiceState.listening) {
        final text = _partialTranscript.trim();
        _partialTranscript = '';
        _lastTranscript = text;
        _handleFinalSpeech(text);
      } else {
        _scheduleHide();
      }
    });
  }

  void _showHud() {
    if (!_hudVisible) {
      setState(() {
        _hudVisible = true;
      });
      _fadeController.forward();
    }
    _cancelHideTimer();
  }

  void _scheduleHide({Duration delay = const Duration(seconds: 4)}) {
    _cancelHideTimer();
    _hideTimer = Timer(delay, () {
      if (mounted && _state == VoiceState.standby) {
        _fadeController.reverse().then((_) {
          if (mounted) {
            setState(() {
              _hudVisible = false;
              _partialTranscript = '';
              _lastTranscript = '';
              _assistantResponse = '';
              _spokenWordsSoFar = '';
              _actions = [];
              _voiceService.clearActions();
            });
          }
        });
      }
    });
  }

  void _cancelHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = null;
  }

  Future<void> _handleFinalSpeech(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _state == VoiceState.processing) return;

    _voiceService.stopListening();
    _voiceService.setProcessing();

    // Ajouter les étapes d'action visibles
    _voiceService.clearActions();
    _voiceService.addAction('analyze', 'Analyse de votre demande...', icon: '🧠');

    final response = await ref.read(quantisAiProvider.notifier).sendMessage(trimmed);

    _voiceService.updateAction('analyze', ActionStatus.success, result: 'Compris');

    if (response != null && mounted) {
      setState(() {
        _assistantResponse = response.text;
        _spokenWordsSoFar = '';
      });

      // Ajouter l'étape de réponse
      _voiceService.addAction('respond', 'Réponse vocale...', icon: '🔊');
      _voiceService.speak(response.text);

      // Marquer comme terminé quand la voix finit
      Future.delayed(const Duration(seconds: 1), () {
        _voiceService.updateAction('respond', ActionStatus.success);
        // Auto-hide après la réponse
        _scheduleHide(delay: const Duration(seconds: 6));
      });
    } else {
      _scheduleHide();
    }
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _audioSub?.cancel();
    _partialSub?.cancel();
    _finalSub?.cancel();
    _wakeUpSub?.cancel();
    _speakWordSub?.cancel();
    _actionSub?.cancel();
    _silenceSub?.cancel();
    _hideTimer?.cancel();
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Indicateur de veille permanent (petit orbe en bas à droite)
        if (!_hudVisible)
          Positioned(
            bottom: 24,
            right: 24,
            child: _buildStandbyIndicator(),
          ),

        // HUD principal (overlay transparent ancré en bas de l'écran)
        if (_hudVisible)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: FadeTransition(
              opacity: _fadeController,
              child: _buildHud(),
            ),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  // Indicateur de veille — petit orbe pulsant
  // ═══════════════════════════════════════════
  Widget _buildStandbyIndicator() {
    return GestureDetector(
      onTap: () {
        // Tap → activer manuellement
        _voiceService.startListening();
        _showHud();
      },
      onDoubleTap: () {
        // Double tap → ouvrir le chat
        showQuantisAiChat(context);
      },
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, _) {
          final pulse = 0.6 + (_pulseController.value * 0.4);
          return Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF00E5FF).withValues(alpha: 0.8 * pulse),
                  const Color(0xFF3B82F6).withValues(alpha: 0.4 * pulse),
                  Colors.transparent,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.3 * pulse),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF00E5FF),
                ),
                child: const Icon(
                  Icons.mic_none_rounded,
                  color: Colors.white,
                  size: 12,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════
  // HUD principal — overlay transparent
  // ═══════════════════════════════════════════
  Widget _buildHud() {
    return GestureDetector(
      onTap: () {
        // Tap sur le HUD quand Quantis est idle → fermer
        if (_state == VoiceState.standby) {
          _scheduleHide(delay: Duration.zero);
        }
      },
      behavior: HitTestBehavior.translucent,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Container principal glassmorphism
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _getStateColor().withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _getStateColor().withValues(alpha: 0.2),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Barre d'état
                      _buildStatusBar(),
                      // Visualiseur d'ondes
                      if (_state == VoiceState.listening)
                        _buildWaveVisualizer(),
                      // Transcription live
                      if (_partialTranscript.isNotEmpty || _lastTranscript.isNotEmpty)
                        _buildTranscript(),
                      // Timeline d'actions
                      if (_actions.isNotEmpty)
                        _buildActionTimeline(),
                      // Réponse de Quantis
                      if (_assistantResponse.isNotEmpty && _state != VoiceState.listening)
                        _buildResponse(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // Composants du HUD
  // ═══════════════════════════════════════════

  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Indicateur d'état animé
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getStateColor(),
              boxShadow: [
                BoxShadow(
                  color: _getStateColor().withValues(alpha: 0.6),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _getStatusLabel(),
            style: TextStyle(
              color: _getStateColor(),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const Spacer(),
          // Bouton micro / stop
          GestureDetector(
            onTap: () {
              if (_state == VoiceState.listening) {
                final pending = _partialTranscript.trim();
                _voiceService.stopListening();
                if (pending.isNotEmpty) {
                  _partialTranscript = '';
                  _lastTranscript = pending;
                  _handleFinalSpeech(pending);
                }
              } else if (_state == VoiceState.speaking) {
                _voiceService.stopSpeaking();
              } else {
                _voiceService.startListening();
              }
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getStateColor().withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _state == VoiceState.listening
                    ? Icons.stop_rounded
                    : _state == VoiceState.speaking
                        ? Icons.volume_off_rounded
                        : Icons.mic_rounded,
                color: _getStateColor(),
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Bouton plein écran (Jarvis modal 3D)
          GestureDetector(
            onTap: () {
              JarvisVoiceModal.show(context);
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.fullscreen_rounded,
                color: Colors.white70,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Bouton fermer
          GestureDetector(
            onTap: () {
              _voiceService.stopListening();
              _voiceService.stopSpeaking();
              _scheduleHide(delay: Duration.zero);
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.white54,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaveVisualizer() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        return Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: CustomPaint(
            painter: _WavePainter(
              audioLevel: _audioLevel,
              progress: _pulseController.value,
              color: _getStateColor(),
            ),
            size: Size.infinite,
          ),
        );
      },
    );
  }

  Widget _buildTranscript() {
    final text = _partialTranscript.isNotEmpty ? _partialTranscript : _lastTranscript;
    final isPartial = _partialTranscript.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🗣️ ', style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.7))),
          Expanded(
            child: Text(
              '« $text »',
              style: TextStyle(
                color: isPartial ? Colors.white60 : Colors.white,
                fontSize: 14,
                fontStyle: isPartial ? FontStyle.italic : FontStyle.normal,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTimeline() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _actions.map((action) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                // Icône d'état
                SizedBox(
                  width: 20,
                  height: 20,
                  child: action.status == ActionStatus.running
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(_getStateColor()),
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
                const SizedBox(width: 10),
                Text(action.icon, style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    action.label,
                    style: TextStyle(
                      color: action.status == ActionStatus.running
                          ? Colors.white
                          : Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (action.result != null)
                  Text(
                    action.result!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildResponse() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('Q', style: TextStyle(
              color: Color(0xFF60A5FA),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            )),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _assistantResponse
                  .replaceAll(RegExp(r'[*#_`~>|]'), '')
                  .replaceAll(RegExp(r'\n+'), ' ')
                  .trim(),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════

  Color _getStateColor() {
    switch (_state) {
      case VoiceState.listening:
        return const Color(0xFF00E5FF);
      case VoiceState.processing:
        return const Color(0xFF8B5CF6);
      case VoiceState.speaking:
        return const Color(0xFF10B981);
      case VoiceState.error:
        return const Color(0xFFEF4444);
      case VoiceState.standby:
        return const Color(0xFF3B82F6);
    }
  }

  String _getStatusLabel() {
    switch (_state) {
      case VoiceState.listening:
        return 'ÉCOUTE ACTIVE';
      case VoiceState.processing:
        return 'TRAITEMENT...';
      case VoiceState.speaking:
        return 'QUANTIS PARLE';
      case VoiceState.error:
        return 'ERREUR';
      case VoiceState.standby:
        return 'QUANTIS';
    }
  }
}

/// Peintre de formes d'onde pour le visualiseur
class _WavePainter extends CustomPainter {
  final double audioLevel;
  final double progress;
  final Color color;

  _WavePainter({
    required this.audioLevel,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final barCount = 40;
    final barWidth = size.width / barCount;
    final maxAmplitude = size.height * 0.4;

    for (int i = 0; i < barCount; i++) {
      final x = i * barWidth + barWidth / 2;
      final normalizedPosition = i / barCount;

      // Forme d'onde avec bruit pseudo-aléatoire synchronisé au niveau audio
      final wave = math.sin(normalizedPosition * math.pi * 4 + progress * math.pi * 2);
      final noise = math.sin(i * 1.7 + progress * 5) * 0.3;
      final amplitude = (audioLevel * 0.7 + 0.3) * maxAmplitude * (wave.abs() + noise.abs()).clamp(0.05, 1.0);

      final barPaint = Paint()
        ..color = color.withValues(alpha: 0.3 + audioLevel * 0.6)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(x, centerY - amplitude),
        Offset(x, centerY + amplitude),
        barPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return audioLevel != oldDelegate.audioLevel || progress != oldDelegate.progress;
  }
}
