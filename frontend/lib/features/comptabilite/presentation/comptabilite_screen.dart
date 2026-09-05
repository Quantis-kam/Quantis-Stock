import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/quantis_theme.dart';
import 'mouvement_caisse_dialog.dart';
import 'session_caisse_dialog.dart';
import 'grand_livre_tab.dart';

/// Écran Comptabilité & Module Caisse Autonome — Phase 1.
class ComptabiliteScreen extends StatefulWidget {
  const ComptabiliteScreen({super.key});

  @override
  State<ComptabiliteScreen> createState() => _ComptabiliteScreenState();
}

class _ComptabiliteScreenState extends State<ComptabiliteScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  Map<String, dynamic>? _activeSession;
  Map<String, dynamic>? _reportData;
  List<dynamic> _journal = [];
  List<dynamic> _sessions = [];

  bool _loading = true;
  String? _error;

  final DateTime _dateDebut = DateTime(DateTime.now().year, DateTime.now().month, 1);
  final DateTime _dateFin = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final dio = ApiClient.instance;
      final debutStr = _dateDebut.toIso8601String().substring(0, 10);
      final finStr = _dateFin.toIso8601String().substring(0, 10);

      final results = await Future.wait([
        dio.get('/caisses/session-active'),
        dio.get('/accounting/report', queryParameters: {'debut': debutStr, 'fin': finStr}),
        dio.get('/accounting/cash', queryParameters: {'debut': debutStr, 'fin': finStr, 'size': 100}),
        dio.get('/caisses/historique', queryParameters: {'size': 50}),
      ]);

      if (mounted) {
        setState(() {
          _activeSession = results[0].data['data'] as Map<String, dynamic>?;
          _reportData = results[1].data['data'] as Map<String, dynamic>?;
          _journal = (results[2].data['data']?['content'] as List?) ?? [];
          _sessions = (results[3].data['data']?['content'] as List?) ?? [];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erreur lors du chargement: $e';
          _loading = false;
        });
      }
    }
  }

  void _openSessionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => SessionCaisseDialog(
        activeSession: _activeSession,
        onSessionChanged: _loadAllData,
      ),
    );
  }

  void _openMouvementDialog() {
    showDialog(
      context: context,
      builder: (ctx) => MouvementCaisseDialog(
        onSaved: _loadAllData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final devise = ApiClient.entrepriseMonnaie;

    final totalEntrees = (_reportData?['totalEntrees'] as num? ?? 0).toDouble();
    final totalSorties = (_reportData?['totalSorties'] as num? ?? 0).toDouble();
    final soldeNet = (_reportData?['solde'] as num? ?? 0).toDouble();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion de Caisse & Comptabilité', style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllData,
            tooltip: 'Actualiser',
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: QuantisColors.luxuryGold),
            onPressed: _openMouvementDialog,
            tooltip: 'Nouveau mouvement de caisse',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: QuantisColors.luxuryGold,
          tabs: const [
            Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Journal de Caisse'),
            Tab(icon: Icon(Icons.history_toggle_off), text: 'Sessions de Caisse'),
            Tab(icon: Icon(Icons.menu_book), text: 'Grand Livre & Clôtures'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: QuantisColors.error)))
              : RefreshIndicator(
                  onRefresh: _loadAllData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Active Caisse Status Banner
                        _buildActiveSessionBanner(),
                        const SizedBox(height: 16),

                        // Financial KPI Cards
                        Row(
                          children: [
                            Expanded(child: _kpiCard('Entrées Période', '${totalEntrees.toStringAsFixed(0)} $devise', Icons.arrow_downward, QuantisColors.success)),
                            const SizedBox(width: 12),
                            Expanded(child: _kpiCard('Sorties Période', '${totalSorties.toStringAsFixed(0)} $devise', Icons.arrow_upward, QuantisColors.error)),
                            const SizedBox(width: 12),
                            Expanded(child: _kpiCard('Solde Net Période', '${soldeNet.toStringAsFixed(0)} $devise', Icons.account_balance_wallet, QuantisColors.royalBlue)),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Action Buttons Bar
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: _openMouvementDialog,
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Nouveau Mouvement'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: QuantisColors.royalBlue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: _openSessionDialog,
                              icon: Icon(_activeSession != null ? Icons.lock : Icons.lock_open, size: 18),
                              label: Text(_activeSession != null ? 'Fermer Session Caisse' : 'Ouvrir Session Caisse'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _activeSession != null ? QuantisColors.warning : QuantisColors.success,
                                side: BorderSide(color: _activeSession != null ? QuantisColors.warning : QuantisColors.success),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // TabBar Content (Scrollable Container with dynamic height)
                        SizedBox(
                          height: 900,
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildJournalTab(devise),
                              _buildSessionsTab(devise),
                              const GrandLivreTab(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildActiveSessionBanner() {
    final isOpen = _activeSession != null;
    final solde = isOpen ? (_activeSession!['soldeTheorique'] as num? ?? 0).toDouble() : 0.0;
    final fond = isOpen ? (_activeSession!['fondCaisseOuverture'] as num? ?? 0).toDouble() : 0.0;
    final dateOuv = isOpen && _activeSession!['dateOuverture'] != null
        ? _activeSession!['dateOuverture'].toString().substring(0, 16).replaceAll('T', ' à ')
        : '-';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isOpen ? QuantisColors.royalBlue : Colors.amber.shade900,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white24,
              child: Icon(isOpen ? Icons.point_of_sale : Icons.lock_clock, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isOpen ? QuantisColors.success : Colors.white24,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isOpen ? 'SESSION DE CAISSE ACTIVE' : 'AUCUNE CAISSE OUVERTE',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                      if (isOpen)
                        Text('Ouverte le $dateOuv', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isOpen
                        ? 'Solde théorique : ${solde.toStringAsFixed(0)} ${ApiClient.entrepriseMonnaie} (Fond: ${fond.toStringAsFixed(0)})'
                        : 'Ouvrez votre session pour enregistrer et suivre les encaissements.',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: _openSessionDialog,
              icon: Icon(isOpen ? Icons.lock : Icons.lock_open, size: 16),
              label: Text(isOpen ? 'Clôturer' : 'Ouvrir Caisse'),
              style: ElevatedButton.styleFrom(
                backgroundColor: QuantisColors.luxuryGold,
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpiCard(String label, String val, IconData icon, Color col) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: col, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: QuantisColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
            const SizedBox(height: 8),
            Text(val, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: col)),
          ],
        ),
      ),
    );
  }

  Widget _buildJournalTab(String devise) {
    if (_journal.isEmpty) {
      return const Center(
        child: Text('Aucun mouvement de caisse sur la période sélectionnée.', style: TextStyle(color: QuantisColors.textMuted)),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListView.separated(
        itemCount: _journal.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, idx) {
          final m = _journal[idx];
          final isEntree = m['type'] == 'ENTREE';
          final montant = (m['montant'] as num? ?? 0).toDouble();

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: (isEntree ? QuantisColors.success : QuantisColors.error).withValues(alpha: 0.15),
              foregroundColor: isEntree ? QuantisColors.success : QuantisColors.error,
              child: Icon(isEntree ? Icons.arrow_downward : Icons.arrow_upward, size: 20),
            ),
            title: Text(m['libelle'] ?? 'Mouvement', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text(
              'Date: ${m['dateMouvement'] ?? "-"} | Catégorie: ${m['categorie'] ?? "Général"}${m['reference'] != null ? " | Ref: ${m['reference']}" : ""}',
              style: const TextStyle(fontSize: 11, color: QuantisColors.textMuted),
            ),
            trailing: Text(
              '${isEntree ? "+" : "-"}${montant.toStringAsFixed(0)} $devise',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: isEntree ? QuantisColors.success : QuantisColors.error,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSessionsTab(String devise) {
    if (_sessions.isEmpty) {
      return const Center(
        child: Text('Aucune session de caisse enregistrée.', style: TextStyle(color: QuantisColors.textMuted)),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListView.separated(
        itemCount: _sessions.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, idx) {
          final s = _sessions[idx];
          final isOpen = s['statut'] == 'OUVERTE';
          final fond = (s['fondCaisseOuverture'] as num? ?? 0).toDouble();
          final theorique = (s['soldeTheorique'] as num? ?? 0).toDouble();
          final compte = s['soldeCompte'] != null ? (s['soldeCompte'] as num).toDouble() : null;
          final ecart = s['ecart'] != null ? (s['ecart'] as num).toDouble() : null;

          final dateOuv = s['dateOuverture'] != null ? s['dateOuverture'].toString().substring(0, 16).replaceAll('T', ' ') : '-';
          final dateFerm = s['dateFermeture'] != null ? s['dateFermeture'].toString().substring(0, 16).replaceAll('T', ' ') : '-';

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: (isOpen ? QuantisColors.success : Colors.grey).withValues(alpha: 0.15),
              foregroundColor: isOpen ? QuantisColors.success : Colors.grey.shade700,
              child: Icon(isOpen ? Icons.lock_open : Icons.lock, size: 20),
            ),
            title: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Session #${s['id']} — ${s['caissier']?['prenom'] ?? ""} ${s['caissier']?['nom'] ?? "Caissier"}', style: const TextStyle(fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (isOpen ? QuantisColors.success : Colors.grey.shade400).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(s['statut'] ?? '', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isOpen ? QuantisColors.success : Colors.grey.shade800)),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                'Ouvert: $dateOuv | Clôturé: $dateFerm\nFond départ: ${fond.toStringAsFixed(0)} $devise | Entrées: ${(s['totalEntrees'] as num? ?? 0).toStringAsFixed(0)} | Sorties: ${(s['totalSorties'] as num? ?? 0).toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 11, color: QuantisColors.textMuted),
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Théorique: ${theorique.toStringAsFixed(0)} $devise', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: QuantisColors.royalBlue)),
                if (compte != null)
                  Text('Compté: ${compte.toStringAsFixed(0)} $devise', style: const TextStyle(fontSize: 11)),
                if (ecart != null)
                  Text(
                    'Écart: ${ecart >= 0 ? "+" : ""}${ecart.toStringAsFixed(0)} $devise',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: ecart == 0 ? QuantisColors.success : (ecart > 0 ? Colors.blue : QuantisColors.error),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
