import 'package:flutter/material.dart';
import '../../../../core/theme/quantis_theme.dart';

class QuantisTypingIndicator extends StatefulWidget {
  const QuantisTypingIndicator({super.key});

  @override
  State<QuantisTypingIndicator> createState() => _QuantisTypingIndicatorState();
}

class _QuantisTypingIndicatorState extends State<QuantisTypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 12.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [QuantisColors.royalBlue, QuantisColors.blueDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: QuantisColors.luxuryGold.withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
            child: const Center(
              child: Text(
                'Q',
                style: TextStyle(
                  color: QuantisColors.luxuryGold,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  fontFamily: 'SpaceGrotesk',
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: QuantisColors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(color: QuantisColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(0.2),
                const SizedBox(width: 4),
                _buildDot(0.4),
                const SizedBox(width: 8),
                const Text(
                  'Quantis réfléchit...',
                  style: TextStyle(
                    fontSize: 12,
                    color: QuantisColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(double delay) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = (_controller.value - delay) % 1.0;
        final bounce = progress < 0.5 ? progress * 2 : (1.0 - progress) * 2;

        return Transform.translate(
          offset: Offset(0, -bounce * 4),
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: Color.lerp(
                QuantisColors.royalBlue,
                QuantisColors.luxuryGold,
                bounce,
              ),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
