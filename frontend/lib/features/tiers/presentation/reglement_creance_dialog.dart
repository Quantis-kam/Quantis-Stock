import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/quantis_theme.dart';
import '../../documents/data/document_models.dart';
import '../data/tiers_models.dart';

/// Dialogue dédié au règlement des créances d'un client (facture précise OU règlement global / acompte FIFO).
class ReglementCreanceDialog extends StatefulWidget {
  final ClientModel client;
  final int? preselectedDocumentId;

  const ReglementCreanceDialog({
    super.key,
    required this.client,
    this.preselectedDocumentId,
  });

  @override
  State<ReglementCreanceDialog> createState() => _ReglementCreanceDialogState();
}

class _ReglementCreanceDialogState extends State<ReglementCreanceDialog> {
  final ApiClient _api = ApiClient();
  final _montantCtrl = TextEditingController();
  final _refCtrl = TextEditingController();

  List<DocumentModel> _facturesImpayees = [];
  int? _selectedDocumentId; // null = règlement global FIFO
  String _moyenPaiement = 'ESPECES';
  bool _loadingDocs = true;
  bool _saving = false;
  double _montantSaisi = 0;

  final _moyens = const [
    {'code': 'ESPECES', 'label': 'Espèces', 'icon': Icons.payments},
    {'code': 'WAVE', 'label': 'Wave', 'icon': Icons.phone_android},
    {'code': 'ORANGE_MONEY', 'label': 'Orange Money', 'icon': Icons.account_balance_wallet},
    {'code': 'MOOV_MONEY', 'label': 'Moov Money', 'icon': Icons.send_to_mobile},
    {'code': 'CARTE_BANCAIRE', 'label': 'Carte Bancaire', 'icon': Icons.credit_card},
    {'code': 'VIREMENT', 'label': 'Virement', 'icon': Icons.account_balance},
  ];

  @override
  void initState() {
    super.initState();
    _selectedDocumentId = widget.preselectedDocumentId;
    _montantSaisi = widget.client.soldeCredit;
    _montantCtrl.text = widget.client.soldeCredit.toStringAsFixed(0);
    _loadUnpaidInvoices();
  }

  @override
  void dispose() {
    _montantCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUnpaidInvoices() async {
    try {
      final res = await _api.get('/documents/client/${widget.client.id}?size=100');
      final list = (res.data['data']?['content'] as List?) ?? [];
      final unpaid = list
          .map((e) => DocumentModel.fromJson(e as Map<String, dynamic>))
          .where((d) => d.type == 'FACTURE' && d.statut == 'VALIDE' && !d.isPayeIntegral)
          .toList();
      if (mounted) {
        setState(() {
          _facturesImpayees = unpaid;
          _loadingDocs = false;
          if (_selectedDocumentId != null) {
            final match = unpaid.where((f) => f.id == _selectedDocumentId).firstOrNull;
            if (match != null) {
              _montantSaisi = match.soldeRestant;
              _montantCtrl.text = match.soldeRestant.toStringAsFixed(0);
            }
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingDocs = false);
    }
  }

  double get _maxAutorise {
    if (_selectedDocumentId != null) {
      final match = _facturesImpayees.where((f) => f.id == _selectedDocumentId).firstOrNull;
      if (match != null) return match.soldeRestant;
    }
    return widget.client.soldeCredit;
  }

  void _selectDocument(int? docId) {
    setState(() {
      _selectedDocumentId = docId;
      final target = _maxAutorise;
      _montantSaisi = target;
      _montantCtrl.text = target.toStringAsFixed(0);
    });
  }

  Future<void> _valider() async {
    final montant = double.tryParse(_montantCtrl.text.trim().replaceAll(' ', '').replaceAll(',', '.')) ?? 0;
    final monnaie = ApiClient.entrepriseMonnaie;
    if (montant <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez saisir un montant supérieur à 0.'), backgroundColor: QuantisColors.warning),
      );
      return;
    }
    if (montant > _maxAutorise + 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Le montant dépasse le reste dû (${_maxAutorise.toStringAsFixed(0)} $monnaie).'),
          backgroundColor: QuantisColors.warning,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final res = await _api.post('/clients/${widget.client.id}/reglements', data: {
        'montant': montant,
        'moyen': _moyenPaiement,
        if (_selectedDocumentId != null) 'documentId': _selectedDocumentId,
        'datePaiement': DateTime.now().toIso8601String().substring(0, 10),
        'reference': _refCtrl.text.trim(),
      });

      final data = res.data['data'] as Map<String, dynamic>?;
      final nouveauSolde = (data?['nouveauSolde'] as num?)?.toDouble() ?? 0;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              nouveauSolde <= 0
                  ? 'Crédit intégralement soldé pour ${widget.client.nom} !'
                  : 'Règlement de ${montant.toStringAsFixed(0)} $monnaie enregistré. Nouveau solde : ${nouveauSolde.toStringAsFixed(0)} $monnaie.',
            ),
            backgroundColor: QuantisColors.success,
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiClient.formatErrorMessage(e, fallback: 'Impossible d\'enregistrer le règlement.')),
            backgroundColor: QuantisColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final monnaie = ApiClient.entrepriseMonnaie;
    final isMobile = MediaQuery.of(context).size.width < 600;
    final resteApres = (widget.client.soldeCredit - _montantSaisi).clamp(0.0, double.infinity);

    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 32, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: isMobile ? double.infinity : 520,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: QuantisColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.payments_rounded, color: QuantisColors.success, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Encaisser un Règlement de Crédit',
                            style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold)),
                        Text(
                          '${widget.client.nom}${widget.client.telephone != null ? " • ${widget.client.telephone}" : ""}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const Divider(height: 20),

              // Solde actuel
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: QuantisColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: QuantisColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Dette totale actuelle :', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${widget.client.soldeCredit.toStringAsFixed(0)} $monnaie',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: QuantisColors.error),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Choix : Règlement global ou facture précise
              if (_loadingDocs)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(),
                )
              else if (_facturesImpayees.isNotEmpty) ...[
                const Text('Imputation du règlement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      RadioListTile<int?>(
                        dense: true,
                        value: null,
                        groupValue: _selectedDocumentId,
                        title: const Text('Règlement global / Acompte (automatique)',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          'Solde automatiquement les ${_facturesImpayees.length} facture(s) impayée(s) par ancienneté.',
                          style: const TextStyle(fontSize: 11),
                        ),
                        onChanged: _selectDocument,
                      ),
                      const Divider(height: 1),
                      ..._facturesImpayees.map((f) => RadioListTile<int?>(
                            dense: true,
                            value: f.id,
                            groupValue: _selectedDocumentId,
                            title: Text('${f.numero}  (${f.dateDocument ?? ""})',
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              'Reste à payer : ${f.soldeRestant.toStringAsFixed(0)} $monnaie / ${f.totalTtc.toStringAsFixed(0)} $monnaie',
                              style: const TextStyle(fontSize: 11, color: QuantisColors.warning, fontWeight: FontWeight.w600),
                            ),
                            onChanged: _selectDocument,
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Montant encaissé + raccourcis
              TextField(
                controller: _montantCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'Montant reçu ($monnaie) *',
                  prefixIcon: const Icon(Icons.money),
                  suffixText: monnaie,
                ),
                onChanged: (v) => setState(() {
                  _montantSaisi = double.tryParse(v.replaceAll(' ', '').replaceAll(',', '.')) ?? 0;
                }),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.done_all, size: 15, color: QuantisColors.success),
                    label: Text('Tout solder (${_maxAutorise.toStringAsFixed(0)} $monnaie)'),
                    onPressed: () {
                      setState(() {
                        _montantSaisi = _maxAutorise;
                        _montantCtrl.text = _maxAutorise.toStringAsFixed(0);
                      });
                    },
                  ),
                  if (_maxAutorise >= 1000)
                    ActionChip(
                      label: Text('Moitié (${(_maxAutorise / 2).round()} $monnaie)'),
                      onPressed: () {
                        final half = (_maxAutorise / 2).roundToDouble();
                        setState(() {
                          _montantSaisi = half;
                          _montantCtrl.text = half.toStringAsFixed(0);
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 14),

              // Mode de paiement
              const Text('Moyen d\'encaissement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _moyens.map((m) {
                  final isSel = _moyenPaiement == m['code'];
                  return ChoiceChip(
                    avatar: Icon(m['icon'] as IconData, size: 15, color: isSel ? Colors.white : QuantisColors.royalBlue),
                    label: Text(m['label'] as String),
                    selected: isSel,
                    selectedColor: QuantisColors.royalBlue,
                    labelStyle: TextStyle(
                      color: isSel ? Colors.white : Colors.black87,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                    onSelected: (s) {
                      if (s) setState(() => _moyenPaiement = m['code'] as String);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Référence
              TextField(
                controller: _refCtrl,
                decoration: const InputDecoration(
                  labelText: 'Référence reçu / Mobile Money (optionnel)',
                  prefixIcon: Icon(Icons.receipt_outlined),
                ),
              ),
              const SizedBox(height: 14),

              // Aperçu nouveau solde
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: (resteApres <= 0 ? QuantisColors.success : QuantisColors.royalBlue).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (resteApres <= 0 ? QuantisColors.success : QuantisColors.royalBlue).withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        resteApres <= 0 ? 'Statut après règlement :' : 'Nouveau solde restant :',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          resteApres <= 0 ? 'COMPTE SOLDÉ ✓' : '${resteApres.toStringAsFixed(0)} $monnaie',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: resteApres <= 0 ? QuantisColors.success : QuantisColors.royalBlue,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _valider,
                      icon: _saving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_circle, size: 18),
                      label: const Text('Confirmer l\'encaissement', overflow: TextOverflow.ellipsis),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: QuantisColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

