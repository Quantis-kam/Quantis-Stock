import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/quantis_theme.dart';
import '../../../core/network/api_client.dart';

/// Dialogue affichant les suggestions intelligentes de réapprovisionnement basées sur la vitesse de rotation des ventes.
class ReapprovisionnementDialog extends StatefulWidget {
  const ReapprovisionnementDialog({super.key});

  @override
  State<ReapprovisionnementDialog> createState() => _ReapprovisionnementDialogState();
}

class _ReapprovisionnementDialogState extends State<ReapprovisionnementDialog> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _suggestions = [];
  final Set<int> _selectedIndices = {};
  int _targetDays = 30; // 15, 30, 45 jours

  @override
  void initState() {
    super.initState();
    _fetchSuggestions();
  }

  Future<void> _fetchSuggestions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ApiClient.instance.get('/stock/reapprovisionnement-suggestions');
      final data = response.data['data'] as List<dynamic>? ?? [];
      setState(() {
        _suggestions = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _selectedIndices.clear();
        for (int i = 0; i < _suggestions.length; i++) {
          _selectedIndices.add(i); // Tout sélectionner par défaut
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Impossible de charger les suggestions : $e';
        _isLoading = false;
      });
    }
  }

  double get _montantTotalEstime {
    double total = 0;
    for (int i in _selectedIndices) {
      if (i < _suggestions.length) {
        final s = _suggestions[i];
        final qte = (s['quantiteSuggeree'] as num?)?.toDouble() ?? 0;
        final prix = (s['prixAchat'] as num?)?.toDouble() ?? 0;
        total += (qte * prix);
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'fr_FR', symbol: ApiClient.entrepriseMonnaie, decimalDigits: 0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 900,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête avec bouton fermer
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: QuantisColors.luxuryGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_awesome, color: QuantisColors.luxuryGold, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Suggestions Intelligentes de Réapprovisionnement',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Calculé selon l\'historique des ventes sur 30 jours et les seuils d\'alerte',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  tooltip: 'Fermer',
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            // Barre d'outils (Filtres de jours de buffer + Résumé)
            Row(
              children: [
                const Text('Objectif de stock :', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(width: 10),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 15, label: Text('15 Jours')),
                    ButtonSegment(value: 30, label: Text('30 Jours (Recommandé)')),
                    ButtonSegment(value: 45, label: Text('45 Jours')),
                  ],
                  selected: {_targetDays},
                  onSelectionChanged: (set) {
                    setState(() => _targetDays = set.first);
                  },
                ),
                const Spacer(),
                IconButton(
                  onPressed: _fetchSuggestions,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Actualiser les calculs',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Contenu principal
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, color: QuantisColors.error, size: 48),
                              const SizedBox(height: 12),
                              Text(_error!, style: const TextStyle(color: QuantisColors.error)),
                              const SizedBox(height: 12),
                              ElevatedButton(onPressed: _fetchSuggestions, child: const Text('Réessayer')),
                            ],
                          ),
                        )
                      : _suggestions.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle_outline, color: QuantisColors.success, size: 56),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Tous vos stocks sont à un niveau optimal !',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Aucun article ne nécessite de commande urgente pour le moment.',
                                    style: TextStyle(color: Colors.grey, fontSize: 13),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: _suggestions.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final s = _suggestions[index];
                                final isSelected = _selectedIndices.contains(index);
                                final urgence = s['statutUrgence'] ?? 'NORMAL';
                                final isCritique = urgence == 'CRITIQUE';
                                final stockActuel = (s['stockActuel'] as num?)?.toDouble() ?? 0;
                                final ventesMois = (s['ventesMoisDernier'] as num?)?.toDouble() ?? 0;
                                final joursAutonomie = s['joursAutonomie'] as int?;
                                final qteSuggeree = (s['quantiteSuggeree'] as num?)?.toDouble() ?? 0;
                                final prixAchat = (s['prixAchat'] as num?)?.toDouble() ?? 0;

                                return Container(
                                  color: isSelected ? QuantisColors.royalBlue.withValues(alpha: 0.03) : Colors.transparent,
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                  child: Row(
                                    children: [
                                      Checkbox(
                                        value: isSelected,
                                        onChanged: (val) {
                                          setState(() {
                                            if (val == true) {
                                              _selectedIndices.add(index);
                                            } else {
                                              _selectedIndices.remove(index);
                                            }
                                          });
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      // Badge Urgence
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isCritique
                                              ? QuantisColors.error.withValues(alpha: 0.15)
                                              : QuantisColors.warning.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: isCritique ? QuantisColors.error : QuantisColors.warning,
                                          ),
                                        ),
                                        child: Text(
                                          isCritique ? 'CRITIQUE' : 'ATTENTION',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isCritique ? QuantisColors.error : const Color(0xFFB45309),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      // Info Produit
                                      Expanded(
                                        flex: 3,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              s['nom'] ?? 'Produit',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                            Text(
                                              'SKU: ${s['sku'] ?? 'N/A'} • Catégorie: ${s['categorie'] ?? 'Général'}',
                                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Stock actuel & Jours restants
                                      Expanded(
                                        flex: 2,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Stock : ${stockActuel.toStringAsFixed(0)} ${s['unite'] ?? ''}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12,
                                                color: stockActuel <= 0 ? QuantisColors.error : Colors.black87,
                                              ),
                                            ),
                                            Text(
                                              joursAutonomie != null
                                                  ? 'Autonomie : ~${joursAutonomie}j'
                                                  : 'Ventes 30j : ${ventesMois.toStringAsFixed(0)}',
                                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Quantité suggérée
                                      Expanded(
                                        flex: 2,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              '+${qteSuggeree.toStringAsFixed(0)} ${s['unite'] ?? ''}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: QuantisColors.royalBlue,
                                              ),
                                            ),
                                            Text(
                                              'PU : ${currency.format(prixAchat)}',
                                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Montant total estimé
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          currency.format(qteSuggeree * prixAchat),
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
            ),

            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),

            // Pied de page avec total et bouton de commande
            Row(
              children: [
                Text(
                  '${_selectedIndices.length} article(s) sélectionné(s)',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Coût estimé total :', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    Text(
                      currency.format(_montantTotalEstime),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: QuantisColors.royalBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                ElevatedButton.icon(
                  onPressed: _selectedIndices.isEmpty
                      ? null
                      : () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${_selectedIndices.length} articles ajoutés à votre prévision de commande fournisseur !',
                              ),
                              backgroundColor: QuantisColors.success,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                  icon: const Icon(Icons.shopping_cart_checkout),
                  label: const Text('Valider pour Commande Fournisseur'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: QuantisColors.royalBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
