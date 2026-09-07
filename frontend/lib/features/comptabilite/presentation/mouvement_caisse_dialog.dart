import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/quantis_theme.dart';

/// Dialogue d'enregistrement manuel d'une entrée ou sortie de caisse.
class MouvementCaisseDialog extends StatefulWidget {
  final VoidCallback onSaved;

  const MouvementCaisseDialog({super.key, required this.onSaved});

  @override
  State<MouvementCaisseDialog> createState() => _MouvementCaisseDialogState();
}

class _MouvementCaisseDialogState extends State<MouvementCaisseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _montantController = TextEditingController();
  final _libelleController = TextEditingController();
  final _notesController = TextEditingController();

  String _type = 'SORTIE'; // 'ENTREE' ou 'SORTIE'
  String _categorie = 'FRAIS_GENERAUX';
  bool _loading = false;
  String? _error;

  final List<Map<String, String>> _categoriesEntree = [
    {'code': 'APPORT_MONNAIE', 'label': 'Apport de monnaie'},
    {'code': 'VENTE_DIVERS', 'label': 'Recette diverse'},
    {'code': 'AUTRE_ENTREE', 'label': 'Autre entrée'},
  ];

  final List<Map<String, String>> _categoriesSortie = [
    {'code': 'FRAIS_GENERAUX', 'label': 'Frais généraux & fournitures'},
    {'code': 'TRANSPORT', 'label': 'Transport & logistique'},
    {'code': 'FACTURES_CHARGES', 'label': 'Eau / Électricité / Internet'},
    {'code': 'RETRAIT_BANQUE', 'label': 'Retrait / Dépôt banque'},
    {'code': 'AUTRE_SORTIE', 'label': 'Autre dépense'},
  ];

  @override
  void dispose() {
    _montantController.dispose();
    _libelleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      final dio = ApiClient.instance;
      final montant = double.tryParse(_montantController.text.replaceAll(' ', '')) ?? 0;

      await dio.post('/accounting/cash', data: {
        'type': _type,
        'montant': montant,
        'libelle': _libelleController.text.trim(),
        'categorie': _categorie,
        'notes': _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      });

      if (mounted) {
        Navigator.of(context).pop();
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_type == 'ENTREE' ? 'Entrée de caisse enregistrée !' : 'Sortie de caisse enregistrée !'),
            backgroundColor: QuantisColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() { _error = 'Erreur : $e'; });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = _type == 'ENTREE' ? _categoriesEntree : _categoriesSortie;
    final isMobile = MediaQuery.of(context).size.width < 600;
    final screenWidth = MediaQuery.of(context).size.width;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 40,
        vertical: isMobile ? 16 : 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isMobile ? screenWidth * 0.95 : 500),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: (_type == 'ENTREE' ? QuantisColors.success : QuantisColors.error).withValues(alpha: 0.15),
                      child: Icon(
                        _type == 'ENTREE' ? Icons.arrow_downward : Icons.arrow_upward,
                        color: _type == 'ENTREE' ? QuantisColors.success : QuantisColors.error,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Mouvement de Caisse',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: isMobile ? 18 : null),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Type selector
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.arrow_downward, size: 16, color: QuantisColors.success),
                            SizedBox(width: 4),
                            Flexible(child: Text('Entrée', overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                        selected: _type == 'ENTREE',
                        selectedColor: QuantisColors.success.withValues(alpha: 0.2),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _type = 'ENTREE';
                              _categorie = 'APPORT_MONNAIE';
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ChoiceChip(
                        label: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.arrow_upward, size: 16, color: QuantisColors.error),
                            SizedBox(width: 4),
                            Flexible(child: Text('Sortie', overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                        selected: _type == 'SORTIE',
                        selectedColor: QuantisColors.error.withValues(alpha: 0.2),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _type = 'SORTIE';
                              _categorie = 'FRAIS_GENERAUX';
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Montant
                TextFormField(
                  controller: _montantController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Montant (${ApiClient.entrepriseMonnaie}) *',
                    hintText: 'Ex: 15000',
                    prefixIcon: const Icon(Icons.payments_outlined),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Montant obligatoire';
                    if (double.tryParse(val.replaceAll(' ', '')) == null) return 'Montant invalide';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Libellé
                TextFormField(
                  controller: _libelleController,
                  decoration: const InputDecoration(
                    labelText: 'Libellé / Motif *',
                    hintText: 'Ex: Achat fournitures bureau, Carburant livraison...',
                    prefixIcon: Icon(Icons.edit_note),
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Libellé obligatoire';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Catégorie
                DropdownButtonFormField<String>(
                  value: _categorie,
                  decoration: const InputDecoration(
                    labelText: 'Catégorie de mouvement',
                    prefixIcon: Icon(Icons.category_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: categories.map((c) => DropdownMenuItem(
                    value: c['code'],
                    child: Text(c['label']!, overflow: TextOverflow.ellipsis),
                  )).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _categorie = val);
                  },
                ),
                const SizedBox(height: 12),

                // Notes
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes ou référence (optionnel)',
                    hintText: 'Ex: Reçu N° 4528, facture Sonabel...',
                    prefixIcon: Icon(Icons.receipt_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Text(_error!, style: const TextStyle(color: QuantisColors.error, fontSize: 12)),
                  ),

                if (isMobile)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _loading ? null : _submit,
                        icon: _loading
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.check, size: 18),
                        label: const Text('Enregistrer le Mouvement'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _type == 'ENTREE' ? QuantisColors.success : QuantisColors.error,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Annuler'),
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Annuler'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _loading ? null : _submit,
                        icon: _loading
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.check, size: 18),
                        label: const Text('Enregistrer le Mouvement'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _type == 'ENTREE' ? QuantisColors.success : QuantisColors.error,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
