import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/quantis_theme.dart';

/// Écran Dashboard — KPIs + graphique mensuel.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  static const _moisLabels = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de bord'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Bienvenue sur Quantis Stock',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: QuantisColors.royalBlue,
              ),
            ),
            const SizedBox(height: 4),
            const Text('Vue d\'ensemble de votre activité', style: TextStyle(color: QuantisColors.textMuted)),
            const SizedBox(height: 20),

            // KPI Grid
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _KpiCard(
                  title: 'Produits',
                  value: '—',
                  icon: Icons.inventory_2,
                  color: QuantisColors.royalBlue,
                  width: isWide ? 200 : null,
                ),
                _KpiCard(
                  title: 'Clients',
                  value: '—',
                  icon: Icons.people,
                  color: QuantisColors.info,
                  width: isWide ? 200 : null,
                ),
                _KpiCard(
                  title: 'Alertes stock',
                  value: '—',
                  icon: Icons.warning_amber,
                  color: QuantisColors.warning,
                  width: isWide ? 200 : null,
                ),
                _KpiCard(
                  title: 'Ruptures',
                  value: '—',
                  icon: Icons.error_outline,
                  color: QuantisColors.error,
                  width: isWide ? 200 : null,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // CA du mois
            Row(
              children: [
                Expanded(
                  child: _BigKpiCard(
                    title: 'CA du mois',
                    value: '— FCFA',
                    subtitle: 'Entrées de caisse',
                    icon: Icons.trending_up,
                    color: QuantisColors.success,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BigKpiCard(
                    title: 'Dépenses',
                    value: '— FCFA',
                    subtitle: 'Sorties de caisse',
                    icon: Icons.trending_down,
                    color: QuantisColors.error,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BigKpiCard(
                    title: 'Marge',
                    value: '— FCFA',
                    subtitle: 'CA − Dépenses',
                    icon: Icons.account_balance_wallet,
                    color: QuantisColors.luxuryGold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Graphique
            const Text('Évolution mensuelle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  height: 250,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            return BarTooltipItem(
                              '${_moisLabels[groupIndex]}\n${rod.toY.toStringAsFixed(0)} FCFA',
                              const TextStyle(color: Colors.white, fontSize: 12),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx >= 0 && idx < _moisLabels.length) {
                                return Text(_moisLabels[idx],
                                    style: const TextStyle(fontSize: 11, color: QuantisColors.textMuted));
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      gridData: const FlGridData(show: false),
                      barGroups: List.generate(12, (i) => BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: 0,
                            color: QuantisColors.royalBlue,
                            width: isWide ? 16 : 10,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ],
                      )),
                    ),
                    duration: const Duration(milliseconds: 300),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Info connexion
            Card(
              color: QuantisColors.info.withValues(alpha: 0.05),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: QuantisColors.info),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Connectez-vous au serveur pour afficher les données en temps réel.',
                        style: TextStyle(color: QuantisColors.info, fontSize: 13),
                      ),
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
  final double? width;

  const _KpiCard({required this.title, required this.value, required this.icon, required this.color, this.width});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisSize: width == null ? MainAxisSize.max : MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12, color: QuantisColors.textMuted)),
                  Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BigKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _BigKpiCard({
    required this.title, required this.value, required this.subtitle,
    required this.icon, required this.color,
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
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: QuantisColors.textMuted)),
          ],
        ),
      ),
    );
  }
}
