import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/permission_helper.dart';
import '../../../core/theme/quantis_theme.dart';
import '../../sales/presentation/pos_screen.dart';
import '../../tiers/presentation/debiteurs_screen.dart';
import '../data/document_models.dart';
import '../data/document_service.dart';
import 'document_detail_screen.dart';
import 'document_form_dialog.dart';
import 'paiement_facture_dialog.dart';
import 'solder_commande_dialog.dart';

/// Écran liste des documents commerciaux avec filtrage par type et accès POS.
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DocumentService _service = DocumentService();

  final _types = ['FACTURE', 'COMMANDE_CLIENT', 'DEVIS', 'BON_LIVRAISON', 'AVOIR'];
  final _labels = ['Factures', 'Commandes', 'Devis', 'Bons de livraison', 'Avoirs'];

  List<DocumentModel> _documents = [];
  bool _loading = true;
  bool _filterNonReglees = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _types.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) _load();
    });
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _documents = await _service.getDocuments(_types[_tabController.index]);
    } catch (_) {
      _documents = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  Color _statutColor(String statut) => switch (statut) {
        'BROUILLON' => QuantisColors.textMuted,
        'VALIDE' => QuantisColors.success,
        'ANNULE' => QuantisColors.error,
        _ => QuantisColors.textMuted,
      };

  IconData _typeIcon(String type) => switch (type) {
        'FACTURE' => Icons.receipt,
        'COMMANDE_CLIENT' => Icons.shopping_bag_outlined,
        'DEVIS' => Icons.description,
        'BON_LIVRAISON' => Icons.local_shipping,
        'AVOIR' => Icons.assignment_return,
        _ => Icons.article,
      };

  String _fabLabel(String type) => switch (type) {
        'FACTURE' => 'Nouvelle Facture',
        'COMMANDE_CLIENT' => 'Nouvelle Commande',
        'DEVIS' => 'Nouveau Devis',
        'BON_LIVRAISON' => 'Nouveau Bon Livraison',
        'AVOIR' => 'Nouvel Avoir',
        _ => 'Nouveau Document',
      };

  Future<void> _validerDocumentRapide(DocumentModel doc) async {
    try {
      await _service.valider(doc.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${doc.typeLabel} ${doc.numero} validé !'),
            backgroundColor: QuantisColors.success,
          ),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiClient.formatErrorMessage(e, fallback: 'Impossible de valider ce document.')),
            backgroundColor: QuantisColors.error,
          ),
        );
      }
    }
  }

  Future<void> _solderCommandeRapide(DocumentModel doc) async {
    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SolderCommandeDialog(commande: doc),
    );
    if (res == true) _load();
  }

  List<DocumentModel> get _displayedDocuments {
    if (_filterNonReglees && _types[_tabController.index] == 'FACTURE') {
      return _documents.where((d) => d.statut == 'VALIDE' && !d.isPayeIntegral).toList();
    }
    return _documents;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents Commerciaux'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          padding: EdgeInsets.zero,
          labelPadding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 16),
          labelColor: QuantisColors.royalBlue,
          unselectedLabelColor: QuantisColors.textMuted,
          indicatorColor: QuantisColors.luxuryGold,
          indicatorWeight: 3,
          tabs: List.generate(_labels.length, (i) => Tab(
            icon: Icon(_typeIcon(_types[i]), size: 18),
            text: isMobile && _types[i] == 'BON_LIVRAISON' ? 'Bons Livraison' : _labels[i],
          )),
        ),
        actions: [
          if (PermissionHelper.canAccessDebiteurs)
            isMobile
                ? IconButton(
                    icon: Icon(Icons.account_balance_wallet, color: Colors.amber.shade800),
                    tooltip: 'Crédits & Créances Clients',
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const DebiteursScreen()),
                      );
                      _load();
                    },
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const DebiteursScreen()),
                        );
                        _load();
                      },
                      icon: Icon(Icons.account_balance_wallet, size: 16, color: Colors.amber.shade900),
                      label: Text('Crédits Clients', style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.amber.shade400)),
                    ),
                  ),
          // Bouton Mode POS Rapide
          if (isMobile)
            IconButton(
              icon: const Icon(Icons.point_of_sale, color: QuantisColors.luxuryGold),
              tooltip: 'Caisse POS Comptoir',
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PosScreen()),
                );
                _load();
              },
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PosScreen()),
                  );
                  _load();
                },
                icon: const Icon(Icons.point_of_sale, size: 18),
                label: const Text('Caisse POS Comptoir'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: QuantisColors.luxuryGold,
                  foregroundColor: Colors.black87,
                  elevation: 1,
                ),
              ),
            ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: PermissionHelper.hasPermission('CREER_VENTE')
          ? FloatingActionButton.extended(
              onPressed: () async {
                final res = await showDialog<bool>(
                  context: context,
                  builder: (_) => DocumentFormDialog(
                    initialType: _types[_tabController.index],
                  ),
                );
                if (res == true) {
                  _load();
                }
              },
              icon: const Icon(Icons.add),
              label: Text(_fabLabel(_types[_tabController.index])),
              backgroundColor: QuantisColors.royalBlue,
              foregroundColor: Colors.white,
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Filtre Factures non réglées
                if (_types[_tabController.index] == 'FACTURE')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: Colors.white,
                    child: Row(
                      children: [
                        FilterChip(
                          avatar: Icon(
                            _filterNonReglees ? Icons.filter_alt : Icons.filter_alt_outlined,
                            size: 16,
                            color: _filterNonReglees ? Colors.white : QuantisColors.warning,
                          ),
                          label: const Text('Factures Non Soldées / À Crédit'),
                          selected: _filterNonReglees,
                          selectedColor: QuantisColors.warning,
                          labelStyle: TextStyle(
                            color: _filterNonReglees ? Colors.white : Colors.black87,
                            fontWeight: _filterNonReglees ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (val) => setState(() => _filterNonReglees = val),
                        ),
                        const Spacer(),
                        Text(
                          '${_displayedDocuments.length} document(s)',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),

                Expanded(
                  child: _displayedDocuments.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_typeIcon(_types[_tabController.index]),
                                  size: 64, color: QuantisColors.textMuted),
                              const SizedBox(height: 8),
                              Text('Aucun ${_labels[_tabController.index].toLowerCase()}',
                                  style: const TextStyle(color: QuantisColors.textMuted)),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _displayedDocuments.length,
                            itemBuilder: (_, i) {
                              final doc = _displayedDocuments[i];
                              final bool hasSolde = doc.type == 'FACTURE' && doc.statut == 'VALIDE' && !doc.isPayeIntegral;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => DocumentDetailScreen(documentId: doc.id!),
                                      ),
                                    );
                                    _load();
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Header: numéro + statut
                                        Row(
                                          children: [
                                            Icon(_typeIcon(doc.type), size: 20, color: QuantisColors.royalBlue),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(doc.numero,
                                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: (doc.isCommandeSoldee
                                                        ? QuantisColors.success
                                                        : (doc.type == 'FACTURE' && doc.statut == 'VALIDE' && doc.isPayeIntegral
                                                            ? QuantisColors.success
                                                            : (hasSolde ? QuantisColors.warning : _statutColor(doc.statut))))
                                                    .withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                doc.isCommandeSoldee
                                                    ? '✓ Soldée'
                                                    : (doc.type == 'FACTURE' && doc.statut == 'VALIDE'
                                                        ? (doc.isPayeIntegral ? '✓ Soldée' : 'À crédit')
                                                        : doc.statutLabel),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: doc.isCommandeSoldee
                                                      ? QuantisColors.success
                                                      : (doc.type == 'FACTURE' && doc.statut == 'VALIDE' && doc.isPayeIntegral
                                                          ? QuantisColors.success
                                                          : (hasSolde ? QuantisColors.warning : _statutColor(doc.statut))),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),

                                        // Client
                                        if (doc.clientNom != null)
                                          Text(doc.clientNom!, style: const TextStyle(fontSize: 13, color: QuantisColors.textSecondary)),

                                        const SizedBox(height: 8),

                                        // Montants & Actions
                                        Row(
                                          children: [
                                            if (doc.dateDocument != null)
                                              Text(doc.dateDocument!, style: const TextStyle(fontSize: 12, color: QuantisColors.textMuted)),
                                            const Spacer(),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  '${doc.totalTtc.toStringAsFixed(0)} FCFA',
                                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                                ),
                                                if (doc.type == 'FACTURE' && doc.statut == 'VALIDE')
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        doc.isPayeIntegral ? 'Payée intégralement' : 'Reste: ${doc.soldeRestant.toStringAsFixed(0)} ${ApiClient.entrepriseMonnaie}',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: doc.isPayeIntegral ? QuantisColors.success : QuantisColors.error,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                      if (hasSolde && PermissionHelper.hasPermission('PAIEMENT_CLIENT')) ...[
                                                        const SizedBox(width: 8),
                                                        InkWell(
                                                          onTap: () async {
                                                            final res = await showDialog<bool>(
                                                              context: context,
                                                              builder: (_) => PaiementFactureDialog(document: doc),
                                                            );
                                                            if (res == true) _load();
                                                          },
                                                          child: Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                            decoration: BoxDecoration(
                                                              color: QuantisColors.success,
                                                              borderRadius: BorderRadius.circular(6),
                                                            ),
                                                            child: const Text(
                                                              'Encaisser',
                                                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),

                                        // Actions directes claires pour Commandes clients & Brouillons
                                        if (doc.canSolderCommande &&
                                            (PermissionHelper.hasPermission('PAIEMENT_CLIENT') ||
                                                PermissionHelper.hasPermission('CONVERTIR_VENTE'))) ...[
                                          const SizedBox(height: 10),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 6,
                                            children: [
                                              ElevatedButton.icon(
                                                onPressed: () => _solderCommandeRapide(doc),
                                                icon: const Icon(Icons.task_alt_rounded, size: 15),
                                                label: const Text('Valider & Solder', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: QuantisColors.success,
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                  minimumSize: Size.zero,
                                                ),
                                              ),
                                              if (doc.canValidate && PermissionHelper.hasPermission('CONVERTIR_VENTE'))
                                                OutlinedButton.icon(
                                                  onPressed: () => _validerDocumentRapide(doc),
                                                  icon: const Icon(Icons.check, size: 15),
                                                  label: const Text('Confirmer seule', style: TextStyle(fontSize: 12)),
                                                  style: OutlinedButton.styleFrom(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                    minimumSize: Size.zero,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ] else if (doc.canValidate &&
                                            doc.type != 'COMMANDE_CLIENT' &&
                                            PermissionHelper.hasPermission('CONVERTIR_VENTE')) ...[
                                          const SizedBox(height: 10),
                                          OutlinedButton.icon(
                                            onPressed: () => _validerDocumentRapide(doc),
                                            icon: const Icon(Icons.check_circle_outline, size: 15, color: QuantisColors.success),
                                            label: const Text('Valider ce document', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: QuantisColors.success)),
                                            style: OutlinedButton.styleFrom(
                                              side: const BorderSide(color: QuantisColors.success),
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              minimumSize: Size.zero,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}
