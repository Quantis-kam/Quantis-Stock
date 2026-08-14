import 'package:flutter/material.dart';
import '../../../core/theme/quantis_theme.dart';
import '../data/produit_service.dart';

/// Écran catalogue produits — liste avec recherche, prix, marge.
class ProduitsScreen extends StatefulWidget {
  const ProduitsScreen({super.key});

  @override
  State<ProduitsScreen> createState() => _ProduitsScreenState();
}

class _ProduitsScreenState extends State<ProduitsScreen> {
  final ProduitService _service = ProduitService();
  final TextEditingController _searchCtrl = TextEditingController();
  List<ProduitModel> _produits = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({String? search}) async {
    setState(() { _loading = true; _error = null; });
    try {
      _produits = await _service.getProduits(search: search);
      setState(() => _loading = false);
    } catch (e) {
      setState(() { _loading = false; _error = 'Erreur: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catalogue Produits'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => _load()),
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => _load(search: v),
              decoration: InputDecoration(
                hintText: 'Rechercher par nom ou référence...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () { _searchCtrl.clear(); _load(); },
                      )
                    : null,
              ),
            ),
          ),

          // Compteur
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: QuantisColors.royalBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_produits.length} produit${_produits.length > 1 ? 's' : ''}',
                    style: const TextStyle(fontSize: 12, color: QuantisColors.royalBlue, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Liste
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline, size: 48, color: QuantisColors.error),
                            const SizedBox(height: 8),
                            Text(_error!, style: TextStyle(color: QuantisColors.error)),
                            const SizedBox(height: 16),
                            ElevatedButton(onPressed: () => _load(), child: const Text('Réessayer')),
                          ],
                        ),
                      )
                    : _produits.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.inventory_2_outlined, size: 64, color: QuantisColors.textMuted),
                                SizedBox(height: 8),
                                Text('Aucun produit trouvé', style: TextStyle(color: QuantisColors.textMuted)),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () => _load(),
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _produits.length,
                              itemBuilder: (_, i) => _ProduitCard(produit: _produits[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _ProduitCard extends StatelessWidget {
  final ProduitModel produit;
  const _ProduitCard({required this.produit});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: QuantisColors.royalBlue.withValues(alpha: 0.1),
          child: Text(
            produit.nom.isNotEmpty ? produit.nom[0].toUpperCase() : '?',
            style: const TextStyle(fontWeight: FontWeight.w700, color: QuantisColors.royalBlue),
          ),
        ),
        title: Text(produit.nom, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (produit.reference != null)
              Text('Réf: ${produit.reference}', style: const TextStyle(fontSize: 12, color: QuantisColors.textMuted)),
            if (produit.categorieNom != null)
              Text(produit.categorieNom!, style: const TextStyle(fontSize: 12, color: QuantisColors.textSecondary)),
          ],
        ),
        isThreeLine: produit.reference != null || produit.categorieNom != null,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${produit.prixVente.toStringAsFixed(0)} FCFA',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            if (produit.marge > 0)
              Text('+${produit.margePercent.toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 11, color: QuantisColors.success, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
