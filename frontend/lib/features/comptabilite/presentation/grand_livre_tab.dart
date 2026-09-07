import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/quantis_theme.dart';
import '../data/comptabilite_service.dart';

/// Onglet Grand Livre Général Débit/Crédit & Arrêtés Périodiques de Clôture
class GrandLivreTab extends StatefulWidget {
  const GrandLivreTab({super.key});

  @override
  State<GrandLivreTab> createState() => _GrandLivreTabState();
}

class _GrandLivreTabState extends State<GrandLivreTab> {
  final ComptabiliteService _service = ComptabiliteService();

  late DateTime _debut;
  late DateTime _fin;
  late String _periodeKey;

  bool _loading = true;
  String? _error;

  List<EcritureGrandLivre> _ecritures = [];
  ClotureSynthese? _synthese;
  List<ClotureComptableModel> _historiqueClotures = [];

  final List<Map<String, dynamic>> _moisOptions = [
    {'label': 'Septembre 2026', 'key': '2026-09', 'debut': DateTime(2026, 9, 1), 'fin': DateTime(2026, 9, 30)},
    {'label': 'Août 2026', 'key': '2026-08', 'debut': DateTime(2026, 8, 1), 'fin': DateTime(2026, 8, 31)},
    {'label': 'Juillet 2026', 'key': '2026-07', 'debut': DateTime(2026, 7, 1), 'fin': DateTime(2026, 7, 31)},
    {'label': 'Année 2026 Complète', 'key': '2026', 'debut': DateTime(2026, 1, 1), 'fin': DateTime(2026, 12, 31)},
  ];

  @override
  void initState() {
    super.initState();
    _debut = _moisOptions[0]['debut'] as DateTime;
    _fin = _moisOptions[0]['fin'] as DateTime;
    _periodeKey = _moisOptions[0]['key'] as String;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _service.getGrandLivre(debut: _debut, fin: _fin),
        _service.simulerCloture(debut: _debut, fin: _fin, periode: _periodeKey),
        _service.getHistoriqueClotures(),
      ]);

      if (mounted) {
        setState(() {
          _ecritures = results[0] as List<EcritureGrandLivre>;
          _synthese = results[1] as ClotureSynthese;
          _historiqueClotures = results[2] as List<ClotureComptableModel>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erreur lors du chargement : $e';
          _loading = false;
        });
      }
    }
  }

  void _changerPeriode(Map<String, dynamic> opt) {
    setState(() {
      _debut = opt['debut'] as DateTime;
      _fin = opt['fin'] as DateTime;
      _periodeKey = opt['key'] as String;
    });
    _loadData();
  }

  Future<void> _validerClotureDialog() async {
    if (_synthese == null) return;
    if (_synthese!.dejaCloturee) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cette période a déjà été clôturée et verrouillée.'),
          backgroundColor: QuantisColors.warning,
        ),
      );
      return;
    }

    final notesCtrl = TextEditingController();

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final dialogWidth = (screenWidth * 0.92).clamp(280.0, 480.0);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 40,
          vertical: 16,
        ),
        title: Row(
          children: const [
            Icon(Icons.lock_outline, color: QuantisColors.royalBlue),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Clôturer la période',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: dialogWidth,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Êtes-vous sûr de vouloir arrêter et verrouiller les écritures pour la période ${_synthese!.periode} ?',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Text(
                    '⚠️ Attention : Une clôture verrouillée fige les totaux de chiffre d\'affaires, de stock et de caisse pour cette période dans le registre comptable.',
                    style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Notes & observations de clôture',
                    hintText: 'Ex: Inventaire physique conforme, caisse équilibrée...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check_circle, size: 16),
            label: const Text('Confirmer & Verrouiller'),
            style: ElevatedButton.styleFrom(
              backgroundColor: QuantisColors.royalBlue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _service.validerCloture(
          periode: _periodeKey,
          debut: _debut,
          fin: _fin,
          notes: notesCtrl.text.trim(),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Clôture enregistrée et verrouillée avec succès !'),
            backgroundColor: QuantisColors.success,
          ),
        );
        _loadData();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: QuantisColors.error),
        );
      }
    }
  }

  Future<void> _exportCsv() async {
    try {
      await _service.exportGrandLivreCsv(debut: _debut, fin: _fin);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Export CSV du Grand Livre téléchargé !'),
          backgroundColor: QuantisColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur export: $e'), backgroundColor: QuantisColors.error),
      );
    }
  }

  Future<void> _seedDemoData() async {
    try {
      await _service.seedDemoData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Données réelles injectées avec succès !'),
          backgroundColor: QuantisColors.success,
        ),
      );
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: QuantisColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'fr_FR', symbol: ApiClient.entrepriseMonnaie, decimalDigits: 0);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // =================== BANDEAU CONTRÔLES PÉRIODE ===================
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_month, color: QuantisColors.royalBlue, size: 20),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _periodeKey,
                        underline: const SizedBox(),
                        items: _moisOptions.map((opt) {
                          return DropdownMenuItem<String>(
                            value: opt['key'] as String,
                            child: Text(opt['label'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            final match = _moisOptions.firstWhere((o) => o['key'] == val);
                            _changerPeriode(match);
                          }
                        },
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _exportCsv,
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Export Grand Livre (CSV)'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _seedDemoData,
                        icon: const Icon(Icons.dataset, size: 16, color: Colors.orange),
                        label: const Text('Injecter Données Réelles'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _validerClotureDialog,
                        icon: Icon(_synthese?.dejaCloturee == true ? Icons.lock : Icons.lock_open, size: 16),
                        label: Text(_synthese?.dejaCloturee == true ? 'Période Déjà Clôturée' : 'Verrouiller Clôture'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _synthese?.dejaCloturee == true ? Colors.grey : QuantisColors.royalBlue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          else if (_error != null)
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: QuantisColors.error),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_error!, style: const TextStyle(color: QuantisColors.error))),
                    TextButton(onPressed: _loadData, child: const Text('Réessayer')),
                  ],
                ),
              ),
            )
          else ...[
            // =================== CARTES DE SYNTHÈSE DU BILAN ===================
            if (_synthese != null) ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final crossAxisCount = width > 1100 ? 5 : (width > 700 ? 3 : 1);

                  return GridView.count(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: width > 1100 ? 1.6 : 1.9,
                    children: [
                      _kpiCard('Chiffre d\'Affaires TTC', currency.format(_synthese!.chiffreAffairesTtc),
                          'HT: ${currency.format(_synthese!.chiffreAffairesHt)} • TVA: ${currency.format(_synthese!.totalTvaCollectee)}',
                          Icons.trending_up, QuantisColors.royalBlue),
                      _kpiCard('Marge Brute Estimée', currency.format(_synthese!.margeBruteEstimee),
                          'Achats: ${currency.format(_synthese!.totalAchatsHt)}',
                          Icons.diamond_outlined, QuantisColors.success),
                      _kpiCard('Solde Caisse Net', currency.format(_synthese!.soldeCaisseFinal),
                          'Entrées: ${currency.format(_synthese!.totalEntreesCaisse)} • Dépenses: ${currency.format(_synthese!.totalDepensesCaisse)}',
                          Icons.account_balance_wallet_outlined, Colors.indigo),
                      _kpiCard('Valeur Stock Final', currency.format(_synthese!.valeurStockFinPeriode),
                          'Valorisation globale au prix d\'achat',
                          Icons.inventory_2_outlined, Colors.purple),
                      _kpiCard('Créances Clients', currency.format(_synthese!.totalCreancesClients),
                          'Dettes Fournisseurs: ${currency.format(_synthese!.totalDettesFournisseurs)}',
                          Icons.people_outline, Colors.orange.shade800),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
            ],

            // =================== TABLEAU DU GRAND LIVRE ===================
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: QuantisColors.royalBlue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.menu_book, color: QuantisColors.royalBlue, size: 20),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Grand Livre Général des Écritures',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                        Text(
                          '${_ecritures.length} opérations consolidées',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 6),

                    if (_ecritures.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: Text('Aucune écriture comptable trouvée pour cette période.', style: TextStyle(color: Colors.grey)),
                        ),
                      )
                    else
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                          columnSpacing: 20,
                          horizontalMargin: 12,
                          columns: const [
                            DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Réf Pièce', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Tiers / Catégorie', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Libellé Opération', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Débit (+)', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Crédit (-)', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Solde Cumulé', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: _ecritures.map((e) {
                            final isDebit = e.debit > 0;
                            return DataRow(
                              cells: [
                                DataCell(Text(e.date, style: const TextStyle(fontSize: 12))),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(e.referencePiece, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                DataCell(Text(e.tiersOuCategorie, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                                DataCell(Text(e.libelle, style: const TextStyle(fontSize: 12))),
                                DataCell(
                                  Text(
                                    e.debit > 0 ? currency.format(e.debit) : '-',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isDebit ? QuantisColors.success : Colors.black,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    e.credit > 0 ? currency.format(e.credit) : '-',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: e.credit > 0 ? QuantisColors.error : Colors.black,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    currency.format(e.soldeProgressif),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: QuantisColors.royalBlue),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),

            // =================== HISTORIQUE DES CLÔTURES ===================
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.verified, color: Colors.green, size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Historique des Clôtures & Arrêtés Verrouillés',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 6),

                    if (_historiqueClotures.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: Text('Aucune clôture verrouillée pour l\'instant.', style: TextStyle(color: Colors.grey)),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _historiqueClotures.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, idx) {
                          final c = _historiqueClotures[idx];
                          final dateClot = c.dateCloture.isNotEmpty && c.dateCloture.length >= 10
                              ? c.dateCloture.substring(0, 10)
                              : c.dateCloture;
                          final isSmall = MediaQuery.of(context).size.width < 600;

                          if (isSmall) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundColor: Colors.green.shade50,
                                        foregroundColor: Colors.green.shade700,
                                        child: const Icon(Icons.lock, size: 14),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(c.libelle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade100,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          c.statut,
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade900),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Période: ${c.dateDebut} au ${c.dateFin} • Verrouillé le $dateClot par ${c.clotureParNom}${c.notes != null && c.notes!.isNotEmpty ? "\nNote: ${c.notes}" : ""}',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'CA: ${currency.format(c.chiffreAffairesTtc)}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: QuantisColors.royalBlue),
                                      ),
                                      Text(
                                        'Marge: ${currency.format(c.margeBruteEstimee)}',
                                        style: const TextStyle(fontSize: 12, color: QuantisColors.success, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.green.shade50,
                              foregroundColor: Colors.green.shade700,
                              child: const Icon(Icons.lock, size: 20),
                            ),
                            title: Row(
                              children: [
                                Text(c.libelle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    c.statut,
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade900),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              'Période: ${c.dateDebut} au ${c.dateFin} • Verrouillé le $dateClot par ${c.clotureParNom}${c.notes != null && c.notes!.isNotEmpty ? "\nNote: ${c.notes}" : ""}',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'CA: ${currency.format(c.chiffreAffairesTtc)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: QuantisColors.royalBlue),
                                ),
                                Text(
                                  'Marge: ${currency.format(c.margeBruteEstimee)}',
                                  style: const TextStyle(fontSize: 11, color: QuantisColors.success, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kpiCard(String title, String mainVal, String subVal, IconData icon, Color color) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(icon, color: color, size: 20),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              mainVal,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              subVal,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
