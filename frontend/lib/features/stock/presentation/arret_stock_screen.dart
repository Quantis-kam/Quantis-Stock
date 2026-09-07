import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/quantis_theme.dart';

/// Écran de gestion et consultation des Arrêts de Stock (Snapshots).
class ArretStockScreen extends StatefulWidget {
  const ArretStockScreen({super.key});

  @override
  State<ArretStockScreen> createState() => _ArretStockScreenState();
}

class _ArretStockScreenState extends State<ArretStockScreen> {
  List<dynamic> _arrets = [];
  bool _loading = true;
  bool _creating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadArrets();
  }

  Future<void> _loadArrets() async {
    setState(() { _loading = true; _error = null; });
    try {
      final dio = ApiClient.instance;
      final response = await dio.get('/stock/arrets');
      if (mounted) {
        setState(() {
          _arrets = response.data['data']['content'] as List;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erreur de chargement : $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _creerArretStock() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Générer un Arrêt de Stock'),
        content: const Text(
          'Voulez-vous figer l\'état actuel du stock (snapshot instantané) ?\n'
          'Cette action enregistrera la quantité et la valorisation exacte de chaque produit.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: QuantisColors.royalBlue, foregroundColor: Colors.white),
            child: const Text('Confirmer l\'Arrêt'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() { _creating = true; });

    try {
      final dio = ApiClient.instance;
      await dio.post('/stock/arrets', data: {
        'notes': 'Arrêt de stock généré depuis l\'interface web',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Arrêt de stock créé avec succès !'),
            backgroundColor: QuantisColors.success,
          ),
        );
        _loadArrets();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: QuantisColors.error),
        );
      }
    } finally {
      if (mounted) setState(() { _creating = false; });
    }
  }

  void _afficherDetail(Map<String, dynamic> arret) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final lignes = (arret['lignes'] as List?) ?? [];
        final totalAchat = (arret['valeurTotaleAchat'] as num? ?? 0).toDouble();
        final totalVente = (arret['valeurTotaleVente'] as num? ?? 0).toDouble();

        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, controller) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Détail — ${arret['reference']}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Date: ${arret['dateArret'] != null ? arret['dateArret'].toString().substring(0, 16).replaceAll('T', ' ') : "-"} | Dépôt: ${arret['depot']?['nom'] ?? "Tous les dépôts"}',
                    style: const TextStyle(fontSize: 12, color: QuantisColors.textMuted),
                  ),
                  const SizedBox(height: 16),

                  // Valuation cards
                  Row(
                    children: [
                      Expanded(
                        child: _cardValuation('Valeur Achat Totale', '${totalAchat.toStringAsFixed(0)} FCFA', QuantisColors.royalBlue),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _cardValuation('Valeur Vente Totale', '${totalVente.toStringAsFixed(0)} FCFA', QuantisColors.success),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('LIGNES DU STOCK FIGÉ (${lignes.length} PRODUITS)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: QuantisColors.textMuted)),
                  const SizedBox(height: 8),

                  Expanded(
                    child: ListView.separated(
                      controller: controller,
                      itemCount: lignes.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, idx) {
                        final l = lignes[idx];
                        final qte = (l['quantiteProjetee'] as num? ?? 0).toDouble();
                        final valAchat = (l['valeurAchatTotale'] as num? ?? 0).toDouble();

                        return ListTile(
                          title: Text(l['produit']?['nom'] ?? 'Produit', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text('P.Achat: ${l['prixAchatUnitaire']} FCFA | P.Vente: ${l['prixVenteUnitaire']} FCFA'),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${qte.toStringAsFixed(0)} en stock', style: const TextStyle(fontWeight: FontWeight.bold, color: QuantisColors.royalBlue)),
                              Text('${valAchat.toStringAsFixed(0)} FCFA', style: const TextStyle(fontSize: 11, color: QuantisColors.textMuted)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _cardValuation(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Arrêts & Snapshots de Stock', style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadArrets),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: QuantisColors.error)))
              : Column(
                  children: [
                    // Header Actions Card
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        color: QuantisColors.royalBlue,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: MediaQuery.of(context).size.width < 600
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    const Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor: Colors.white24,
                                          child: Icon(Icons.camera_alt, color: Colors.white, size: 22),
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('GEL & AUDIT DE STOCK', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                                              SizedBox(height: 2),
                                              Text(
                                                'Instantané du stock',
                                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    ElevatedButton.icon(
                                      onPressed: _creating ? null : _creerArretStock,
                                      icon: _creating
                                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                                          : const Icon(Icons.add_a_photo, size: 18),
                                      label: const Text('Générer Arrêt'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: QuantisColors.luxuryGold,
                                        foregroundColor: Colors.black87,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      ),
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    const CircleAvatar(
                                      radius: 24,
                                      backgroundColor: Colors.white24,
                                      child: Icon(Icons.camera_alt, color: Colors.white, size: 28),
                                    ),
                                    const SizedBox(width: 16),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('GEL & AUDIT DE STOCK', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                                          SizedBox(height: 4),
                                          Text(
                                            'Créer un instantané du stock',
                                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: _creating ? null : _creerArretStock,
                                      icon: _creating
                                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                                          : const Icon(Icons.add_a_photo, size: 18),
                                      label: const Text('Générer Arrêt'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: QuantisColors.luxuryGold,
                                        foregroundColor: Colors.black87,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),

                    // List of stock snapshots
                    Expanded(
                      child: _arrets.isEmpty
                          ? const Center(child: Text('Aucun arrêt de stock effectué.', style: TextStyle(color: QuantisColors.textMuted)))
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _arrets.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final a = _arrets[index];
                                final totalAchat = (a['valeurTotaleAchat'] as num? ?? 0).toDouble();
                                final dateStr = a['dateArret'] != null
                                    ? a['dateArret'].toString().substring(0, 16).replaceAll('T', ' ')
                                    : '-';

                                return Card(
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    leading: CircleAvatar(
                                      backgroundColor: QuantisColors.royalBlue.withValues(alpha: 0.15),
                                      foregroundColor: QuantisColors.royalBlue,
                                      child: const Icon(Icons.inventory),
                                    ),
                                    title: Text(a['reference'] ?? 'Ref', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text('Date: $dateStr | Produits: ${a['nbrProduits'] ?? 0}'),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text('${totalAchat.toStringAsFixed(0)} FCFA', style: const TextStyle(fontWeight: FontWeight.bold, color: QuantisColors.royalBlue, fontSize: 14)),
                                            const Text('Valeur Achat', style: TextStyle(fontSize: 10, color: QuantisColors.textMuted)),
                                          ],
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.chevron_right, color: QuantisColors.royalBlue),
                                          onPressed: () => _afficherDetail(a),
                                        ),
                                      ],
                                    ),
                                    onTap: () => _afficherDetail(a),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}
