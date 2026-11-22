import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/quantis_theme.dart';
import '../../../core/utils/whatsapp_share_helper.dart';

/// Écran / panneau Premium présenté lorsque le module Quantis AI
/// n'est pas inclus dans l'abonnement actif de l'entreprise.
class QuantisAiPremiumView extends StatelessWidget {
  final VoidCallback? onClose;
  final bool isFullScreen;

  const QuantisAiPremiumView({
    super.key,
    this.onClose,
    this.isFullScreen = false,
  });

  Future<void> _requestUpgrade(BuildContext context) async {
    final entreprise = ApiClient.entrepriseNom;
    final email = ApiClient.userEmail ?? '';
    final message = StringBuffer()
      ..writeln('Bonjour l\'équipe Quantis,')
      ..writeln()
      ..writeln(
        'Je souhaite passer mon compte *$entreprise* à l\'abonnement *Premium (Quantis Pro IA)* afin d\'activer l\'assistant intelligent *Quantis AI*.',
      );
    if (email.isNotEmpty) {
      message.writeln('Compte : $email');
    }
    message.writeln();
    message.write('Merci de m\'indiquer la procédure d\'activation.');

    final opened = await WhatsappShareHelper.sendDirectMessage(
      phone: AppConstants.supportWhatsAppPhone,
      message: message.toString(),
    );

    if (!opened && context.mounted) {
      await Clipboard.setData(
        const ClipboardData(text: AppConstants.supportPhoneDisplay),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Numéro commercial copié (${AppConstants.supportPhoneDisplay}) — contactez-nous sur WhatsApp ou par appel.',
            ),
            backgroundColor: QuantisColors.royalBlue,
          ),
        );
      }
    }
  }

  Future<void> _copySupportPhone(BuildContext context) async {
    await Clipboard.setData(
      const ClipboardData(text: AppConstants.supportPhoneDisplay),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Contact Quantis copié : ${AppConstants.supportPhoneDisplay}',
          ),
          backgroundColor: QuantisColors.success,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final isCompact = MediaQuery.of(context).size.width < 600;

    return Container(
      decoration: BoxDecoration(
        color: QuantisColors.bgLight,
        borderRadius: isFullScreen
            ? BorderRadius.zero
            : const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          _buildHeader(context, showBack: isFullScreen && canPop),
          const Divider(height: 1, color: QuantisColors.border),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isCompact ? 16 : 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeroCard(isCompact),
                      const SizedBox(height: 18),
                      _buildCurrentPlanBanner(),
                      const SizedBox(height: 20),
                      const Text(
                        'Ce que débloque l\'abonnement Quantis Pro IA',
                        style: TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: QuantisColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildFeatureTile(
                        icon: Icons.inventory_2_rounded,
                        color: QuantisColors.royalBlue,
                        title: 'Analyse instantanée de votre stock',
                        subtitle:
                            'Repérez en un clic les ruptures imminentes, les produits dormants et vos meilleures ventes.',
                      ),
                      const SizedBox(height: 10),
                      _buildFeatureTile(
                        icon: Icons.insights_rounded,
                        color: const Color(0xFF0D9488),
                        title: 'Pilotage des ventes & bénéfices',
                        subtitle:
                            'Posez vos questions en français sur votre chiffre d\'affaires, vos marges et vos créances clients.',
                      ),
                      const SizedBox(height: 10),
                      _buildFeatureTile(
                        icon: Icons.auto_graph_rounded,
                        color: QuantisColors.goldDark,
                        title: 'Prévisions de réapprovisionnement',
                        subtitle:
                            'Anticipez vos commandes fournisseurs avant les ruptures grâce au suivi intelligent des rotations.',
                      ),
                      const SizedBox(height: 10),
                      _buildFeatureTile(
                        icon: Icons.workspace_premium_rounded,
                        color: const Color(0xFF7C3AED),
                        title: 'Accompagnement & nouveautés IA prioritaires',
                        subtitle:
                            'Accès prioritaire aux futures automatisations Quantis et support dédié pour votre équipe.',
                      ),
                      const SizedBox(height: 22),
                      _buildUpgradeCta(context),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, {required bool showBack}) {
    return Container(
      padding: EdgeInsets.only(
        top: isFullScreen ? MediaQuery.of(context).padding.top + 10 : 12,
        bottom: 12,
        left: 14,
        right: 14,
      ),
      decoration: BoxDecoration(
        color: QuantisColors.white,
        borderRadius: isFullScreen
            ? BorderRadius.zero
            : const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          if (showBack) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded,
                  color: QuantisColors.royalBlue),
              tooltip: 'Retour',
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 4),
          ],
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [QuantisColors.royalBlue, QuantisColors.blueDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: QuantisColors.luxuryGold, width: 1.5),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: QuantisColors.luxuryGold,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Quantis AI',
                  style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: QuantisColors.royalBlue,
                  ),
                ),
                Text(
                  'Module réservé au forfait Premium',
                  style: TextStyle(
                    fontSize: 11,
                    color: QuantisColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [QuantisColors.goldDark, QuantisColors.luxuryGold],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.workspace_premium_rounded,
                    size: 13, color: QuantisColors.blueDark),
                SizedBox(width: 4),
                Text(
                  'PREMIUM',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: QuantisColors.blueDark,
                  ),
                ),
              ],
            ),
          ),
          if (onClose != null) ...[
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.close_rounded,
                  color: QuantisColors.textSecondary),
              tooltip: 'Fermer',
              onPressed: onClose,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeroCard(bool isCompact) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 20 : 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [QuantisColors.blueDark, QuantisColors.royalBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: QuantisColors.luxuryGold.withValues(alpha: 0.75),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: QuantisColors.royalBlue.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: QuantisColors.luxuryGold,
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: QuantisColors.luxuryGold,
                  size: 32,
                ),
              ),
              Positioned(
                right: -4,
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    color: QuantisColors.luxuryGold,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    size: 14,
                    color: QuantisColors.blueDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: QuantisColors.luxuryGold.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: QuantisColors.luxuryGold.withValues(alpha: 0.5),
              ),
            ),
            child: const Text(
              'OFFRE QUANTIS PRO IA',
              style: TextStyle(
                color: QuantisColors.goldLight,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Passez à un abonnement supérieur',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontSize: isCompact ? 20 : 23,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'L\'assistant intelligent Quantis AI est réservé aux formules Premium. '
            'Changez de forfait pour débloquer l\'intelligence artificielle dédiée à votre stock et vos ventes.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: Colors.white70,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentPlanBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: QuantisColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: QuantisColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: QuantisColors.royalBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.verified_user_outlined,
              size: 18,
              color: QuantisColors.royalBlue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Forfait actuel : Quantis Standard (${ApiClient.entrepriseNom})',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: QuantisColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Gestion complète Stock, Caisse POS, Factures, Clients & Comptabilité active.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: QuantisColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: QuantisColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: QuantisColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: QuantisColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: QuantisColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeCta(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: QuantisColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: QuantisColors.luxuryGold.withValues(alpha: 0.6),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            onPressed: () => _requestUpgrade(context),
            icon: const Icon(Icons.workspace_premium_rounded, size: 20),
            label: const Text('Passer à l\'abonnement Premium'),
            style: ElevatedButton.styleFrom(
              backgroundColor: QuantisColors.royalBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _copySupportPhone(context),
            icon: const Icon(Icons.phone_outlined, size: 17),
            label: const Text(
              'Service commercial : ${AppConstants.supportPhoneDisplay}',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: QuantisColors.royalBlue,
              side: BorderSide(
                color: QuantisColors.royalBlue.withValues(alpha: 0.35),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          if (onClose != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onClose,
              child: const Text(
                'Plus tard',
                style: TextStyle(color: QuantisColors.textSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

