import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/quantis_theme.dart';
import 'quantis_ai_premium_view.dart';
import 'quantis_chat_view.dart';
import 'widgets/jarvis_voice_modal.dart';

/// Ouvre le panneau Quantis AI (ou l'offre Premium si l'abonnement IA n'est pas actif).
void showQuantisAiChat(BuildContext context) {
  final isWide = MediaQuery.of(context).size.width >= 800;

  Widget buildContent(BuildContext ctx) {
    if (!AppConstants.isQuantisAiPremiumEnabled) {
      return QuantisAiPremiumView(
        onClose: () => Navigator.of(ctx).pop(),
      );
    }
    return QuantisChatView(
      onClose: () => Navigator.of(ctx).pop(),
    );
  }

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
          child: buildContent(ctx),
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
          height: MediaQuery.of(context).size.height * 0.85,
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(
            color: QuantisColors.bgLight,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: buildContent(ctx),
        ),
      ),
    );
  }
}

/// Ouvre le mode vocal si l'offre Premium IA est active, sinon affiche la page Premium.
void showJarvisVoice(BuildContext context) {
  if (!AppConstants.isQuantisAiPremiumEnabled) {
    showQuantisAiChat(context);
    return;
  }
  JarvisVoiceModal.show(context);
}

/// Bouton flottant pour lancer Quantis AI depuis n'importe quel écran (sans écoute micro).
class QuantisAiFloatingButton extends StatelessWidget {
  const QuantisAiFloatingButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
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
                if (!AppConstants.isQuantisAiPremiumEnabled) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: QuantisColors.luxuryGold,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'PRO',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: QuantisColors.blueDark,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Écran complet pour Quantis AI (destiné au menu de navigation).
class QuantisAiScreen extends StatelessWidget {
  const QuantisAiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppConstants.isQuantisAiPremiumEnabled
          ? const QuantisChatView(isFullScreen: true)
          : const QuantisAiPremiumView(isFullScreen: true),
    );
  }
}
