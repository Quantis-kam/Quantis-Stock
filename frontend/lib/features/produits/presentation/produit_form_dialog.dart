import 'package:flutter/material.dart';
import 'dart:math';
import '../../../core/network/api_client.dart';
import '../../../core/theme/quantis_theme.dart';
import '../../../core/widgets/quantis_field_toggle.dart';
import '../data/produit_service.dart';
import '../data/categorie_service.dart';

class ProduitFormDialog extends StatefulWidget {
  final ProduitModel? produit;
  const ProduitFormDialog({super.key, this.produit});

  @override
  State<ProduitFormDialog> createState() => _ProduitFormDialogState();
}

class _ProduitFormDialogState extends State<ProduitFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _produitService = ProduitService();
  final _categorieService = CategorieService();

  late TextEditingController _nomCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _skuCtrl;
  late TextEditingController _barcodeCtrl;
  late TextEditingController _prixAchatCtrl;
  late TextEditingController _prixVenteCtrl;
  late TextEditingController _seuilCtrl;
  late TextEditingController _tvaCtrl;

  int? _selectedCategorieId;
  int? _selectedUniteId;

  List<CategorieModel> _categories = [];
  List<UniteMesureModel> _units = [];
  List<VarianteModel> _variantes = [];

  bool _loading = false;
  bool _saving = false;

  // Interrupteurs inline façon Cloudflare (contrôle direct sur chaque champ)
  bool _hasPrixAchat = true;
  bool _hasTva = true;
  bool _hasSeuilAlerte = true;

  // Real-time Margin details
  double _prixAchat = 0;
  double _marge = 0;
  double _margePercent = 0;

  static double _parseNumber(String raw) {
    final cleaned = raw.trim().replaceAll('%', '').replaceAll(' ', '').replaceAll(',', '.');
    return double.tryParse(cleaned) ?? 0.0;
  }

  static String _formatTva(double value) {
    return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
  }

  @override
  void initState() {
    super.initState();
    final p = widget.produit;
    final defaultTvaRate = ApiClient.tauxTvaDefaut > 0 ? ApiClient.tauxTvaDefaut : 18.0;

    _hasPrixAchat = p != null ? p.prixAchat > 0 : ApiClient.suiviPrixAchat;
    _hasTva = p != null ? p.tauxTva > 0 : ApiClient.tvaActive;
    _hasSeuilAlerte = p != null ? p.seuilAlerte > 0 : true;

    _nomCtrl = TextEditingController(text: p?.nom ?? '');
    _descCtrl = TextEditingController(text: p?.description ?? '');
    _skuCtrl = TextEditingController(text: p?.reference ?? '');
    _barcodeCtrl = TextEditingController(text: p?.codeBarres ?? '');
    _prixAchatCtrl = TextEditingController(
      text: (p != null && p.prixAchat > 0) ? p.prixAchat.toStringAsFixed(0) : '',
    );
    _prixVenteCtrl = TextEditingController(
      text: p != null ? p.prixVente.toStringAsFixed(0) : '',
    );
    _seuilCtrl = TextEditingController(
      text: (p != null && p.seuilAlerte > 0) ? p.seuilAlerte.toString() : '10',
    );
    _tvaCtrl = TextEditingController(
      text: (p != null && p.tauxTva > 0) ? _formatTva(p.tauxTva) : _formatTva(defaultTvaRate),
    );

    _selectedCategorieId = p?.categorieId;
    _selectedUniteId = p?.uniteId;
    _variantes = p != null ? List.from(p.variantes) : [];

    _prixAchatCtrl.addListener(_updateMargin);
    _prixVenteCtrl.addListener(_updateMargin);
    
    _loadMetadata();
    _updateMargin();
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _descCtrl.dispose();
    _skuCtrl.dispose();
    _barcodeCtrl.dispose();
    _prixAchatCtrl.dispose();
    _prixVenteCtrl.dispose();
    _seuilCtrl.dispose();
    _tvaCtrl.dispose();
    super.dispose();
  }

  void _updateMargin() {
    final pa = _parseNumber(_prixAchatCtrl.text);
    final pv = _parseNumber(_prixVenteCtrl.text);
    setState(() {
      _prixAchat = pa;
      _marge = pa > 0 ? (pv - pa) : 0;
      _margePercent = pa > 0 ? (_marge / pa) * 100 : 0;
    });
  }

  Future<void> _loadMetadata() async {
    setState(() => _loading = true);
    try {
      final cats = await _categorieService.getCategories();
      final units = await _produitService.getUnits();
      setState(() {
        _categories = cats;
        _units = units;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur chargement métadonnées: $e'), backgroundColor: QuantisColors.error),
      );
    }
  }

  void _generateMockBarcode() {
    final rand = Random();
    // Generate a typical 13-digit EAN code starting with '613' (typical region prefix)
    final digits = List.generate(10, (_) => rand.nextInt(10)).join();
    setState(() {
      _barcodeCtrl.text = '613$digits';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.qr_code_scanner, color: Colors.white),
            SizedBox(width: 8),
            Text('Code-barres scanné avec succès !'),
          ],
        ),
        backgroundColor: QuantisColors.success,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _addVariante() {
    final attrCtrl = TextEditingController();
    final valCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ajouter une Variante'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: attrCtrl,
              decoration: const InputDecoration(labelText: 'Attribut (ex: Taille, Couleur)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: valCtrl,
              decoration: const InputDecoration(labelText: 'Valeur (ex: XL, Rouge)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              if (attrCtrl.text.isNotEmpty && valCtrl.text.isNotEmpty) {
                setState(() {
                  _variantes.add(VarianteModel(
                    attribut: attrCtrl.text.trim(),
                    valeur: valCtrl.text.trim(),
                  ));
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _saving = true);
    
    final prd = ProduitModel(
      id: widget.produit?.id,
      nom: _nomCtrl.text.trim(),
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      reference: _skuCtrl.text.trim(),
      codeBarres: _barcodeCtrl.text.trim().isEmpty ? null : _barcodeCtrl.text.trim(),
      prixAchat: _hasPrixAchat ? _parseNumber(_prixAchatCtrl.text) : 0.0,
      prixVente: _parseNumber(_prixVenteCtrl.text),
      tauxTva: _hasTva ? _parseNumber(_tvaCtrl.text) : 0.0,
      seuilAlerte: _hasSeuilAlerte ? (int.tryParse(_seuilCtrl.text.trim()) ?? 10) : 0,
      categorieId: _selectedCategorieId,
      uniteId: _selectedUniteId,
      variantes: _variantes,
      actif: widget.produit?.actif ?? true,
    );

    try {
      if (widget.produit == null) {
        await _produitService.createProduit(prd);
      } else {
        await _produitService.updateProduit(widget.produit!.id!, prd);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiClient.formatErrorMessage(e, fallback: 'Erreur d\'enregistrement')),
            backgroundColor: QuantisColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.produit == null ? 'Ajouter un Produit' : 'Modifier le Produit';

    final isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 40,
        vertical: 24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: min(MediaQuery.of(context).size.width * 0.95, 700),
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: _loading
            ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: isMobile ? 18 : 20,
                                fontWeight: FontWeight.bold,
                                color: QuantisColors.royalBlue,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                        ],
                      ),
                      const Divider(height: 24),
                      
                      // Section Informations générales
                      const Text('Informations Générales', style: TextStyle(fontWeight: FontWeight.bold, color: QuantisColors.textSecondary)),
                      const SizedBox(height: 12),
                      
                      if (isMobile) ...[
                        TextFormField(
                          controller: _nomCtrl,
                          decoration: const InputDecoration(labelText: 'Nom du produit *'),
                          validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _skuCtrl,
                          decoration: const InputDecoration(labelText: 'SKU / Référence *'),
                          validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                        ),
                      ] else
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _nomCtrl,
                                decoration: const InputDecoration(labelText: 'Nom du produit *'),
                                validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _skuCtrl,
                                decoration: const InputDecoration(labelText: 'SKU / Référence *'),
                                validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 16),
                      
                      if (isMobile) ...[
                        TextFormField(
                          controller: _barcodeCtrl,
                          decoration: InputDecoration(
                            labelText: 'Code-barres',
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.qr_code_scanner, color: QuantisColors.luxuryGold),
                              tooltip: 'Simuler Scan Barcode',
                              onPressed: _generateMockBarcode,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _descCtrl,
                          decoration: const InputDecoration(labelText: 'Description'),
                        ),
                      ] else
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _barcodeCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Code-barres',
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.qr_code_scanner, color: QuantisColors.luxuryGold),
                                    tooltip: 'Simuler Scan Barcode',
                                    onPressed: _generateMockBarcode,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _descCtrl,
                                decoration: const InputDecoration(labelText: 'Description'),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 16),

                      if (isMobile) ...[
                        DropdownButtonFormField<int>(
                          value: _selectedCategorieId,
                          decoration: const InputDecoration(labelText: 'Catégorie'),
                          items: _categories
                              .map((c) => DropdownMenuItem(value: c.id, child: Text(c.nom)))
                              .toList(),
                          onChanged: (val) => setState(() => _selectedCategorieId = val),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          value: _selectedUniteId,
                          decoration: const InputDecoration(labelText: 'Unité de Mesure'),
                          items: _units
                              .map((u) => DropdownMenuItem(value: u.id, child: Text('${u.nom} (${u.abreviation})')))
                              .toList(),
                          onChanged: (val) => setState(() => _selectedUniteId = val),
                        ),
                      ] else
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                value: _selectedCategorieId,
                                decoration: const InputDecoration(labelText: 'Catégorie'),
                                items: _categories
                                    .map((c) => DropdownMenuItem(value: c.id, child: Text(c.nom)))
                                    .toList(),
                                onChanged: (val) => setState(() => _selectedCategorieId = val),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                value: _selectedUniteId,
                                decoration: const InputDecoration(labelText: 'Unité de Mesure'),
                                items: _units
                                    .map((u) => DropdownMenuItem(value: u.id, child: Text('${u.nom} (${u.abreviation})')))
                                    .toList(),
                                onChanged: (val) => setState(() => _selectedUniteId = val),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 24),

                      // Section Prix, TVA & Stock (avec boutons interrupteurs inline)
                      Text(
                        'Prix, Taxes & Stock (${ApiClient.entrepriseMonnaie})',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: QuantisColors.textSecondary),
                      ),
                      const SizedBox(height: 12),

                      // Prix de vente (toujours visible et obligatoire)
                      TextFormField(
                        controller: _prixVenteCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Prix de vente (${ApiClient.entrepriseMonnaie}) *',
                          hintText: 'Ex: 5000',
                          prefixIcon: const Icon(Icons.sell_outlined),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Requis' : null,
                      ),
                      const SizedBox(height: 14),

                      // Blocs de champs activables façon Cloudflare (Prix d'achat, TVA, Alerte stock)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Prix d'achat
                            isMobile
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      QuantisFieldToggle(
                                        title: 'Prix d\'achat',
                                        value: _hasPrixAchat,
                                        activeLabel: 'Renseigné',
                                        inactiveLabel: 'Non suivi',
                                        activeIcon: Icons.payments_rounded,
                                        inactiveIcon: Icons.money_off_csred_outlined,
                                        onChanged: (val) {
                                          setState(() => _hasPrixAchat = val);
                                          _updateMargin();
                                        },
                                      ),
                                      if (_hasPrixAchat) ...[
                                        const SizedBox(height: 8),
                                        TextFormField(
                                          controller: _prixAchatCtrl,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          decoration: InputDecoration(
                                            labelText: 'Montant prix d\'achat (${ApiClient.entrepriseMonnaie})',
                                            hintText: 'Ex: 3500',
                                            isDense: true,
                                          ),
                                        ),
                                      ],
                                    ],
                                  )
                                : Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 210,
                                        child: QuantisFieldToggle(
                                          title: 'Prix d\'achat',
                                          value: _hasPrixAchat,
                                          activeLabel: 'Renseigné',
                                          inactiveLabel: 'Non suivi',
                                          activeIcon: Icons.payments_rounded,
                                          inactiveIcon: Icons.money_off_csred_outlined,
                                          onChanged: (val) {
                                            setState(() => _hasPrixAchat = val);
                                            _updateMargin();
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: _hasPrixAchat
                                            ? TextFormField(
                                                controller: _prixAchatCtrl,
                                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                decoration: InputDecoration(
                                                  labelText: 'Montant prix d\'achat (${ApiClient.entrepriseMonnaie})',
                                                  hintText: 'Ex: 3500',
                                                  isDense: true,
                                                ),
                                              )
                                            : Text(
                                                'Champ désactivé (se remplira automatiquement lors d\'un achat fournisseur)',
                                                style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                                              ),
                                      ),
                                    ],
                                  ),
                            const Divider(height: 22),

                            // 2. TVA
                            isMobile
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      QuantisFieldToggle(
                                        title: 'TVA sur ce produit',
                                        value: _hasTva,
                                        activeLabel: 'TVA appliquée',
                                        inactiveLabel: 'Sans TVA (0%)',
                                        activeIcon: Icons.percent_rounded,
                                        inactiveIcon: Icons.block_outlined,
                                        activeIconColor: const Color(0xFFF97316),
                                        onChanged: (val) {
                                          setState(() {
                                            _hasTva = val;
                                            if (val && _parseNumber(_tvaCtrl.text) <= 0) {
                                              final def = ApiClient.tauxTvaDefaut > 0 ? ApiClient.tauxTvaDefaut : 18.0;
                                              _tvaCtrl.text = _formatTva(def);
                                            }
                                          });
                                        },
                                      ),
                                      if (_hasTva) ...[
                                        const SizedBox(height: 8),
                                        TextFormField(
                                          controller: _tvaCtrl,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          decoration: const InputDecoration(
                                            labelText: 'Taux TVA (%)',
                                            hintText: 'Ex: 18',
                                            suffixText: '%',
                                            isDense: true,
                                          ),
                                        ),
                                      ],
                                    ],
                                  )
                                : Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 210,
                                        child: QuantisFieldToggle(
                                          title: 'TVA sur ce produit',
                                          value: _hasTva,
                                          activeLabel: 'TVA appliquée',
                                          inactiveLabel: 'Sans TVA (0%)',
                                          activeIcon: Icons.percent_rounded,
                                          inactiveIcon: Icons.block_outlined,
                                          activeIconColor: const Color(0xFFF97316),
                                          onChanged: (val) {
                                            setState(() {
                                              _hasTva = val;
                                              if (val && _parseNumber(_tvaCtrl.text) <= 0) {
                                                final def = ApiClient.tauxTvaDefaut > 0 ? ApiClient.tauxTvaDefaut : 18.0;
                                                _tvaCtrl.text = _formatTva(def);
                                              }
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: _hasTva
                                            ? TextFormField(
                                                controller: _tvaCtrl,
                                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                decoration: const InputDecoration(
                                                  labelText: 'Taux TVA (%)',
                                                  hintText: 'Ex: 18',
                                                  suffixText: '%',
                                                  isDense: true,
                                                ),
                                              )
                                            : Text(
                                                'Produit vendu net sans TVA (0%)',
                                                style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                                              ),
                                      ),
                                    ],
                                  ),
                            const Divider(height: 22),

                            // 3. Alerte de stock bas
                            isMobile
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      QuantisFieldToggle(
                                        title: 'Alerte stock bas',
                                        value: _hasSeuilAlerte,
                                        activeLabel: 'Alerte active',
                                        inactiveLabel: 'Désactivée',
                                        activeIcon: Icons.notifications_active_rounded,
                                        inactiveIcon: Icons.notifications_off_outlined,
                                        activeIconColor: QuantisColors.warning,
                                        onChanged: (val) => setState(() => _hasSeuilAlerte = val),
                                      ),
                                      if (_hasSeuilAlerte) ...[
                                        const SizedBox(height: 8),
                                        TextFormField(
                                          controller: _seuilCtrl,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            labelText: 'Seuil d\'alerte (quantité min.)',
                                            hintText: 'Ex: 10',
                                            isDense: true,
                                          ),
                                        ),
                                      ],
                                    ],
                                  )
                                : Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 210,
                                        child: QuantisFieldToggle(
                                          title: 'Alerte stock bas',
                                          value: _hasSeuilAlerte,
                                          activeLabel: 'Alerte active',
                                          inactiveLabel: 'Désactivée',
                                          activeIcon: Icons.notifications_active_rounded,
                                          inactiveIcon: Icons.notifications_off_outlined,
                                          activeIconColor: QuantisColors.warning,
                                          onChanged: (val) => setState(() => _hasSeuilAlerte = val),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: _hasSeuilAlerte
                                            ? TextFormField(
                                                controller: _seuilCtrl,
                                                keyboardType: TextInputType.number,
                                                decoration: const InputDecoration(
                                                  labelText: 'Seuil d\'alerte (quantité min.)',
                                                  hintText: 'Ex: 10',
                                                  isDense: true,
                                                ),
                                              )
                                            : Text(
                                                'Aucune alerte de rupture générée pour cet article',
                                                style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                                              ),
                                      ),
                                    ],
                                  ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Calculateur de marge dynamique (uniquement si Prix d'achat activé et > 0)
                      if (_hasPrixAchat && _prixAchat > 0)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _marge >= 0
                                ? QuantisColors.success.withValues(alpha: 0.08)
                                : QuantisColors.error.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _marge >= 0
                                  ? QuantisColors.success.withValues(alpha: 0.3)
                                  : QuantisColors.error.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Marge estimée :', style: TextStyle(fontWeight: FontWeight.w600)),
                              Text(
                                '${_marge.toStringAsFixed(0)} ${ApiClient.entrepriseMonnaie}  (${_margePercent.toStringAsFixed(1)}%)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _marge >= 0 ? QuantisColors.success : QuantisColors.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 24),

                      // Section Variantes
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Variantes de produit', style: TextStyle(fontWeight: FontWeight.bold, color: QuantisColors.textSecondary)),
                          TextButton.icon(
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Ajouter une variante'),
                            onPressed: _addVariante,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (_variantes.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('Aucune variante définie (Standard)', style: TextStyle(fontStyle: FontStyle.italic, color: QuantisColors.textMuted)),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _variantes.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final v = entry.value;
                            return Chip(
                              label: Text('${v.attribut}: ${v.valeur}'),
                              deleteIcon: const Icon(Icons.cancel, size: 16),
                              onDeleted: () => setState(() => _variantes.removeAt(idx)),
                            );
                          }).toList(),
                        ),
                      
                      const SizedBox(height: 32),

                      // Boutons d'action
                      if (isMobile)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _saving ? null : () => Navigator.pop(context),
                                child: const Text('Annuler'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: QuantisColors.royalBlue,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: _saving ? null : _save,
                                child: _saving
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Text('Enregistrer'),
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: _saving ? null : () => Navigator.pop(context),
                              child: const Text('Annuler'),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: QuantisColors.royalBlue,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: _saving ? null : _save,
                              child: _saving
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Text('Enregistrer'),
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
