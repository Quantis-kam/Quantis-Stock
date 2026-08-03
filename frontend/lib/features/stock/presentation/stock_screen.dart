import 'package:flutter/material.dart';
import '../../../core/theme/quantis_theme.dart';

/// Écran mouvements de stock avec formulaire rapide.
class StockScreen extends StatelessWidget {
  const StockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mouvements de Stock'),
        actions: [
          IconButton(icon: const Icon(Icons.history), onPressed: () {}),
          IconButton(icon: const Icon(Icons.notifications_active), onPressed: () {}),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: const Text('Nouveau mouvement'),
        backgroundColor: QuantisColors.royalBlue,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swap_horiz, size: 64, color: QuantisColors.royalBlue.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('Gestion de Stock',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: QuantisColors.royalBlue)),
            const SizedBox(height: 8),
            const Text('Connectez-vous au serveur pour voir l\'état du stock',
                style: TextStyle(color: QuantisColors.textMuted)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.sync),
              label: const Text('Charger les données'),
            ),
          ],
        ),
      ),
    );
  }
}
