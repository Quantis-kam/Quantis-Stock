import 'package:flutter/material.dart';
import '../../../core/utils/permission_helper.dart';
import '../../../core/theme/quantis_theme.dart';
import '../../produits/data/produit_service.dart';
import '../data/stock_service.dart';
import 'mouvement_rapide_dialog.dart';
import 'arret_stock_screen.dart';
import 'reapprovisionnement_dialog.dart';
import '../../produits/presentation/produits_screen.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final StockApiService _service = StockApiService();
  final ProduitService _produitService = ProduitService();

  List<DepotModel> _depots = [];
  int? _selectedDepotId;

  // Tab 1: Stock par Dépôt
  List<StockCourantModel> _stockItems = [];
  bool _stockLoading = true;
  String _stockSearchQuery = '';
  
  // Mode Inventaire
  bool _isInventoryMode = false;
  final Map<String, double> _physicalCounts = {}; // Key: "produitId-varianteId"

  // Tab 2: Historique
  List<MouvementModel> _mouvements = [];
  bool _mouvementsLoading = true;
  
  // Filtres Historique
  int? _filterDepotId;
  String? _filterType;
  int? _filterProduitId;
  DateTimeRange? _filterDateRange;
  List<ProduitModel> _filterProduits = [];

  // Tab 3: Alertes
  List<StockCourantModel> _alertes = [];
  bool _alertesLoading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        _loadTab(_tabCtrl.index);
      }
    });
    _initData();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    try {
      final depotsList = await _service.getDepots();
      final productsList = await _produitService.getProduits(size: 200);
      setState(() {
        _depots = depotsList;
        if (_depots.isNotEmpty) {
          _selectedDepotId = _depots.first.id;
        }
        _filterProduits = productsList.where((p) => p.actif).toList();
      });
      _loadTab(0);
    } catch (_) {}
  }

  void _loadTab(int index) {
    if (index == 0) {
      _loadStock();
    } else if (index == 1) {
      _loadMouvements();
    } else if (index == 2) {
      _loadAlertes();
    }
  }

  Future<void> _loadStock() async {
    if (_selectedDepotId == null) return;
    setState(() => _stockLoading = true);
    try {
      final items = await _service.getStockByDepot(_selectedDepotId!);
      setState(() {
        _stockItems = items;
        _stockLoading = false;
        // Initialiser les valeurs physiques par défaut si en mode inventaire
        if (_isInventoryMode) {
          for (var item in _stockItems) {
            final key = '${item.produitId}-${item.varianteId}';
            _physicalCounts[key] = item.quantite;
          }
        }
      });
    } catch (_) {
      setState(() => _stockLoading = false);
    }
  }

  Future<void> _loadMouvements() async {
    setState(() => _mouvementsLoading = true);
    try {
      String? startIso;
      String? endIso;
      if (_filterDateRange != null) {
        startIso = _filterDateRange!.start.toUtc().toIso8601String();
        // Fin de journée pour le end date
        endIso = _filterDateRange!.end.add(const Duration(hours: 23, minutes: 59, seconds: 59)).toUtc().toIso8601String();
      }

      final items = await _service.getMouvementsFiltered(
        depotId: _filterDepotId,
        type: _filterType,
        produitId: _filterProduitId,
        startDate: startIso,
        endDate: endIso,
      );
      setState(() {
        _mouvements = items;
        _mouvementsLoading = false;
      });
    } catch (_) {
      setState(() => _mouvementsLoading = false);
    }
  }

  Future<void> _loadAlertes() async {
    setState(() => _alertesLoading = true);
    try {
      final items = await _service.getAlertes();
      setState(() {
        _alertes = items;
        _alertesLoading = false;
      });
    } catch (_) {
      setState(() => _alertesLoading = false);
    }
  }

  void _startInventory() {
    setState(() {
      _isInventoryMode = true;
      _physicalCounts.clear();
      for (var item in _stockItems) {
        final key = '${item.produitId}-${item.varianteId}';
        _physicalCounts[key] = item.quantite;
      }
    });
  }

  void _cancelInventory() {
    setState(() {
      _isInventoryMode = false;
      _physicalCounts.clear();
    });
  }

  Future<void> _submitReconciliation() async {
    final countDiscrepancies = _stockItems.where((item) {
      final key = '${item.produitId}-${item.varianteId}';
      final val = _physicalCounts[key] ?? item.quantite;
      return val != item.quantite;
    }).length;

    if (countDiscrepancies == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun écart de stock constaté. Rapprochement non nécessaire.')),
      );
      setState(() => _isInventoryMode = false);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer l\'Inventaire'),
        content: Text(
          'Vous allez enregistrer un rapprochement pour $countDiscrepancies écarts constatés.\n'
          'Des mouvements d\'ajustement seront automatiquement générés.\nVoulez-vous continuer ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler', style: TextStyle(color: QuantisColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: QuantisColors.success),
            child: const Text('Valider le Rapprochement', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _stockLoading = true);

    try {
      final List<Map<String, dynamic>> itemsPayload = _stockItems.map((item) {
        final key = '${item.produitId}-${item.varianteId}';
        final val = _physicalCounts[key] ?? item.quantite;
        return {
          'produitId': item.produitId,
          if (item.varianteId != null) 'varianteId': item.varianteId,
          'quantitePhysique': val,
        };
      }).toList();

      final payload = {
        'depotId': _selectedDepotId,
        'items': itemsPayload,
        'reference': 'INV-${DateTime.now().millisecondsSinceEpoch}',
        'commentaire': 'Rapprochement d\'inventaire physique périodique',
      };

      await _service.reconcilierStock(payload);
      
      setState(() {
        _isInventoryMode = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inventaire et rapprochement enregistrés avec succès !'),
          backgroundColor: QuantisColors.success,
        ),
      );
      _loadStock();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du rapprochement : $e'),
          backgroundColor: QuantisColors.error,
        ),
      );
      setState(() => _stockLoading = false);
    }
  }

  Color _typeColor(String type) => switch (type) {
        'ENTREE' => QuantisColors.success,
        'SORTIE' => QuantisColors.error,
        'TRANSFERT' => QuantisColors.info,
        'AJUSTEMENT' => QuantisColors.warning,
        _ => QuantisColors.textMuted,
      };

  IconData _typeIcon(String type) => switch (type) {
        'ENTREE' => Icons.arrow_downward,
        'SORTIE' => Icons.arrow_upward,
        'TRANSFERT' => Icons.swap_horiz,
        'AJUSTEMENT' => Icons.tune,
        _ => Icons.help,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion de Stock'),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: QuantisColors.royalBlue,
          unselectedLabelColor: QuantisColors.textMuted,
          indicatorColor: QuantisColors.luxuryGold,
          tabs: [
            const Tab(icon: Icon(Icons.dashboard_outlined, size: 18), text: 'Stock par Dépôt'),
            const Tab(icon: Icon(Icons.history, size: 18), text: 'Historique Mouvements'),
            Tab(
              icon: Badge(
                label: Text(_alertes.length.toString()),
                isLabelVisible: _alertes.isNotEmpty,
                child: const Icon(Icons.warning_amber, size: 18),
              ),
              text: 'Alertes',
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.category_outlined),
            tooltip: 'Catalogue Articles (Créer / Modifier)',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProduitsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: QuantisColors.luxuryGold),
            tooltip: 'Suggestions intelligentes de réapprovisionnement',
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const ReapprovisionnementDialog(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined),
            tooltip: 'Arrêts & Snapshots de stock',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ArretStockScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadTab(_tabCtrl.index),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabCtrl,
        physics: const NeverScrollableScrollPhysics(), // Désactiver le swipe pour éviter de perdre le mode inventaire par accident
        children: [
          _buildStockTab(),
          _buildHistoriqueTab(),
          _buildAlertesTab(),
        ],
      ),
    );
  }

  // =================== TAB 1: STOCK PAR DEPOT ===================

  Widget _buildStockTab() {
    if (_depots.isEmpty) {
      return const Center(child: Text('Aucun dépôt configuré.'));
    }

    final filteredStock = _stockItems.where((item) {
      if (_stockSearchQuery.isEmpty) return true;
      final q = _stockSearchQuery.toLowerCase();
      final pName = item.produitNom?.toLowerCase() ?? '';
      final vName = item.varianteNom?.toLowerCase() ?? '';
      return pName.contains(q) || vName.contains(q);
    }).toList();

    final isMobile = MediaQuery.of(context).size.width < 700;

    return Column(
      children: [
        // Header de sélection / contrôle
        Container(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          color: Colors.white,
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<int>(
                      value: _selectedDepotId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Dépôt actif',
                        prefixIcon: Icon(Icons.warehouse),
                      ),
                      items: _depots.map((d) {
                        return DropdownMenuItem(value: d.id, child: Text(d.nom));
                      }).toList(),
                      onChanged: _isInventoryMode
                          ? null
                          : (val) {
                              setState(() {
                                _selectedDepotId = val;
                              });
                              _loadStock();
                            },
                    ),
                    if (!_isInventoryMode) ...[
                      const SizedBox(height: 10),
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'Rechercher un produit...',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (val) => setState(() => _stockSearchQuery = val),
                      ),
                    ],
                    const SizedBox(height: 10),
                    if (!_isInventoryMode)
                      Row(
                        children: [
                          if (PermissionHelper.hasAnyPermission(['ENTREE_STOCK', 'SORTIE_STOCK', 'TRANSFERT_STOCK']))
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final res = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => MouvementRapideDialog(
                                      depots: _depots,
                                      initialDepotId: _selectedDepotId,
                                    ),
                                  );
                                  if (res == true) {
                                    _loadStock();
                                  }
                                },
                                icon: const Icon(Icons.swap_horiz, size: 16),
                                label: const Text('Mouvement', overflow: TextOverflow.ellipsis),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: QuantisColors.royalBlue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                ),
                              ),
                            ),
                          if (PermissionHelper.hasAnyPermission(['ENTREE_STOCK', 'SORTIE_STOCK', 'TRANSFERT_STOCK']) &&
                              PermissionHelper.hasPermission('INVENTAIRE_PHYSIQUE'))
                            const SizedBox(width: 8),
                          if (PermissionHelper.hasPermission('INVENTAIRE_PHYSIQUE'))
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _startInventory,
                                icon: const Icon(Icons.checklist, size: 16),
                                label: const Text('Inventaire', overflow: TextOverflow.ellipsis),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: QuantisColors.luxuryGold,
                                  side: const BorderSide(color: QuantisColors.luxuryGold),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                ),
                              ),
                            ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _submitReconciliation,
                              icon: const Icon(Icons.save_outlined, size: 16),
                              label: const Text('Valider'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: QuantisColors.success,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextButton.icon(
                              onPressed: _cancelInventory,
                              icon: const Icon(Icons.cancel_outlined, size: 16),
                              label: const Text('Annuler'),
                              style: TextButton.styleFrom(foregroundColor: QuantisColors.error),
                            ),
                          ),
                        ],
                      ),
                  ],
                )
              : Row(
                  children: [
                    // Choix dépôt
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<int>(
                        value: _selectedDepotId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Dépôt actif',
                          prefixIcon: Icon(Icons.warehouse),
                        ),
                        items: _depots.map((d) {
                          return DropdownMenuItem(value: d.id, child: Text(d.nom));
                        }).toList(),
                        onChanged: _isInventoryMode
                            ? null
                            : (val) {
                                setState(() {
                                  _selectedDepotId = val;
                                });
                                _loadStock();
                              },
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Recherche produit (seulement si pas en inventaire)
                    if (!_isInventoryMode)
                      Expanded(
                        flex: 3,
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Rechercher un produit...',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (val) => setState(() => _stockSearchQuery = val),
                        ),
                      ),
                    
                    const SizedBox(width: 16),

                    // Actions
                    if (!_isInventoryMode) ...[
                      if (PermissionHelper.hasAnyPermission(['ENTREE_STOCK', 'SORTIE_STOCK', 'TRANSFERT_STOCK']))
                      ElevatedButton.icon(
                        onPressed: () async {
                          final res = await showDialog<bool>(
                            context: context,
                            builder: (_) => MouvementRapideDialog(
                              depots: _depots,
                              initialDepotId: _selectedDepotId,
                            ),
                          );
                          if (res == true) {
                            _loadStock();
                          }
                        },
                        icon: const Icon(Icons.swap_horiz, size: 18),
                        label: const Text('Mouvement Rapide'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: QuantisColors.royalBlue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (PermissionHelper.hasPermission('INVENTAIRE_PHYSIQUE'))
                      OutlinedButton.icon(
                        onPressed: _startInventory,
                        icon: const Icon(Icons.checklist, size: 18),
                        label: const Text('Faire Inventaire'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: QuantisColors.luxuryGold,
                          side: const BorderSide(color: QuantisColors.luxuryGold),
                        ),
                      ),
                    ] else ...[
                      ElevatedButton.icon(
                        onPressed: _submitReconciliation,
                        icon: const Icon(Icons.save_outlined, size: 18),
                        label: Text(isMobile ? 'Valider' : 'Valider l\'Inventaire'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: QuantisColors.success,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: _cancelInventory,
                        icon: const Icon(Icons.cancel_outlined, size: 18),
                        label: const Text('Annuler'),
                        style: TextButton.styleFrom(foregroundColor: QuantisColors.error),
                      ),
                    ]
                  ],
                ),
        ),

        // Bannière mode inventaire
        if (_isInventoryMode)
          Container(
            width: double.infinity,
            color: QuantisColors.warning.withValues(alpha: 0.1),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: const Row(
              children: [
                Icon(Icons.warning, color: QuantisColors.warning, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Mode Inventaire Physique Actif. Veuillez saisir la quantité réelle comptée pour chaque produit.',
                    style: TextStyle(fontWeight: FontWeight.w600, color: QuantisColors.textPrimary, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

        // Contenu
        Expanded(
          child: _stockLoading
              ? const Center(child: CircularProgressIndicator())
              : filteredStock.isEmpty
                  ? const Center(child: Text('Aucun stock trouvé pour ce dépôt.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredStock.length,
                      itemBuilder: (ctx, i) {
                        final item = filteredStock[i];
                        final key = '${item.produitId}-${item.varianteId}';
                        final double currentPhysVal = _physicalCounts[key] ?? item.quantite;
                        final double discrepancy = currentPhysVal - item.quantite;

                        if (isMobile) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: QuantisColors.border),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Ligne supérieure : Produit + Stock théorique
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.produitNom ?? '',
                                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                            ),
                                            if (item.varianteNom != null)
                                              Container(
                                                margin: const EdgeInsets.only(top: 4),
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: QuantisColors.royalBlue.withValues(alpha: 0.08),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  item.varianteNom!,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: QuantisColors.royalBlue,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: (item.isRupture
                                                  ? QuantisColors.error
                                                  : item.isAlerte
                                                      ? QuantisColors.warning
                                                      : QuantisColors.royalBlue)
                                              .withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: (item.isRupture
                                                    ? QuantisColors.error
                                                    : item.isAlerte
                                                        ? QuantisColors.warning
                                                        : QuantisColors.royalBlue)
                                                .withValues(alpha: 0.2),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            const Text(
                                              'Stock théorique',
                                              style: TextStyle(fontSize: 10, color: QuantisColors.textMuted, fontWeight: FontWeight.w500),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${item.quantite.toStringAsFixed(0)} unités',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: item.isRupture
                                                    ? QuantisColors.error
                                                    : item.isAlerte
                                                        ? QuantisColors.warning
                                                        : QuantisColors.textPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Badge alerte hors inventaire
                                  if (!_isInventoryMode && (item.isAlerte || item.isRupture)) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: (item.isRupture ? QuantisColors.error : QuantisColors.warning).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        item.isRupture ? 'Rupture' : 'Seuil bas',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: item.isRupture ? QuantisColors.error : QuantisColors.warning,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],

                                  // Ligne inférieure : Mode Inventaire (Saisie réelle + Écart)
                                  if (_isInventoryMode) ...[
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 10),
                                      child: Divider(height: 1, color: QuantisColors.border),
                                    ),
                                    Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: TextFormField(
                                            initialValue: item.quantite.toStringAsFixed(0),
                                            keyboardType: TextInputType.number,
                                            decoration: const InputDecoration(
                                              labelText: 'Quantité réelle',
                                              isDense: true,
                                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              border: OutlineInputBorder(),
                                            ),
                                            onChanged: (val) {
                                              final double? parsedVal = double.tryParse(val);
                                              if (parsedVal != null && parsedVal >= 0) {
                                                setState(() {
                                                  _physicalCounts[key] = parsedVal;
                                                });
                                              }
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          flex: 2,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: (discrepancy == 0
                                                      ? QuantisColors.border
                                                      : discrepancy > 0
                                                          ? QuantisColors.success
                                                          : QuantisColors.error)
                                                  .withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: (discrepancy == 0
                                                        ? QuantisColors.border
                                                        : discrepancy > 0
                                                            ? QuantisColors.success
                                                            : QuantisColors.error)
                                                    .withValues(alpha: 0.3),
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                const Text(
                                                  'Écart',
                                                  style: TextStyle(fontSize: 10, color: QuantisColors.textMuted),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  discrepancy == 0
                                                      ? 'Aucun'
                                                      : '${discrepancy > 0 ? "+" : ""}${discrepancy.toStringAsFixed(0)}',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                    color: discrepancy == 0
                                                        ? QuantisColors.textMuted
                                                        : discrepancy > 0
                                                            ? QuantisColors.success
                                                            : QuantisColors.error,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                // Produit info
                                Expanded(
                                  flex: 4,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.produitNom ?? '',
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                      ),
                                      if (item.varianteNom != null)
                                        Container(
                                          margin: const EdgeInsets.only(top: 4),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: QuantisColors.royalBlue.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            item.varianteNom!,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: QuantisColors.royalBlue,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),

                                // Stock Théorique / Actuel
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Stock théorique',
                                        style: TextStyle(fontSize: 11, color: QuantisColors.textMuted),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${item.quantite.toStringAsFixed(0)} unités',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: item.isRupture
                                              ? QuantisColors.error
                                              : item.isAlerte
                                                  ? QuantisColors.warning
                                                  : QuantisColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Mode Inventaire saisie
                                if (_isInventoryMode) ...[
                                  // Quantité Physique (TextField)
                                  SizedBox(
                                    width: 120,
                                    child: TextFormField(
                                      initialValue: item.quantite.toStringAsFixed(0),
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Quantité réelle',
                                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      ),
                                      onChanged: (val) {
                                        final double? parsedVal = double.tryParse(val);
                                        if (parsedVal != null && parsedVal >= 0) {
                                          setState(() {
                                            _physicalCounts[key] = parsedVal;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 16),

                                  // Ecart
                                  SizedBox(
                                    width: 100,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Écart', style: TextStyle(fontSize: 11, color: QuantisColors.textMuted)),
                                        const SizedBox(height: 2),
                                        Text(
                                          discrepancy == 0
                                              ? 'Aucun'
                                              : '${discrepancy > 0 ? "+" : ""}${discrepancy.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: discrepancy == 0
                                                ? QuantisColors.textMuted
                                                : discrepancy > 0
                                                    ? QuantisColors.success
                                                    : QuantisColors.error,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else ...[
                                  // Badge alerte
                                  if (item.isAlerte || item.isRupture)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: (item.isRupture ? QuantisColors.error : QuantisColors.warning).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        item.isRupture ? 'Rupture' : 'Seuil bas',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: item.isRupture ? QuantisColors.error : QuantisColors.warning,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                ]
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  // =================== TAB 2: HISTORIQUE MOUVEMENTS ===================

  Widget _buildHistoriqueTab() {
    return Column(
      children: [
        // Panneau de filtres
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: ExpansionTile(
            title: const Row(
              children: [
                Icon(Icons.filter_list, color: QuantisColors.royalBlue),
                SizedBox(width: 8),
                Text('Filtrer les mouvements de stock', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            childrenPadding: const EdgeInsets.all(16),
            children: [
              if (MediaQuery.of(context).size.width < 600) ...[
                DropdownButtonFormField<int>(
                  value: _filterDepotId,
                  decoration: const InputDecoration(labelText: 'Filtrer par Dépôt'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Tous les dépôts')),
                    ..._depots.map((d) => DropdownMenuItem(value: d.id, child: Text(d.nom))),
                  ],
                  onChanged: (val) => setState(() => _filterDepotId = val),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _filterType,
                  decoration: const InputDecoration(labelText: 'Filtrer par Type'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Tous les types')),
                    DropdownMenuItem(value: 'ENTREE', child: Text('Entrées')),
                    DropdownMenuItem(value: 'SORTIE', child: Text('Sorties')),
                    DropdownMenuItem(value: 'TRANSFERT', child: Text('Transferts')),
                    DropdownMenuItem(value: 'AJUSTEMENT', child: Text('Ajustements')),
                  ],
                  onChanged: (val) => setState(() => _filterType = val),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: _filterProduitId,
                  decoration: const InputDecoration(labelText: 'Filtrer par Produit'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Tous les produits')),
                    ..._filterProduits.map((p) => DropdownMenuItem(value: p.id, child: Text(p.nom))),
                  ],
                  onChanged: (val) => setState(() => _filterProduitId = val),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picker = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2025),
                      lastDate: DateTime(2030),
                      initialDateRange: _filterDateRange,
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: QuantisColors.royalBlue,
                              onPrimary: Colors.white,
                              surface: Colors.white,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picker != null) {
                      setState(() {
                        _filterDateRange = picker;
                      });
                    }
                  },
                  icon: const Icon(Icons.date_range),
                  label: Text(
                    _filterDateRange == null
                        ? 'Toutes les dates'
                        : '${_filterDateRange!.start.day}/${_filterDateRange!.start.month} au ${_filterDateRange!.end.day}/${_filterDateRange!.end.month}',
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    foregroundColor: QuantisColors.textPrimary,
                    side: BorderSide(color: Colors.grey.shade400),
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    // Dépôt
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _filterDepotId,
                        decoration: const InputDecoration(labelText: 'Filtrer par Dépôt'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Tous les dépôts')),
                          ..._depots.map((d) => DropdownMenuItem(value: d.id, child: Text(d.nom))),
                        ],
                        onChanged: (val) => setState(() => _filterDepotId = val),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Type
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _filterType,
                        decoration: const InputDecoration(labelText: 'Filtrer par Type'),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('Tous les types')),
                          DropdownMenuItem(value: 'ENTREE', child: Text('Entrées')),
                          DropdownMenuItem(value: 'SORTIE', child: Text('Sorties')),
                          DropdownMenuItem(value: 'TRANSFERT', child: Text('Transferts')),
                          DropdownMenuItem(value: 'AJUSTEMENT', child: Text('Ajustements')),
                        ],
                        onChanged: (val) => setState(() => _filterType = val),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    // Produit
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _filterProduitId,
                        decoration: const InputDecoration(labelText: 'Filtrer par Produit'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Tous les produits')),
                          ..._filterProduits.map((p) => DropdownMenuItem(value: p.id, child: Text(p.nom))),
                        ],
                        onChanged: (val) => setState(() => _filterProduitId = val),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Dates
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picker = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2025),
                            lastDate: DateTime(2030),
                            initialDateRange: _filterDateRange,
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: QuantisColors.royalBlue,
                                    onPrimary: Colors.white,
                                    surface: Colors.white,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picker != null) {
                            setState(() {
                              _filterDateRange = picker;
                            });
                          }
                        },
                        icon: const Icon(Icons.date_range),
                        label: Text(
                          _filterDateRange == null
                              ? 'Toutes les dates'
                              : '${_filterDateRange!.start.day}/${_filterDateRange!.start.month} au ${_filterDateRange!.end.day}/${_filterDateRange!.end.month}',
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          foregroundColor: QuantisColors.textPrimary,
                          side: BorderSide(color: Colors.grey.shade400),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _filterDepotId = null;
                        _filterType = null;
                        _filterProduitId = null;
                        _filterDateRange = null;
                      });
                      _loadMouvements();
                    },
                    child: const Text('Réinitialiser', style: TextStyle(color: QuantisColors.textMuted)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _loadMouvements,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: QuantisColors.royalBlue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Appliquer les filtres'),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Historique liste
        Expanded(
          child: _mouvementsLoading
              ? const Center(child: CircularProgressIndicator())
              : _mouvements.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history, size: 64, color: QuantisColors.textMuted),
                          SizedBox(height: 8),
                          Text('Aucun mouvement trouvé', style: TextStyle(color: QuantisColors.textMuted)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadMouvements,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _mouvements.length,
                        itemBuilder: (ctx, i) {
                          final m = _mouvements[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _typeColor(m.type).withValues(alpha: 0.1),
                                child: Icon(_typeIcon(m.type), color: _typeColor(m.type), size: 20),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      m.produitNom ?? 'Produit',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: QuantisColors.royalBlue.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: QuantisColors.royalBlue.withValues(alpha: 0.2)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.access_time_rounded, size: 12, color: QuantisColors.royalBlue),
                                        const SizedBox(width: 5),
                                        Text(
                                          m.dateHeureFormatted,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: QuantisColors.royalBlue,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _typeColor(m.type).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          m.typeLabel,
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _typeColor(m.type)),
                                        ),
                                      ),
                                      Text('Motif : ${m.motifLabel}', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                                      if (m.depotSourceNom != null || m.depotDestNom != null)
                                        Text(
                                          m.type == 'TRANSFERT'
                                              ? '• De: ${m.depotSourceNom} ➔ À: ${m.depotDestNom}'
                                              : m.type == 'SORTIE'
                                                  ? '• Dépôt: ${m.depotSourceNom}'
                                                  : '• Dépôt: ${m.depotDestNom}',
                                          style: const TextStyle(fontSize: 11, color: QuantisColors.textMuted),
                                        ),
                                    ],
                                  ),
                                  if (m.reference != null && m.reference!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'Réf: ${m.reference}',
                                        style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
                                      ),
                                    ),
                                  if (m.commentaire != null && m.commentaire!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        'Commentaire: ${m.commentaire}',
                                        style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${m.type == "SORTIE" ? "-" : m.type == "ENTREE" ? "+" : ""}${m.quantite.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      color: _typeColor(m.type),
                                    ),
                                  ),
                                  Text(
                                    m.type == "SORTIE" ? "Sortie" : (m.type == "ENTREE" ? "Entrée" : "Mvt"),
                                    style: TextStyle(fontSize: 10, color: _typeColor(m.type), fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  // =================== TAB 3: ALERTES & RUPTURES ===================

  Widget _buildAlertesTab() {
    if (_alertesLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_alertes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 64, color: QuantisColors.success.withValues(alpha: 0.5)),
            const SizedBox(height: 8),
            const Text('Aucune alerte de stock active !', style: TextStyle(color: QuantisColors.textMuted)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAlertes,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _alertes.length,
        itemBuilder: (ctx, i) {
          final a = _alertes[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: a.isRupture
                ? QuantisColors.error.withValues(alpha: 0.05)
                : QuantisColors.warning.withValues(alpha: 0.05),
            child: ListTile(
              leading: Icon(
                a.isRupture ? Icons.error_outline : Icons.warning_amber_outlined,
                color: a.isRupture ? QuantisColors.error : QuantisColors.warning,
                size: 28,
              ),
              title: Text(
                a.produitNom ?? '?',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text('Dépôt: ${a.depotNom ?? ""}', style: const TextStyle(fontSize: 12)),
                  if (a.varianteNom != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Variante: ${a.varianteNom!}',
                        style: const TextStyle(fontSize: 11, color: QuantisColors.royalBlue),
                      ),
                    ),
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${a.quantite.toStringAsFixed(0)} unités',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: a.isRupture ? QuantisColors.error : QuantisColors.warning,
                    ),
                  ),
                  Text(
                    'Seuil: ${a.seuilAlerte}',
                    style: const TextStyle(fontSize: 11, color: QuantisColors.textMuted),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
