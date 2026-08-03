import 'package:flutter/material.dart';
import '../../../core/theme/quantis_theme.dart';

/// Écran liste des produits avec recherche et filtrage.
class ProduitsScreen extends StatelessWidget {
  const ProduitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catalogue Produits'),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          IconButton(icon: const Icon(Icons.filter_list), onPressed: () {}),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: const Text('Nouveau produit'),
        backgroundColor: QuantisColors.royalBlue,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2, size: 64, color: QuantisColors.royalBlue.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('Catalogue Produits',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: QuantisColors.royalBlue)),
            const SizedBox(height: 8),
            const Text('Connectez-vous au serveur pour charger le catalogue',
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
