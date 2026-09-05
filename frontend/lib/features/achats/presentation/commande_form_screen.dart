import 'package:flutter/material.dart';
import '../../../core/theme/quantis_theme.dart';
import '../../../core/network/api_client.dart';
import '../data/achat_service.dart';

/// Écran formulaire de création d'une commande fournisseur.
class CommandeFormScreen extends StatefulWidget {
  const CommandeFormScreen({super.key});

  @override
  State<CommandeFormScreen> createState() => _CommandeFormScreenState();
}

class _CommandeFormScreenState extends State<CommandeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final AchatService _service = AchatService();

  // Données du formulaire
  int? _fournisseurId;
  int? _depotId;
  String? _notes;
  DateTime? _dateLivraisonPrevue;
  final List<_LigneForm> _lignes = [];

  // Données de référence
  List<Map<String, dynamic>> _fournisseurs = [];
  List<Map<String, dynamic>> _depots = [];
  List<Map<String, dynamic>> _produits = [];
  bool _loadingRef = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadReferenceData();
  }

  Future<void> _loadReferenceData() async {
    try {
      final dio = ApiClient.instance;
      final fRes = await dio.get('/suppliers', queryParameters: {'size': 200});
      final dRes = await dio.get('/stock/depots');
      final pRes = await dio.get('/products', queryParameters: {'size': 500});

      setState(() {
        _fournisseurs = (fRes.data['data']['content'] as List)
            .map((e) => {'id': e['id'], 'nom': e['nom']})
            .toList();
        _depots = (dRes.data['data'] as List)
            .map((e) => {'id': e['id'], 'nom': e['nom']})
            .toList();
        _produits = (pRes.data['data']['content'] as List)
            .map((e) => {
                  'id': e['id'],
                  'nom': e['nom'],
                  'prixAchat': (e['prixAchat'] as num?)?.toDouble() ?? 0.0,
                })
            .toList();
        _loadingRef = false;
      });
    } catch (e) {
      setState(() => _loadingRef = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur chargement données: $e'), backgroundColor: QuantisColors.error),
        );
      }
    }
  }

  void _addLigne() {
    setState(() {
      _lignes.add(_LigneForm());
    });
  }

  void _removeLigne(int index) {
    setState(() {
      _lignes.removeAt(index);
    });
  }

  double get _totalHt => _lignes.fold(0.0, (sum, l) => sum + l.montant);

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _dateLivraisonPrevue = date);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_lignes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoutez au moins une ligne'), backgroundColor: QuantisColors.error),
      );
      return;
    }
    // Validate lignes
    for (var l in _lignes) {
      if (l.produitId == null || l.quantite <= 0 || l.prixUnitaire <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vérifiez toutes les lignes (produit, quantité, prix)'), backgroundColor: QuantisColors.error),
        );
        return;
      }
    }

    _formKey.currentState!.save();
    setState(() => _submitting = true);

    try {
      final data = {
        'fournisseurId': _fournisseurId,
        'depotId': _depotId,
        if (_dateLivraisonPrevue != null)
          'dateLivraisonPrevue': _dateLivraisonPrevue!.toIso8601String().substring(0, 10),
        if (_notes != null && _notes!.isNotEmpty) 'notes': _notes,
        'lignes': _lignes
            .map((l) => {
                  'produitId': l.produitId,
                  'quantite': l.quantite,
                  'prixUnitaire': l.prixUnitaire,
                })
            .toList(),
      };

      await _service.creerCommande(data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Commande créée avec succès'), backgroundColor: QuantisColors.success),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: QuantisColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouvelle Commande'),
        actions: [
          TextButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check, color: Colors.white),
            label: Text(_submitting ? 'Envoi...' : 'Créer', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _loadingRef
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // === HEADER: Fournisseur & Dépôt ===
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Informations générales',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<int>(
                            decoration: const InputDecoration(
                              labelText: 'Fournisseur *',
                              prefixIcon: Icon(Icons.business),
                            ),
                            items: _fournisseurs
                                .map((f) => DropdownMenuItem<int>(
                                      value: f['id'] as int,
                                      child: Text(f['nom'] as String),
                                    ))
                                .toList(),
                            onChanged: (v) => _fournisseurId = v,
                            validator: (v) => v == null ? 'Sélectionnez un fournisseur' : null,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            decoration: const InputDecoration(
                              labelText: 'Dépôt de destination *',
                              prefixIcon: Icon(Icons.warehouse),
                            ),
                            items: _depots
                                .map((d) => DropdownMenuItem<int>(
                                      value: d['id'] as int,
                                      child: Text(d['nom'] as String),
                                    ))
                                .toList(),
                            onChanged: (v) => _depotId = v,
                            validator: (v) => v == null ? 'Sélectionnez un dépôt' : null,
                          ),
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: _pickDate,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Date de livraison prévue',
                                prefixIcon: Icon(Icons.calendar_today),
                              ),
                              child: Text(
                                _dateLivraisonPrevue != null
                                    ? '${_dateLivraisonPrevue!.day}/${_dateLivraisonPrevue!.month}/${_dateLivraisonPrevue!.year}'
                                    : 'Non définie',
                                style: TextStyle(
                                  color: _dateLivraisonPrevue != null ? null : QuantisColors.textMuted,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Notes',
                              prefixIcon: Icon(Icons.notes),
                            ),
                            maxLines: 2,
                            onSaved: (v) => _notes = v,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // === LIGNES DE COMMANDE ===
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Lignes de commande',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ElevatedButton.icon(
                        onPressed: _addLigne,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Ajouter'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: QuantisColors.royalBlue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (_lignes.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(Icons.shopping_cart_outlined, size: 48,
                                color: QuantisColors.textMuted.withValues(alpha: 0.4)),
                            const SizedBox(height: 8),
                            const Text('Aucune ligne ajoutée',
                                style: TextStyle(color: QuantisColors.textMuted)),
                            const SizedBox(height: 4),
                            const Text('Appuyez sur "Ajouter" pour ajouter des produits',
                                style: TextStyle(color: QuantisColors.textMuted, fontSize: 12)),
                          ],
                        ),
                      ),
                    )
                  else
                    ...List.generate(_lignes.length, (i) {
                      final ligne = _lignes[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: QuantisColors.royalBlue.withValues(alpha: 0.1),
                                    child: Text('${i + 1}',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: QuantisColors.royalBlue)),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: QuantisColors.error, size: 20),
                                    onPressed: () => _removeLigne(i),
                                    tooltip: 'Supprimer',
                                  ),
                                ],
                              ),
                              DropdownButtonFormField<int>(
                                decoration: const InputDecoration(
                                  labelText: 'Produit',
                                  isDense: true,
                                ),
                                value: ligne.produitId,
                                items: _produits
                                    .map((p) => DropdownMenuItem<int>(
                                          value: p['id'] as int,
                                          child: Text(p['nom'] as String, overflow: TextOverflow.ellipsis),
                                        ))
                                    .toList(),
                                onChanged: (v) {
                                  setState(() {
                                    ligne.produitId = v;
                                    // Auto-fill prix achat
                                    final prod = _produits.firstWhere((p) => p['id'] == v, orElse: () => {});
                                    if (prod.isNotEmpty) {
                                      ligne.prixUnitaire = (prod['prixAchat'] as double?) ?? 0;
                                      ligne.prixController.text = ligne.prixUnitaire.toStringAsFixed(0);
                                    }
                                  });
                                },
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      decoration: const InputDecoration(
                                        labelText: 'Quantité',
                                        isDense: true,
                                      ),
                                      keyboardType: TextInputType.number,
                                      controller: ligne.qtyController,
                                      onChanged: (v) => setState(() {
                                        ligne.quantite = double.tryParse(v) ?? 0;
                                      }),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      decoration: const InputDecoration(
                                        labelText: 'Prix unitaire (FCFA)',
                                        isDense: true,
                                      ),
                                      keyboardType: TextInputType.number,
                                      controller: ligne.prixController,
                                      onChanged: (v) => setState(() {
                                        ligne.prixUnitaire = double.tryParse(v) ?? 0;
                                      }),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  'Montant: ${ligne.montant.toStringAsFixed(0)} FCFA',
                                  style: const TextStyle(fontWeight: FontWeight.w700, color: QuantisColors.royalBlue),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                  const SizedBox(height: 16),

                  // === TOTAL ===
                  if (_lignes.isNotEmpty)
                    Card(
                      color: QuantisColors.royalBlue.withValues(alpha: 0.05),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total HT',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                            Text(
                              '${_totalHt.toStringAsFixed(0)} FCFA',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: QuantisColors.royalBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 80), // Space for FAB
                ],
              ),
            ),
    );
  }
}

/// Classe helper pour gérer l'état d'une ligne du formulaire.
class _LigneForm {
  int? produitId;
  double quantite = 0;
  double prixUnitaire = 0;
  final TextEditingController qtyController = TextEditingController();
  final TextEditingController prixController = TextEditingController();

  double get montant => quantite * prixUnitaire;
}
