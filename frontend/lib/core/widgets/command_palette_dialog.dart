import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/quantis_theme.dart';
import '../network/api_client.dart';
import '../utils/permission_helper.dart';
import '../../features/stock/presentation/reapprovisionnement_dialog.dart';
import '../../features/stock/presentation/stock_screen.dart';
import '../../features/documents/presentation/document_detail_screen.dart';
import '../../features/documents/presentation/documents_screen.dart';
import '../../features/sales/presentation/pos_screen.dart';
import '../../features/sales/presentation/debiteurs_screen.dart';
import '../../features/produits/presentation/produits_screen.dart';
import '../../features/reports/presentation/exports_screen.dart';

/// Raccourci global & Palette de commande universelle (Ctrl+K / Cmd+K)
class CommandPaletteDialog extends StatefulWidget {
  final Function(int)? onNavigate;
  final Function()? onOpenAi;

  const CommandPaletteDialog({
    super.key,
    this.onNavigate,
    this.onOpenAi,
  });

  static Future<void> show(
    BuildContext context, {
    Function(int)? onNavigate,
    Function()? onOpenAi,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => CommandPaletteDialog(
        onNavigate: onNavigate,
        onOpenAi: onOpenAi,
      ),
    );
  }

  @override
  State<CommandPaletteDialog> createState() => _CommandPaletteDialogState();
}

class _CommandPaletteDialogState extends State<CommandPaletteDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isSearching = false;
  List<Map<String, dynamic>> _productResults = [];
  List<Map<String, dynamic>> _clientResults = [];
  List<Map<String, dynamic>> _docResults = [];

  List<Map<String, dynamic>> get _quickActions => [
    if (PermissionHelper.canAccessPos)
      {
        'title': 'Nouvelle Vente Caisse POS',
        'subtitle': 'Ouvrir l\'interface de caisse tactile et enregistrer un encaissement',
        'icon': Icons.point_of_sale_rounded,
        'color': QuantisColors.royalBlue,
        'type': 'action',
        'builder': () => const PosScreen(),
      },
    if (PermissionHelper.canAccessDocuments)
      {
        'title': 'Créer une Facture ou un Devis',
        'subtitle': 'Émettre un nouveau document commercial client',
        'icon': Icons.receipt_long_rounded,
        'color': QuantisColors.royalBlue,
        'type': 'action',
        'builder': () => const DocumentsScreen(),
      },
    if (PermissionHelper.canAccessProduits)
      {
        'title': 'Catalogue Articles & Produits',
        'subtitle': 'Créer un article, consulter les prix, marges, codes-barres et catégories',
        'icon': Icons.category_rounded,
        'color': Colors.indigo,
        'type': 'action',
        'builder': () => const ProduitsScreen(),
      },
    if (PermissionHelper.canAccessStock)
      {
        'title': 'Gestion du Stock & Mouvements',
        'subtitle': 'Consulter les niveaux et effectuer des mouvements de stock',
        'icon': Icons.inventory_2_rounded,
        'color': Colors.teal,
        'type': 'action',
        'builder': () => const StockScreen(),
      },
    if (PermissionHelper.canAccessStock)
      {
        'title': 'Suggestions de Réapprovisionnement',
        'subtitle': 'Calculer la vitesse de rotation et anticiper les ruptures de stock',
        'icon': Icons.auto_awesome,
        'color': QuantisColors.luxuryGold,
        'type': 'reappro',
      },
    if (PermissionHelper.canAccessExports)
      {
        'title': 'Exports Comptables & Fiscaux',
        'subtitle': 'Télécharger les journaux de ventes, caisses, clients et stock en Excel/CSV',
        'icon': Icons.table_view_rounded,
        'color': const Color(0xFF7C3AED),
        'type': 'action',
        'builder': () => const ExportsScreen(),
      },
    if (PermissionHelper.canAccessDebiteurs)
      {
        'title': 'Grand Livre des Débiteurs',
        'subtitle': 'Consulter les créances clients et créances à recouvrer',
        'icon': Icons.people_alt_rounded,
        'color': QuantisColors.warning,
        'type': 'action',
        'builder': () => const DebiteursScreen(),
      },
    if (PermissionHelper.canAccessAi)
      {
        'title': 'Assistant Intelligent Quantis IA',
        'subtitle': 'Interroger votre stock et piloter votre commerce en langage naturel',
        'icon': Icons.chat_bubble_outline,
        'color': QuantisColors.royalBlue,
        'type': 'ai',
      },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        _isSearching = false;
        _productResults = [];
        _clientResults = [];
        _docResults = [];
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final futures = await Future.wait([
        ApiClient.instance.get('/produits', queryParameters: {'search': q, 'size': 5}),
        ApiClient.instance.get('/clients', queryParameters: {'search': q, 'size': 5}),
        ApiClient.instance.get('/documents', queryParameters: {'search': q, 'size': 5}),
      ]);

      final prods = (futures[0].data['data']['content'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      final clients = (futures[1].data['data']['content'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      final docs = (futures[2].data['data']['content'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      if (mounted) {
        setState(() {
          _productResults = prods;
          _clientResults = clients;
          _docResults = docs;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchCtrl.text.trim();
    final hasResults = _productResults.isNotEmpty || _clientResults.isNotEmpty || _docResults.isNotEmpty;

    return Dialog(
      backgroundColor: Colors.transparent,
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.only(top: 80, left: 24, right: 24),
      child: Container(
        width: 680,
        constraints: const BoxConstraints(maxHeight: 580),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 28,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Barre de saisie
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: QuantisColors.royalBlue, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      focusNode: _focusNode,
                      decoration: const InputDecoration(
                        hintText: 'Rechercher un article, un client, une facture ou une action...',
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                        border: InputBorder.none,
                      ),
                      style: const TextStyle(fontSize: 15),
                      onChanged: _performSearch,
                    ),
                  ),
                  if (_isSearching)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (_searchCtrl.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                      onPressed: () {
                        _searchCtrl.clear();
                        _performSearch('');
                      },
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const Text('ESC', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                  ),
                ],
              ),
            ),

            // Contenu
            Flexible(
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (query.isNotEmpty) ...[
                    // Résultats Produits
                    if (_productResults.isNotEmpty) ...[
                      _buildSectionHeader('Articles & Produits (${_productResults.length})', Icons.inventory_2_outlined),
                      ..._productResults.map((p) => _buildProductItem(p)),
                      const SizedBox(height: 12),
                    ],

                    // Résultats Clients
                    if (_clientResults.isNotEmpty) ...[
                      _buildSectionHeader('Clients (${_clientResults.length})', Icons.people_outline),
                      ..._clientResults.map((c) => _buildClientItem(c)),
                      const SizedBox(height: 12),
                    ],

                    // Résultats Factures / Documents
                    if (_docResults.isNotEmpty) ...[
                      _buildSectionHeader('Factures & Devis (${_docResults.length})', Icons.receipt_long_outlined),
                      ..._docResults.map((d) => _buildDocItem(d)),
                      const SizedBox(height: 12),
                    ],

                    if (!hasResults && !_isSearching)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.search_off, size: 42, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              Text('Aucun résultat trouvé pour « $query »', style: const TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                  ] else ...[
                    _buildSectionHeader('Actions Rapides', Icons.bolt),
                    ..._quickActions.map((action) => _buildActionItem(action)),
                  ],
                ],
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  const Text('Quantis Stock Command Palette', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  const Spacer(),
                  Text('Raccourci : Ctrl + K', style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 6, top: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: QuantisColors.royalBlue),
          const SizedBox(width: 6),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: QuantisColors.royalBlue,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem(Map<String, dynamic> action) {
    return ListTile(
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (action['color'] as Color).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(action['icon'] as IconData, color: action['color'] as Color, size: 18),
      ),
      title: Text(action['title'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      subtitle: Text(action['subtitle'] as String, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      trailing: const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
      onTap: () {
        Navigator.pop(context);
        final type = action['type'];
        final builder = action['builder'] as Widget Function()?;
        if (builder != null) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => builder()));
        } else if (type == 'reappro') {
          showDialog(context: context, builder: (_) => const ReapprovisionnementDialog());
        } else if (type == 'ai' && widget.onOpenAi != null) {
          widget.onOpenAi!();
        }
      },
    );
  }

  Widget _buildProductItem(Map<String, dynamic> p) {
    final currency = NumberFormat.currency(locale: 'fr_FR', symbol: ApiClient.entrepriseMonnaie, decimalDigits: 0);
    final prix = (p['prixVenteTtc'] as num?)?.toDouble() ?? 0;

    return ListTile(
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.inventory_2, color: Colors.blue, size: 18),
      ),
      title: Text(p['nom'] ?? 'Produit', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      subtitle: Text('SKU: ${p['sku'] ?? 'N/A'} • Catégorie: ${p['categorieNom'] ?? 'Général'}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
      trailing: Text(currency.format(prix), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: QuantisColors.royalBlue)),
      onTap: () {
        Navigator.pop(context);
        if (widget.onNavigate != null) {
          widget.onNavigate!(1); // Produits
        }
      },
    );
  }

  Widget _buildClientItem(Map<String, dynamic> c) {
    final solde = (c['soldeCredit'] as num?)?.toDouble() ?? 0;
    return ListTile(
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.teal.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.person, color: Colors.teal, size: 18),
      ),
      title: Text(c['nom'] ?? 'Client', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      subtitle: Text('Tél: ${c['telephone'] ?? 'N/A'}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
      trailing: solde > 0
          ? Text('Dû: ${solde.toStringAsFixed(0)} ${ApiClient.entrepriseMonnaie}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: QuantisColors.error))
          : const Text('À jour', style: TextStyle(fontSize: 11, color: QuantisColors.success, fontWeight: FontWeight.bold)),
      onTap: () {
        Navigator.pop(context);
        if (widget.onNavigate != null) {
          widget.onNavigate!(4); // Clients
        }
      },
    );
  }

  Widget _buildDocItem(Map<String, dynamic> d) {
    final currency = NumberFormat.currency(locale: 'fr_FR', symbol: ApiClient.entrepriseMonnaie, decimalDigits: 0);
    final total = (d['totalTtc'] as num?)?.toDouble() ?? 0;
    final id = d['id'] as int?;

    return ListTile(
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.purple.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.receipt_long, color: Colors.purple, size: 18),
      ),
      title: Text('${d['type'] ?? 'DOC'} ${d['numero'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      subtitle: Text('${d['clientNom'] ?? 'Client'} • ${d['dateDocument'] ?? ''}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
      trailing: Text(currency.format(total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      onTap: () {
        Navigator.pop(context);
        if (id != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DocumentDetailScreen(documentId: id)),
          );
        }
      },
    );
  }
}
