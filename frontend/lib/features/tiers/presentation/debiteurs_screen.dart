import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/quantis_theme.dart';
import '../data/tiers_models.dart';
import '../data/tiers_service.dart';
import '../../documents/data/document_models.dart';
import '../../documents/presentation/paiement_facture_dialog.dart';

/// Écran dédié à la gestion des Débiteurs & Créances Clients
class DebiteursScreen extends StatefulWidget {
  const DebiteursScreen({super.key});

  @override
  State<DebiteursScreen> createState() => _DebiteursScreenState();
}

class _DebiteursScreenState extends State<DebiteursScreen> {
  final TiersService _tiersService = TiersService();
  final ApiClient _api = ApiClient();

  List<ClientModel> _debiteurs = [];
  bool _loading = true;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  double _totalCreances = 0.0;
  int _nbDebiteurs = 0;

  @override
  void initState() {
    super.initState();
    _loadDebiteurs();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDebiteurs() async {
    setState(() => _loading = true);
    try {
      final clients = await _tiersService.getClients();
      final debiteurs = clients.where((c) => c.soldeCredit > 0).toList();
      debiteurs.sort((a, b) => b.soldeCredit.compareTo(a.soldeCredit));

      double total = 0.0;
      for (var d in debiteurs) {
        total += d.soldeCredit;
      }

      if (mounted) {
        setState(() {
          _debiteurs = debiteurs;
          _totalCreances = total;
          _nbDebiteurs = debiteurs.length;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement débiteurs: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _encaisserClient(ClientModel client) async {
    // Récupérer la première facture impayée du client ou afficher le dialogue
    try {
      final res = await _api.get('/documents?clientId=${client.id}&type=FACTURE&size=50');
      final docs = (res.data['data']?['content'] as List?)
              ?.map((e) => DocumentModel.fromJson(e))
              .where((d) => d.statut == 'VALIDE' && !d.isPayeIntegral)
              .toList() ?? [];

      if (docs.isNotEmpty && mounted) {
        final ok = await showDialog<bool>(
          context: context,
          builder: (_) => PaiementFactureDialog(document: docs.first),
        );
        if (ok == true) _loadDebiteurs();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Aucune facture spécifique en attente pour ${client.nom}.'),
            backgroundColor: QuantisColors.info,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: QuantisColors.error),
        );
      }
    }
  }

  void _relancerClient(ClientModel client) {
    final msg = "Bonjour ${client.nom}, sauf erreur de notre part, votre compte présente un solde restant dû de ${client.soldeCredit.toStringAsFixed(0)} ${ApiClient.entrepriseMonnaie} auprès de ${ApiClient.entrepriseNom}. Merci de bien vouloir régulariser votre situation.";
    Clipboard.setData(ClipboardData(text: msg));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Message de relance copié pour ${client.nom} (WhatsApp / SMS) !'),
        backgroundColor: QuantisColors.success,
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _debiteurs.where((c) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return c.nom.toLowerCase().contains(q) || (c.telephone?.contains(q) ?? false);
    }).toList();

    final isMobile = MediaQuery.of(context).size.width < 750;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Débiteurs & Créances', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDebiteurs,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 12.0 : 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // KPI Cards
                  if (isMobile)
                    Column(
                      children: [
                        _buildSummaryCard(
                          'Total Créances à Recouvrer',
                          '${_totalCreances.toStringAsFixed(0)} ${ApiClient.entrepriseMonnaie}',
                          Icons.account_balance_wallet,
                          QuantisColors.error,
                          'Montant global dû par les clients',
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _buildSummaryCard(
                                'Clients Débiteurs',
                                '$_nbDebiteurs clients',
                                Icons.people_alt,
                                Colors.amber.shade900,
                                'Comptes débiteurs',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildSummaryCard(
                                'Créance Moyenne',
                                _nbDebiteurs > 0
                                    ? '${(_totalCreances / _nbDebiteurs).toStringAsFixed(0)} ${ApiClient.entrepriseMonnaie}'
                                    : '0 ${ApiClient.entrepriseMonnaie}',
                                Icons.analytics,
                                QuantisColors.royalBlue,
                                'Par client',
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard(
                            'Total Créances à Recouvrer',
                            '${_totalCreances.toStringAsFixed(0)} ${ApiClient.entrepriseMonnaie}',
                            Icons.account_balance_wallet,
                            QuantisColors.error,
                            'Montant global dû par les clients',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildSummaryCard(
                            'Clients Débiteurs',
                            '$_nbDebiteurs clients',
                            Icons.people_alt,
                            Colors.amber.shade900,
                            'Comptes clients à solde débiteur',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildSummaryCard(
                            'Créance Moyenne',
                            _nbDebiteurs > 0
                                ? '${(_totalCreances / _nbDebiteurs).toStringAsFixed(0)} ${ApiClient.entrepriseMonnaie}'
                                : '0 ${ApiClient.entrepriseMonnaie}',
                            Icons.analytics,
                            QuantisColors.royalBlue,
                            'Moyenne par client débiteur',
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 20),

                  // Barre de Recherche & Filtre
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            decoration: InputDecoration(
                              hintText: 'Rechercher un client débiteur...',
                              prefixIcon: const Icon(Icons.search, color: QuantisColors.royalBlue),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onChanged: (val) => setState(() => _searchQuery = val),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tableau ou Liste Mobile des Débiteurs
                  if (filtered.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.check_circle_outline, size: 48, color: QuantisColors.success),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'Aucun débiteur ne correspond à votre recherche.'
                                : 'Félicitations ! Aucune créance en cours. Tous les comptes clients sont soldés.',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else if (isMobile)
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final d = filtered[i];
                        return Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: QuantisColors.royalBlue.withValues(alpha: 0.1),
                                      radius: 18,
                                      child: Text(
                                        d.nom.isNotEmpty ? d.nom[0].toUpperCase() : 'C',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: QuantisColors.royalBlue, fontSize: 14),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(d.nom, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                          if (d.telephone != null)
                                            Text(d.telephone!, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${d.soldeCredit.toStringAsFixed(0)} ${ApiClient.entrepriseMonnaie}',
                                          style: const TextStyle(fontWeight: FontWeight.w900, color: QuantisColors.error, fontSize: 15),
                                        ),
                                        const Text('Dû', style: TextStyle(fontSize: 10, color: QuantisColors.textMuted)),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () => _encaisserClient(d),
                                        icon: const Icon(Icons.payments, size: 16),
                                        label: const Text('Encaisser'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: QuantisColors.success,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _relancerClient(d),
                                        icon: const Icon(Icons.message, size: 16),
                                        label: const Text('Relancer'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: QuantisColors.royalBlue,
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    )
                  else
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Column(
                          children: [
                            Container(
                              color: const Color(0xFF1E293B),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              child: Row(
                                children: const [
                                  Expanded(flex: 4, child: Text('CLIENT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                  Expanded(flex: 3, child: Text('TÉLÉPHONE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                  Expanded(flex: 3, child: Text('EMAIL / ADRESSE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                  Expanded(flex: 3, child: Text('SOLDE DÛ', textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                  Expanded(flex: 4, child: Text('ACTIONS', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                ],
                              ),
                            ),
                            ...List.generate(filtered.length, (i) {
                              final d = filtered[i];
                              final isEven = i % 2 == 0;
                              return Container(
                                color: isEven ? Colors.white : const Color(0xFFF8FAFC),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 4,
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: QuantisColors.royalBlue.withValues(alpha: 0.1),
                                            radius: 16,
                                            child: Text(
                                              d.nom.isNotEmpty ? d.nom[0].toUpperCase() : 'C',
                                              style: const TextStyle(fontWeight: FontWeight.bold, color: QuantisColors.royalBlue, fontSize: 13),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              d.nom,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        d.telephone ?? '—',
                                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        d.email ?? d.adresse ?? '—',
                                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        '${d.soldeCredit.toStringAsFixed(0)} ${ApiClient.entrepriseMonnaie}',
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(fontWeight: FontWeight.w900, color: QuantisColors.error, fontSize: 15),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 4,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          ElevatedButton.icon(
                                            onPressed: () => _encaisserClient(d),
                                            icon: const Icon(Icons.payments, size: 16),
                                            label: const Text('Encaisser'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: QuantisColors.success,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          OutlinedButton.icon(
                                            onPressed: () => _relancerClient(d),
                                            icon: const Icon(Icons.message, size: 16),
                                            label: const Text('Relancer'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: QuantisColors.royalBlue,
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}
