import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/quantis_theme.dart';

/// Formulaire de création de document commercial (Devis, Facture, Bon de livraison, Avoir)
class DocumentFormDialog extends StatefulWidget {
  final String initialType;

  const DocumentFormDialog({
    super.key,
    this.initialType = 'FACTURE',
  });

  @override
  State<DocumentFormDialog> createState() => _DocumentFormDialogState();
}

class _DocumentFormDialogState extends State<DocumentFormDialog> {
  final ApiClient _api = ApiClient();
  final _formKey = GlobalKey<FormState>();

  late String _type;
  int? _clientId;
  int? _depotId;
  DateTime _dateDocument = DateTime.now();
  DateTime? _dateEcheance;
  final _notesCtrl = TextEditingController();

  List<dynamic> _clients = [];
  List<dynamic> _depots = [];
  List<dynamic> _produits = [];
  bool _loading = true;
  bool _saving = false;

  final List<Map<String, dynamic>> _lignes = [];

  final _types = [
    {'code': 'FACTURE', 'label': 'Facture'},
    {'code': 'COMMANDE_CLIENT', 'label': 'Commande'},
    {'code': 'DEVIS', 'label': 'Devis'},
    {'code': 'BON_LIVRAISON', 'label': 'Bon de Livraison'},
    {'code': 'AVOIR', 'label': 'Avoir'},
  ];

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _dateEcheance = DateTime.now().add(const Duration(days: 30));
    _ajouterLigne();
    _loadData();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final resClients = await _api.get('/clients?size=100');
      final resDepots = await _api.get('/stock/depots');
      final resProduits = await _api.get('/products?size=100');

      if (mounted) {
        setState(() {
          _clients = resClients.data['data']?['content'] ?? [];
          _depots = resDepots.data['data'] ?? [];
          _produits = resProduits.data['data']?['content'] ?? [];

          if (_depots.isNotEmpty && _depotId == null) {
            _depotId = _depots.first['id'];
          }
          if (_clients.isNotEmpty && _clientId == null) {
            _clientId = _clients.first['id'];
          }
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement formulaire document: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _ajouterLigne() {
    setState(() {
      _lignes.add({
        'produitId': null,
        'designation': '',
        'quantite': 1.0,
        'prixUnitaire': 0.0,
        'tauxTva': 0.0,
      });
    });
  }

  void _supprimerLigne(int index) {
    if (_lignes.length > 1) {
      setState(() => _lignes.removeAt(index));
    }
  }

  double get _totalHt {
    double total = 0;
    for (final l in _lignes) {
      final qte = (l['quantite'] as num?)?.toDouble() ?? 0;
      final pu = (l['prixUnitaire'] as num?)?.toDouble() ?? 0;
      total += (qte * pu);
    }
    return total;
  }

  double get _totalTva {
    double total = 0;
    for (final l in _lignes) {
      final qte = (l['quantite'] as num?)?.toDouble() ?? 0;
      final pu = (l['prixUnitaire'] as num?)?.toDouble() ?? 0;
      final tva = (l['tauxTva'] as num?)?.toDouble() ?? 0;
      total += (qte * pu * (tva / 100));
    }
    return total;
  }

  double get _totalTtc => _totalHt + _totalTva;

  Future<void> _soumettre() async {
    if (!_formKey.currentState!.validate()) return;
    if (_clientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un client'), backgroundColor: QuantisColors.warning),
      );
      return;
    }

    final validLignes = _lignes.where((l) => l['produitId'] != null && (l['quantite'] as num) > 0).toList();
    if (validLignes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez ajouter au moins un produit valide'), backgroundColor: QuantisColors.warning),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final payload = {
        'type': _type,
        'clientId': _clientId,
        'depotId': _depotId,
        'dateDocument': _dateDocument.toIso8601String().substring(0, 10),
        'dateEcheance': _dateEcheance?.toIso8601String().substring(0, 10),
        'notes': _notesCtrl.text.trim(),
        'lignes': validLignes.map((l) => {
          'produitId': l['produitId'],
          'designation': l['designation'],
          'quantite': l['quantite'],
          'prixUnitaire': l['prixUnitaire'],
          'tauxTva': l['tauxTva'],
        }).toList(),
      };

      await _api.post('/documents', data: payload);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: QuantisColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 650;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 24, vertical: isMobile ? 12 : 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: isMobile ? double.infinity : 750,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        padding: EdgeInsets.all(isMobile ? 14 : 24),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Header
                    Row(
                      children: [
                        const Icon(Icons.note_add, color: QuantisColors.royalBlue, size: 24),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Nouveau Document',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                    const Divider(height: 16),

                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Type de Document
                            const Text('Type de Document :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 8),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _types.map((t) {
                                  final isSel = _type == t['code'];
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text(t['label']!),
                                      selected: isSel,
                                      selectedColor: QuantisColors.royalBlue,
                                      labelStyle: TextStyle(
                                        color: isSel ? Colors.white : Colors.black87,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                      onSelected: (_) => setState(() => _type = t['code']!),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Client & Dépôt
                            if (isMobile) ...[
                              DropdownButtonFormField<int>(
                                value: _clientId,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Client *',
                                  prefixIcon: Icon(Icons.person),
                                ),
                                items: _clients.map((c) {
                                  return DropdownMenuItem<int>(
                                    value: c['id'] as int,
                                    child: Text(c['nom'] ?? 'Client'),
                                  );
                                }).toList(),
                                onChanged: (val) => setState(() => _clientId = val),
                                validator: (val) => val == null ? 'Client requis' : null,
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<int>(
                                value: _depotId,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Dépôt',
                                  prefixIcon: Icon(Icons.warehouse),
                                ),
                                items: _depots.map((d) {
                                  return DropdownMenuItem<int>(
                                    value: d['id'] as int,
                                    child: Text(d['nom'] ?? 'Dépôt'),
                                  );
                                }).toList(),
                                onChanged: (val) => setState(() => _depotId = val),
                              ),
                            ] else ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<int>(
                                      value: _clientId,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        labelText: 'Client *',
                                        prefixIcon: Icon(Icons.person),
                                      ),
                                      items: _clients.map((c) {
                                        return DropdownMenuItem<int>(
                                          value: c['id'] as int,
                                          child: Text(c['nom'] ?? 'Client'),
                                        );
                                      }).toList(),
                                      onChanged: (val) => setState(() => _clientId = val),
                                      validator: (val) => val == null ? 'Client requis' : null,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: DropdownButtonFormField<int>(
                                      value: _depotId,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        labelText: 'Dépôt',
                                        prefixIcon: Icon(Icons.warehouse),
                                      ),
                                      items: _depots.map((d) {
                                        return DropdownMenuItem<int>(
                                          value: d['id'] as int,
                                          child: Text(d['nom'] ?? 'Dépôt'),
                                        );
                                      }).toList(),
                                      onChanged: (val) => setState(() => _depotId = val),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 16),

                            // Dates
                            if (isMobile) ...[
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.calendar_today, color: QuantisColors.royalBlue),
                                title: const Text('Date Document', style: TextStyle(fontSize: 12)),
                                subtitle: Text(_dateDocument.toIso8601String().substring(0, 10),
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                                onTap: () async {
                                  final d = await showDatePicker(
                                    context: context,
                                    initialDate: _dateDocument,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2035),
                                  );
                                  if (d != null) setState(() => _dateDocument = d);
                                },
                              ),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.event, color: QuantisColors.warning),
                                title: const Text('Date d\'Échéance', style: TextStyle(fontSize: 12)),
                                subtitle: Text(
                                    _dateEcheance != null
                                        ? _dateEcheance!.toIso8601String().substring(0, 10)
                                        : 'Aucune',
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                                onTap: () async {
                                  final d = await showDatePicker(
                                    context: context,
                                    initialDate: _dateEcheance ?? DateTime.now().add(const Duration(days: 30)),
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime(2035),
                                  );
                                  if (d != null) setState(() => _dateEcheance = d);
                                },
                              ),
                            ] else ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(Icons.calendar_today, color: QuantisColors.royalBlue),
                                      title: const Text('Date Document', style: TextStyle(fontSize: 12)),
                                      subtitle: Text(_dateDocument.toIso8601String().substring(0, 10),
                                          style: const TextStyle(fontWeight: FontWeight.bold)),
                                      onTap: () async {
                                        final d = await showDatePicker(
                                          context: context,
                                          initialDate: _dateDocument,
                                          firstDate: DateTime(2020),
                                          lastDate: DateTime(2035),
                                        );
                                        if (d != null) setState(() => _dateDocument = d);
                                      },
                                    ),
                                  ),
                                  Expanded(
                                    child: ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(Icons.event, color: QuantisColors.warning),
                                      title: const Text('Date d\'Échéance', style: TextStyle(fontSize: 12)),
                                      subtitle: Text(
                                          _dateEcheance != null
                                              ? _dateEcheance!.toIso8601String().substring(0, 10)
                                              : 'Aucune',
                                          style: const TextStyle(fontWeight: FontWeight.bold)),
                                      onTap: () async {
                                        final d = await showDatePicker(
                                          context: context,
                                          initialDate: _dateEcheance ?? DateTime.now().add(const Duration(days: 30)),
                                          firstDate: DateTime.now(),
                                          lastDate: DateTime(2035),
                                        );
                                        if (d != null) setState(() => _dateEcheance = d);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const Divider(height: 24),

                            // Lignes d'articles
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Articles / Prestations',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                TextButton.icon(
                                  onPressed: _ajouterLigne,
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Ajouter une ligne'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            ..._lignes.asMap().entries.map((entry) {
                              final i = entry.key;
                              final l = entry.value;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: isMobile
                                    ? Column(
                                        children: [
                                          DropdownButtonFormField<int>(
                                            value: l['produitId'],
                                            isExpanded: true,
                                            decoration: const InputDecoration(
                                              labelText: 'Article',
                                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            ),
                                            items: _produits.map((p) {
                                              return DropdownMenuItem<int>(
                                                value: p['id'] as int,
                                                child: Text('${p['nom']} (${p['prixVente']} F)'),
                                              );
                                            }).toList(),
                                            onChanged: (val) {
                                              setState(() {
                                                l['produitId'] = val;
                                                final p = _produits.firstWhere((prod) => prod['id'] == val, orElse: () => null);
                                                if (p != null) {
                                                  l['designation'] = p['nom'];
                                                  l['prixUnitaire'] = (p['prixVente'] as num).toDouble();
                                                  l['tauxTva'] = (p['tauxTva'] as num?)?.toDouble() ?? 0.0;
                                                }
                                              });
                                            },
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Expanded(
                                                flex: 2,
                                                child: TextFormField(
                                                  initialValue: l['quantite'].toString(),
                                                  keyboardType: TextInputType.number,
                                                  decoration: const InputDecoration(
                                                    labelText: 'Qté',
                                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                  ),
                                                  onChanged: (val) {
                                                    setState(() => l['quantite'] = double.tryParse(val) ?? 1.0);
                                                  },
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                flex: 3,
                                                child: TextFormField(
                                                  key: ValueKey('pu_${l['produitId']}_$i'),
                                                  initialValue: l['prixUnitaire'].toString(),
                                                  keyboardType: TextInputType.number,
                                                  decoration: const InputDecoration(
                                                    labelText: 'P.U. (FCFA)',
                                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                  ),
                                                  onChanged: (val) {
                                                    setState(() => l['prixUnitaire'] = double.tryParse(val) ?? 0.0);
                                                  },
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete_outline, color: QuantisColors.error),
                                                onPressed: () => _supprimerLigne(i),
                                              ),
                                            ],
                                          ),
                                        ],
                                      )
                                    : Row(
                                        children: [
                                          Expanded(
                                            flex: 5,
                                            child: DropdownButtonFormField<int>(
                                              value: l['produitId'],
                                              isExpanded: true,
                                              decoration: const InputDecoration(
                                                labelText: 'Article',
                                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              ),
                                              items: _produits.map((p) {
                                                return DropdownMenuItem<int>(
                                                  value: p['id'] as int,
                                                  child: Text('${p['nom']} (${p['prixVente']} F)'),
                                                );
                                              }).toList(),
                                              onChanged: (val) {
                                                setState(() {
                                                  l['produitId'] = val;
                                                  final p = _produits.firstWhere((prod) => prod['id'] == val, orElse: () => null);
                                                  if (p != null) {
                                                    l['designation'] = p['nom'];
                                                    l['prixUnitaire'] = (p['prixVente'] as num).toDouble();
                                                    l['tauxTva'] = (p['tauxTva'] as num?)?.toDouble() ?? 0.0;
                                                  }
                                                });
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            flex: 2,
                                            child: TextFormField(
                                              initialValue: l['quantite'].toString(),
                                              keyboardType: TextInputType.number,
                                              decoration: const InputDecoration(
                                                labelText: 'Qté',
                                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                              ),
                                              onChanged: (val) {
                                                setState(() => l['quantite'] = double.tryParse(val) ?? 1.0);
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            flex: 3,
                                            child: TextFormField(
                                              key: ValueKey('pu_${l['produitId']}_$i'),
                                              initialValue: l['prixUnitaire'].toString(),
                                              keyboardType: TextInputType.number,
                                              decoration: const InputDecoration(
                                                labelText: 'P.U. (FCFA)',
                                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                              ),
                                              onChanged: (val) {
                                                setState(() => l['prixUnitaire'] = double.tryParse(val) ?? 0.0);
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, color: QuantisColors.error),
                                            onPressed: () => _supprimerLigne(i),
                                          ),
                                        ],
                                      ),
                              );
                            }),

                            const Divider(height: 24),

                            // Notes
                            TextField(
                              controller: _notesCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Notes / Conditions particulières',
                                prefixIcon: Icon(Icons.note_alt_outlined),
                              ),
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Totaux et Boutons
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: isMobile
                          ? Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('HT: ${_totalHt.toStringAsFixed(0)} F', style: const TextStyle(fontSize: 11)),
                                        Text('TVA: ${_totalTva.toStringAsFixed(0)} F', style: const TextStyle(fontSize: 11)),
                                      ],
                                    ),
                                    Text('TOTAL: ${_totalTtc.toStringAsFixed(0)} FCFA',
                                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: QuantisColors.royalBlue)),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    OutlinedButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Annuler'),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: _saving ? null : _soumettre,
                                        icon: _saving
                                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                            : const Icon(Icons.save, size: 16),
                                        label: const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.bold)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: QuantisColors.royalBlue,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Total HT: ${_totalHt.toStringAsFixed(0)} FCFA', style: const TextStyle(fontSize: 12)),
                                    Text('TVA: ${_totalTva.toStringAsFixed(0)} FCFA', style: const TextStyle(fontSize: 12)),
                                    Text('TOTAL TTC: ${_totalTtc.toStringAsFixed(0)} FCFA',
                                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: QuantisColors.royalBlue)),
                                  ],
                                ),
                                Row(
                                  children: [
                                    OutlinedButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Annuler'),
                                    ),
                                    const SizedBox(width: 12),
                                    ElevatedButton.icon(
                                      onPressed: _saving ? null : _soumettre,
                                      icon: _saving
                                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                          : const Icon(Icons.save, size: 18),
                                      label: const Text('Enregistrer le document'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: QuantisColors.royalBlue,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
