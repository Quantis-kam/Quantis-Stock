import 'package:flutter/material.dart';
import '../../../core/theme/quantis_theme.dart';
import 'quantis_chat_view.dart';
import 'widgets/jarvis_voice_modal.dart';

/// Ouvre le panneau de chat Quantis AI (adaptatif mobile / desktop)
void showQuantisAiChat(BuildContext context) {
  final isWide = MediaQuery.of(context).size.width >= 800;

  if (isWide) {
    showDialog(
      context: context,
      barrierColor: Colors.black45,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        alignment: Alignment.centerRight,
        insetPadding: const EdgeInsets.only(right: 24, top: 24, bottom: 24),
        child: Container(
          width: 480,
          height: MediaQuery.of(context).size.height * 0.85,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: QuantisColors.bgLight,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: QuantisColors.luxuryGold.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: QuantisColors.royalBlue.withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(-4, 4),
              ),
            ],
          ),
          child: QuantisChatView(
            onClose: () => Navigator.of(ctx).pop(),
          ),
        ),
      ),
    );
  } else {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.82,
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(
            color: QuantisColors.bgLight,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: QuantisChatView(
            onClose: () => Navigator.of(ctx).pop(),
          ),
        ),
      ),
    );
  }
}

/// Ouvre directement le Mode Vocal Jarvis plein écran
void showJarvisVoice(BuildContext context) {
  JarvisVoiceModal.show(context);
}

/// Bouton flottant premium pour lancer l'assistant Quantis depuis n'importe quel écran
class QuantisAiFloatingButton extends StatelessWidget {
  const QuantisAiFloatingButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Bouton Vocal Jarvis rapide
        Tooltip(
          message: 'Parler à Jarvis 🎙️',
          child: Container(
            decoration: BoxDecoration(
              gradient: const RadialGradient(
                colors: [Color(0xFF00E5FF), Color(0xFF0284C7)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.45),
                  blurRadius: 14,
                  spreadRadius: 2,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => showJarvisVoice(context),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(
                    Icons.mic_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Bouton Chat Quantis
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [QuantisColors.royalBlue, QuantisColors.blueLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: QuantisColors.luxuryGold,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: QuantisColors.royalBlue.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: () => showQuantisAiChat(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: QuantisColors.luxuryGold,
                        shape: BoxShape.circle,
                      ),
                      child: const Text(
                        'Q',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: QuantisColors.blueDark,
                          fontFamily: 'SpaceGrotesk',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Quantis AI',
                      style: TextStyle(
                        color: QuantisColors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Écran complet pour Quantis AI (destiné au menu de navigation)
class QuantisAiScreen extends StatelessWidget {
  const QuantisAiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: QuantisChatView(isFullScreen: true),
    );
  }
}
