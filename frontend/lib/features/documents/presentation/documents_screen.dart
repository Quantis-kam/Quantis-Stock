import 'package:flutter/material.dart';
import '../../../core/theme/quantis_theme.dart';
import '../data/document_models.dart';
import '../data/document_service.dart';
import 'document_detail_screen.dart';

/// Écran liste des documents commerciaux avec filtrage par type.
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DocumentService _service = DocumentService();

  final _types = ['FACTURE', 'DEVIS', 'BON_LIVRAISON', 'AVOIR'];
  final _labels = ['Factures', 'Devis', 'Bons de livraison', 'Avoirs'];

  List<DocumentModel> _documents = [];
  bool _loading = true;

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
        'DEVIS' => Icons.description,
        'BON_LIVRAISON' => Icons.local_shipping,
        'AVOIR' => Icons.assignment_return,
        _ => Icons.article,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: QuantisColors.royalBlue,
          unselectedLabelColor: QuantisColors.textMuted,
          indicatorColor: QuantisColors.luxuryGold,
          tabs: List.generate(_labels.length, (i) => Tab(
            icon: Icon(_typeIcon(_types[i]), size: 18),
            text: _labels[i],
          )),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Formulaire document — prochaine itération')),
          );
        },
        icon: const Icon(Icons.add),
        label: Text('Nouveau ${_labels[_tabController.index].replaceAll(RegExp(r's$'), '')}'),
        backgroundColor: QuantisColors.royalBlue,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _documents.isEmpty
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
                    itemCount: _documents.length,
                    itemBuilder: (_, i) {
                      final doc = _documents[i];
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
                                        color: _statutColor(doc.statut).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        doc.statutLabel,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: _statutColor(doc.statut),
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

                                // Montants
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
                                          Text(
                                            doc.isPayeIntegral ? 'Payée' : 'Reste: ${doc.soldeRestant.toStringAsFixed(0)} FCFA',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: doc.isPayeIntegral ? QuantisColors.success : QuantisColors.warning,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
