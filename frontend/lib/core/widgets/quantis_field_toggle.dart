import 'package:flutter/material.dart';
import '../theme/quantis_theme.dart';

/// Bouton interrupteur compact façon Cloudflare (pilule animée + icône + statut)
/// à placer directement sur les champs optionnels des formulaires.
class QuantisFieldToggle extends StatelessWidget {
  final String? title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String activeLabel;
  final String inactiveLabel;
  final IconData activeIcon;
  final IconData? inactiveIcon;
  final Color activeColor;
  final Color activeIconColor;
  final bool compact;

  const QuantisFieldToggle({
    super.key,
    this.title,
    required this.value,
    required this.onChanged,
    required this.activeLabel,
    required this.inactiveLabel,
    required this.activeIcon,
    this.inactiveIcon,
    this.activeColor = const Color(0xFF1D63ED),
    this.activeIconColor = QuantisColors.luxuryGold,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final double trackWidth = compact ? 38 : 44;
    final double trackHeight = compact ? 22 : 25;
    final double thumbSize = compact ? 16 : 19;

    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 2 : 4, horizontal: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null && title!.isNotEmpty) ...[
              Text(
                title!,
                style: TextStyle(
                  fontSize: compact ? 11.5 : 12.5,
                  fontWeight: FontWeight.w600,
                  color: QuantisColors.textPrimary,
                ),
              ),
              SizedBox(height: compact ? 4 : 6),
            ],
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pilule animée (style Cloudflare)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  width: trackWidth,
                  height: trackHeight,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: value ? activeColor : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(trackHeight / 2),
                    border: Border.all(
                      color: value
                          ? activeColor
                          : Colors.grey.shade400.withValues(alpha: 0.7),
                      width: 1,
                    ),
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      width: thumbSize,
                      height: thumbSize,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.16),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  value ? activeIcon : (inactiveIcon ?? activeIcon),
                  size: compact ? 16 : 18,
                  color: value ? activeIconColor : Colors.grey.shade500,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    value ? activeLabel : inactiveLabel,
                    style: TextStyle(
                      fontSize: compact ? 12 : 13,
                      fontWeight: value ? FontWeight.w600 : FontWeight.w500,
                      color: value ? QuantisColors.textPrimary : Colors.grey.shade600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

