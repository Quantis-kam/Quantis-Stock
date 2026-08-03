import 'package:flutter/material.dart';
import '../../../core/theme/quantis_theme.dart';

/// Écran comptabilité — tableau de bord financier simple.
class ComptabiliteScreen extends StatelessWidget {
  const ComptabiliteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comptabilité')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI Cards
            Row(
              children: [
                Expanded(child: _KpiCard(
                  title: 'Entrées',
                  value: '— FCFA',
                  icon: Icons.arrow_downward,
                  color: QuantisColors.success,
                )),
                const SizedBox(width: 12),
                Expanded(child: _KpiCard(
                  title: 'Sorties',
                  value: '— FCFA',
                  icon: Icons.arrow_upward,
                  color: QuantisColors.error,
                )),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _KpiCard(
                  title: 'Solde',
                  value: '— FCFA',
                  icon: Icons.account_balance_wallet,
                  color: QuantisColors.royalBlue,
                )),
                const SizedBox(width: 12),
                Expanded(child: _KpiCard(
                  title: 'TVA collectée',
                  value: '— FCFA',
                  icon: Icons.receipt_long,
                  color: QuantisColors.luxuryGold,
                )),
              ],
            ),
            const SizedBox(height: 24),

            // Journal de caisse
            const Text('Journal de caisse', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.account_balance, size: 48, color: QuantisColors.royalBlue.withValues(alpha: 0.3)),
                    const SizedBox(height: 12),
                    const Text(
                      'Connectez-vous au serveur pour voir les données',
                      style: TextStyle(color: QuantisColors.textMuted),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.sync),
                      label: const Text('Charger les données'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 12, color: QuantisColors.textMuted)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            )),
          ],
        ),
      ),
    );
  }
}
