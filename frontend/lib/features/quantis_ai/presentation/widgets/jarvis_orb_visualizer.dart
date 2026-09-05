import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/quantis_voice_service.dart';

/// Visualiseur holographique inspiré de Jarvis
/// Réagit en temps réel à l'état de la voix et à l'amplitude du microphone.
class JarvisOrbVisualizer extends StatefulWidget {
  final VoiceState state;
  final double audioLevel;
  final double size;
  final VoidCallback? onTap;

  const JarvisOrbVisualizer({
    super.key,
    required this.state,
    this.audioLevel = 0.0,
    this.size = 200,
    this.onTap,
  });

  @override
  State<JarvisOrbVisualizer> createState() => _JarvisOrbVisualizerState();
}

class _JarvisOrbVisualizerState extends State<JarvisOrbVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  Color _getPrimaryColor() {
    switch (widget.state) {
      case VoiceState.listening:
        return const Color(0xFF00E5FF); // Cyan électrique
      case VoiceState.processing:
        return const Color(0xFF8B5CF6); // Violet néon
      case VoiceState.speaking:
        return const Color(0xFF10B981); // Émeraude / Teal
      case VoiceState.error:
        return const Color(0xFFEF4444); // Rouge alerte
      case VoiceState.standby:
        return const Color(0xFF3B82F6); // Bleu Quantis
    }
  }

  Color _getSecondaryColor() {
    switch (widget.state) {
      case VoiceState.listening:
        return const Color(0xFF06B6D4);
      case VoiceState.processing:
        return const Color(0xFFEC4899);
      case VoiceState.speaking:
        return const Color(0xFF34D399);
      case VoiceState.error:
        return const Color(0xFFF87171);
      case VoiceState.standby:
        return const Color(0xFF6366F1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = _getPrimaryColor();
    final secondary = _getSecondaryColor();

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _rotationController,
        builder: (context, child) {
          return SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: _JarvisOrbPainter(
                progress: _rotationController.value,
                audioLevel: widget.audioLevel,
                state: widget.state,
                primaryColor: primary,
                secondaryColor: secondary,
              ),
              child: Center(
                child: Container(
                  width: widget.size * 0.4,
                  height: widget.size * 0.4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.9),
                        primary.withValues(alpha: 0.8),
                        secondary.withValues(alpha: 0.4),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.4, 0.8, 1.0],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primary.withValues(alpha: 0.6),
                        blurRadius: 20 + widget.audioLevel * 30,
                        spreadRadius: 5 + widget.audioLevel * 15,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      _getCenterIcon(),
                      color: Colors.white,
                      size: widget.size * 0.18,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _getCenterIcon() {
    switch (widget.state) {
      case VoiceState.listening:
        return Icons.mic_rounded;
      case VoiceState.processing:
        return Icons.auto_awesome_rounded;
      case VoiceState.speaking:
        return Icons.volume_up_rounded;
      case VoiceState.error:
        return Icons.error_outline_rounded;
      case VoiceState.standby:
        return Icons.graphic_eq_rounded;
    }
  }
}

class _JarvisOrbPainter extends CustomPainter {
  final double progress;
  final double audioLevel;
  final VoiceState state;
  final Color primaryColor;
  final Color secondaryColor;

  _JarvisOrbPainter({
    required this.progress,
    required this.audioLevel,
    required this.state,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // 1. Anneaux extérieurs holographiques (Orb rings)
    final ringCount = 3;
    for (int i = 0; i < ringCount; i++) {
      final ringProgress = (progress + (i * 0.33)) % 1.0;
      final pulseRadius = maxRadius * (0.6 + 0.35 * math.sin(ringProgress * math.pi * 2));
      final dynamicRadius = pulseRadius + (audioLevel * 25 * (i + 1));

      paint
        ..color = (i % 2 == 0 ? primaryColor : secondaryColor).withValues(alpha: (0.25 - i * 0.05).clamp(0.05, 0.4))
        ..strokeWidth = 1.5 + audioLevel * 2.0;

      canvas.drawCircle(center, dynamicRadius.clamp(10.0, maxRadius), paint);
    }

    // 2. Ondes de particules & arcs rotatifs
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..shader = SweepGradient(
        colors: [
          primaryColor.withValues(alpha: 0.1),
          primaryColor,
          secondaryColor,
          secondaryColor.withValues(alpha: 0.1),
        ],
        stops: const [0.0, 0.4, 0.7, 1.0],
        transform: GradientRotation(progress * math.pi * 2),
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius * 0.75));

    final arcRadius = maxRadius * 0.7 + (audioLevel * 15);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: arcRadius),
      progress * math.pi * 2,
      math.pi * 1.4,
      false,
      arcPaint,
    );

    // Arc inversé
    final arcPaint2 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = secondaryColor.withValues(alpha: 0.6);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: maxRadius * 0.85),
      -progress * math.pi * 2,
      math.pi * 0.8,
      false,
      arcPaint2,
    );
  }

  @override
  bool shouldRepaint(covariant _JarvisOrbPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.audioLevel != audioLevel ||
        oldDelegate.state != state ||
        oldDelegate.primaryColor != primaryColor;
  }
}
