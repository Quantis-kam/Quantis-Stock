import 'package:flutter/material.dart';
import '../../../core/theme/quantis_theme.dart';
import '../../../core/utils/permission_helper.dart';
import '../../produits/data/produit_service.dart';
import '../data/stock_service.dart';

class MouvementRapideDialog extends StatefulWidget {
  final List<DepotModel> depots;
  final int? initialDepotId;

  const MouvementRapideDialog({
    super.key,
    required this.depots,
    this.initialDepotId,
  });

  @override
  State<MouvementRapideDialog> createState() => _MouvementRapideDialogState();
}

class _MouvementRapideDialogState extends State<MouvementRapideDialog> {
  final _formKey = GlobalKey<FormState>();
  final _stockService = StockApiService();
  final _produitService = ProduitService();

  String _selectedType = 'ENTREE';
  String _selectedMotif = 'ACHAT';
  int? _selectedSourceDepotId;
  int? _selectedDestDepotId;
  
  List<ProduitModel> _produits = [];
  ProduitModel? _selectedProduit;
  VarianteModel? _selectedVariante;
  
  final _qtyCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();
  
  bool _loadingProduits = true;
  bool _submitting = false;
  bool _forcerSortie = false;

  @override
  void initState() {
    super.initState();
    _selectedSourceDepotId = widget.initialDepotId;
    _selectedDestDepotId = widget.initialDepotId;
    _loadProduits();
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _refCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProduits() async {
    try {
      final list = await _produitService.getProduits(size: 200);
      setState(() {
        _produits = list.where((p) => p.actif).toList();
        _loadingProduits = false;
      });
    } catch (_) {
      setState(() => _loadingProduits = false);
    }
  }

  List<String> _getMotifs(String type) => switch (type) {
        'ENTREE' => ['ACHAT', 'RETOUR', 'AUTRE'],
        'SORTIE' => ['VENTE', 'CASSE', 'PERTE', 'AUTRE'],
        'TRANSFERT' => ['TRANSFERT', 'AUTRE'],
        'AJUSTEMENT' => ['INVENTAIRE', 'AUTRE'],
        _ => ['AUTRE'],
      };

  String _motifLabel(String motif) => switch (motif) {
        'ACHAT' => 'Réception Achat',
        'VENTE' => 'Vente / Livraison',
        'RETOUR' => 'Retour Client / Fournisseur',
        'CASSE' => 'Casse',
        'PERTE' => 'Perte / Vol',
        'TRANSFERT' => 'Transfert Inter-dépôt',
        'INVENTAIRE' => 'Régularisation Inventaire',
        _ => 'Autre motif',
      };

  void _onTypeChanged(String? type) {
    if (type == null) return;
    setState(() {
      _selectedType = type;
      final motifs = _getMotifs(type);
      _selectedMotif = motifs.first;
      
      // Ajuster les dépôts par défaut
      if (type == 'ENTREE') {
        _selectedSourceDepotId = null;
        _selectedDestDepotId = widget.initialDepotId ?? (widget.depots.isNotEmpty ? widget.depots.first.id : null);
      } else if (type == 'SORTIE') {
        _selectedSourceDepotId = widget.initialDepotId ?? (widget.depots.isNotEmpty ? widget.depots.first.id : null);
        _selectedDestDepotId = null;
      } else if (type == 'TRANSFERT') {
        _selectedSourceDepotId = widget.depots.isNotEmpty ? widget.depots.first.id : null;
        _selectedDestDepotId = widget.depots.length > 1 ? widget.depots[1].id : null;
      } else if (type == 'AJUSTEMENT') {
        _selectedSourceDepotId = widget.initialDepotId ?? (widget.depots.isNotEmpty ? widget.depots.first.id : null);
        _selectedDestDepotId = null;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProduit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un produit')),
      );
      return;
    }

    setState(() => _submitting = true);
    
    try {
      final Map<String, dynamic> payload = {
        'type': _selectedType,
        'motif': _selectedMotif,
        'produitId': _selectedProduit!.id,
        if (_selectedVariante != null) 'varianteId': _selectedVariante!.id,
        if (_selectedSourceDepotId != null) 'depotSourceId': _selectedSourceDepotId,
        if (_selectedDestDepotId != null) 'depotDestId': _selectedDestDepotId,
        'quantite': double.parse(_qtyCtrl.text),
        if (_refCtrl.text.isNotEmpty) 'reference': _refCtrl.text,
        if (_commentCtrl.text.isNotEmpty) 'commentaire': _commentCtrl.text,
        if (_forcerSortie) 'forcerSortie': true,
      };

      await _stockService.enregistrerMouvement(payload);
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mouvement de stock enregistré avec succès !'),
            backgroundColor: QuantisColors.success,
          ),
        );
      }
    } catch (e) {
      String errMsg = 'Erreur lors de l\'enregistrement';
      if (e is Exception) {
        errMsg = e.toString().replaceFirst('Exception: ', '');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errMsg),
          backgroundColor: QuantisColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final motifs = _getMotifs(_selectedType);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.swap_horiz, color: QuantisColors.royalBlue),
          const SizedBox(width: 8),
          Text(
            'Mouvement de Stock Rapide',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: QuantisColors.royalBlue,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: _loadingProduits
            ? const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              )
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Type de mouvement
                      DropdownButtonFormField<String>(
                        value: _selectedType,
                        decoration: const InputDecoration(
                          labelText: 'Type de mouvement',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'ENTREE', child: Text('Entrée de Stock')),
                          DropdownMenuItem(value: 'SORTIE', child: Text('Sortie de Stock')),
                          DropdownMenuItem(value: 'TRANSFERT', child: Text('Transfert Inter-dépôt')),
                          DropdownMenuItem(value: 'AJUSTEMENT', child: Text('Ajustement / Inventaire')),
                        ],
                        onChanged: _onTypeChanged,
                      ),
                      const SizedBox(height: 16),

                      // Motif de mouvement
                      DropdownButtonFormField<String>(
                        value: _selectedMotif,
                        decoration: const InputDecoration(
                          labelText: 'Motif du mouvement',
                          prefixIcon: Icon(Icons.info_outline),
                        ),
                        items: motifs.map((m) {
                          return DropdownMenuItem(value: m, child: Text(_motifLabel(m)));
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedMotif = val!),
                      ),
                      const SizedBox(height: 16),

                      // Source Depot (if required)
                      if (_selectedType == 'SORTIE' || _selectedType == 'TRANSFERT' || _selectedType == 'AJUSTEMENT')
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: DropdownButtonFormField<int>(
                            value: _selectedSourceDepotId,
                            decoration: InputDecoration(
                              labelText: _selectedType == 'TRANSFERT' ? 'Dépôt Source' : 'Dépôt',
                              prefixIcon: const Icon(Icons.warehouse_outlined),
                            ),
                            items: widget.depots.map((d) {
                              return DropdownMenuItem(value: d.id, child: Text(d.nom));
                            }).toList(),
                            validator: (val) => val == null ? 'Veuillez choisir un dépôt' : null,
                            onChanged: (val) => setState(() => _selectedSourceDepotId = val),
                          ),
                        ),

                      // Destination Depot (if required)
                      if (_selectedType == 'ENTREE' || _selectedType == 'TRANSFERT')
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: DropdownButtonFormField<int>(
                            value: _selectedDestDepotId,
                            decoration: InputDecoration(
                              labelText: _selectedType == 'TRANSFERT' ? 'Dépôt Destination' : 'Dépôt',
                              prefixIcon: const Icon(Icons.warehouse_outlined),
                            ),
                            items: widget.depots.map((d) {
                              return DropdownMenuItem(value: d.id, child: Text(d.nom));
                            }).toList(),
                            validator: (val) => val == null ? 'Veuillez choisir un dépôt' : null,
                            onChanged: (val) => setState(() => _selectedDestDepotId = val),
                          ),
                        ),

                      // Product Selector (with Search)
                      Autocomplete<ProduitModel>(
                        displayStringForOption: (p) => '${p.nom} (${p.reference})',
                        optionsBuilder: (textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return const Iterable<ProduitModel>.empty();
                          }
                          return _produits.where((p) =>
                              p.nom.toLowerCase().contains(textEditingValue.text.toLowerCase()) ||
                              p.reference.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                        },
                        onSelected: (p) {
                          setState(() {
                            _selectedProduit = p;
                            _selectedVariante = null;
                          });
                        },
                        fieldViewBuilder: (ctx, ctrl, focusNode, onFieldSubmitted) {
                          return TextFormField(
                            controller: ctrl,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                              labelText: 'Rechercher Produit (Nom, Code/SKU)',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.qr_code_scanner, color: QuantisColors.luxuryGold),
                                tooltip: 'Simuler Scan Code-barres',
                                onPressed: () {
                                  if (_produits.isNotEmpty) {
                                    final p = _produits.first;
                                    ctrl.text = '${p.nom} (${p.reference})';
                                    setState(() {
                                      _selectedProduit = p;
                                      _selectedVariante = null;
                                    });
                                  }
                                },
                              ),
                            ),
                            validator: (val) => _selectedProduit == null ? 'Veuillez choisir un produit' : null,
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // Product Variants (if exists)
                      if (_selectedProduit != null && _selectedProduit!.variantes.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: DropdownButtonFormField<VarianteModel>(
                            value: _selectedVariante,
                            decoration: const InputDecoration(
                              labelText: 'Variante de produit',
                              prefixIcon: Icon(Icons.style_outlined),
                            ),
                            items: _selectedProduit!.variantes.map((v) {
                              return DropdownMenuItem(
                                value: v,
                                child: Text('${v.attribut} : ${v.valeur}'),
                              );
                            }).toList(),
                            validator: (val) => val == null ? 'Veuillez choisir une variante' : null,
                            onChanged: (val) => setState(() => _selectedVariante = val),
                          ),
                        ),

                      // Quantity
                      TextFormField(
                        controller: _qtyCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Quantité',
                          prefixIcon: Icon(Icons.production_quantity_limits),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'La quantité est requise';
                          final q = double.tryParse(val);
                          if (q == null || q <= 0) return 'La quantité doit être supérieure à 0';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Reference
                      TextFormField(
                        controller: _refCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Référence (N° Facture, Commande...)',
                          prefixIcon: Icon(Icons.tag),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Commentaire
                      TextFormField(
                        controller: _commentCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Commentaire / Motif détaillé',
                          prefixIcon: Icon(Icons.comment_outlined),
                        ),
                      ),

                      // Forcer Sortie (Admin uniquement)
                      if ((_selectedType == 'SORTIE' || _selectedType == 'TRANSFERT') &&
                          PermissionHelper.hasPermission('FORCE_SORTIE'))
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: CheckboxListTile(
                            value: _forcerSortie,
                            onChanged: (v) => setState(() => _forcerSortie = v ?? false),
                            title: const Text('Forcer la sortie (stock négatif)',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            subtitle: const Text('Autorise le stock à devenir négatif',
                                style: TextStyle(fontSize: 11, color: QuantisColors.error)),
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                            activeColor: QuantisColors.error,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler', style: TextStyle(color: QuantisColors.textMuted)),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: QuantisColors.royalBlue,
            foregroundColor: Colors.white,
          ),
          child: _submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text('Valider'),
        ),
      ],
    );
  }
}
