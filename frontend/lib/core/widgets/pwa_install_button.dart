import 'package:flutter/material.dart';
import '../theme/quantis_theme.dart';
import '../utils/pwa_install_helper.dart';

/// Lance l'installation en 1 clic si supportée par le navigateur, sinon affiche le guide 2 étapes.
Future<void> handlePwaInstallTap(BuildContext context) async {
  final outcome = await PwaInstallHelper.triggerInstall();
  if (!context.mounted) return;

  if (outcome == PwaInstallOutcome.accepted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Quantis Stock est en cours d\'installation sur votre appareil !'),
        backgroundColor: QuantisColors.success,
        duration: Duration(seconds: 4),
      ),
    );
    return;
  }

  if (outcome == PwaInstallOutcome.dismissed) {
    return;
  }

  // Guide clair pour iOS Safari, Firefox ou navigateur n'exposant pas la boîte auto
  final isIos = PwaInstallHelper.isIos;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: QuantisColors.royalBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.install_mobile_rounded, color: QuantisColors.royalBlue, size: 22),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Installer Quantis Stock',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isIos
                ? 'Sur iPhone / iPad (Safari), suivez ces 3 gestes rapides :'
                : 'Pour ajouter Quantis Stock comme une vraie application sur votre écran d\'accueil :',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
          ),
          const SizedBox(height: 14),
          if (isIos) ...[
            _stepRow('1', 'Appuyez sur le bouton Partager (icône carré avec flèche vers le haut) en bas de Safari.'),
            const SizedBox(height: 8),
            _stepRow('2', 'Faites défiler et appuyez sur « Sur l\'écran d\'accueil ».'),
            const SizedBox(height: 8),
            _stepRow('3', 'Appuyez sur « Ajouter » en haut à droite.'),
          ] else ...[
            _stepRow('1', 'Appuyez sur le menu du navigateur (⋮ en haut à droite de Chrome / Edge / Brave).'),
            const SizedBox(height: 8),
            _stepRow('2', 'Appuyez sur « Installer l\'application » ou « Ajouter à l\'écran d\'accueil ».'),
            const SizedBox(height: 8),
            _stepRow('3', 'Confirmez « Installer » : l\'icône Quantis Stock apparaît sur votre téléphone et se met à jour automatiquement !'),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: QuantisColors.royalBlue.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: QuantisColors.royalBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Astuce : si l\'application est déjà installée sur votre téléphone, ouvrez directement son icône sur l\'écran d\'accueil.',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx),
          style: ElevatedButton.styleFrom(
            backgroundColor: QuantisColors.royalBlue,
            foregroundColor: Colors.white,
          ),
          child: const Text('Compris'),
        ),
      ],
    ),
  );
}

Widget _stepRow(String num, String text) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
          color: QuantisColors.royalBlue,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            num,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(text, style: const TextStyle(fontSize: 12.5, height: 1.35)),
      ),
    ],
  );
}

/// Carte/bouton d'installation affiché sur l'écran de connexion Web (masqué dans l'APK et en PWA installée).
class PwaInstallCard extends StatefulWidget {
  const PwaInstallCard({super.key});

  @override
  State<PwaInstallCard> createState() => _PwaInstallCardState();
}

class _PwaInstallCardState extends State<PwaInstallCard> {
  @override
  void initState() {
    super.initState();
    PwaInstallHelper.init();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: PwaInstallHelper.stateVersion,
      builder: (context, _, __) {
        if (!PwaInstallHelper.shouldShowButton) {
          return const SizedBox.shrink();
        }
        final isReady = PwaInstallHelper.canPromptNatively;
        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => handlePwaInstallTap(context),
              icon: const Icon(Icons.install_mobile_rounded, size: 20, color: QuantisColors.royalBlue),
              label: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isReady
                        ? 'Installer l\'application sur le téléphone'
                        : 'Installer sur l\'écran d\'accueil',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: QuantisColors.royalBlue,
                    ),
                  ),
                  Text(
                    'Accès rapide 1 clic • Mises à jour automatiques',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                side: BorderSide(color: QuantisColors.royalBlue.withValues(alpha: 0.35)),
                backgroundColor: QuantisColors.royalBlue.withValues(alpha: 0.04),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Entrée de menu (Drawer mobile) pour installer l'application sur le téléphone.
class PwaInstallDrawerTile extends StatefulWidget {
  final VoidCallback? onBeforeTap;
  const PwaInstallDrawerTile({super.key, this.onBeforeTap});

  @override
  State<PwaInstallDrawerTile> createState() => _PwaInstallDrawerTileState();
}

class _PwaInstallDrawerTileState extends State<PwaInstallDrawerTile> {
  @override
  void initState() {
    super.initState();
    PwaInstallHelper.init();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: PwaInstallHelper.stateVersion,
      builder: (context, _, __) {
        if (!PwaInstallHelper.shouldShowButton) {
          return const SizedBox.shrink();
        }
        return ListTile(
          leading: const Icon(Icons.install_mobile_rounded, color: QuantisColors.success),
          title: const Text(
            'Installer sur le téléphone',
            style: TextStyle(fontWeight: FontWeight.w700, color: QuantisColors.royalBlue),
          ),
          subtitle: const Text('Accès rapide depuis l\'écran d\'accueil', style: TextStyle(fontSize: 11)),
          onTap: () {
            widget.onBeforeTap?.call();
            handlePwaInstallTap(context);
          },
        );
      },
    );
  }
}

/// Bouton icône compact pour la barre latérale desktop Web.
class PwaInstallRailButton extends StatefulWidget {
  const PwaInstallRailButton({super.key});

  @override
  State<PwaInstallRailButton> createState() => _PwaInstallRailButtonState();
}

class _PwaInstallRailButtonState extends State<PwaInstallRailButton> {
  @override
  void initState() {
    super.initState();
    PwaInstallHelper.init();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: PwaInstallHelper.stateVersion,
      builder: (context, _, __) {
        if (!PwaInstallHelper.shouldShowButton) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Tooltip(
            message: 'Installer l\'application',
            child: IconButton(
              icon: const Icon(Icons.install_mobile_rounded, color: QuantisColors.luxuryGold, size: 22),
              onPressed: () => handlePwaInstallTap(context),
            ),
          ),
        );
      },
    );
  }
}

