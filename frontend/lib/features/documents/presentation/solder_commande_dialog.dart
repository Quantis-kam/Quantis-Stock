import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/quantis_theme.dart';
import '../../sales/presentation/ticket_receipt_dialog.dart';
import '../data/document_models.dart';

/// Dialogue simple en 1 étape pour valider, déstocker, facturer et solder une Commande Client.
class SolderCommandeDialog extends StatefulWidget {
  final DocumentModel commande;

  const SolderCommandeDialog({
    super.key,
    required this.commande,
  });

  @override
  State<SolderCommandeDialog> createState() => _SolderCommandeDialogState();
}

class _SolderCommandeDialogState extends State<SolderCommandeDialog> {
  final ApiClient _api = ApiClient();
  final _montantCtrl = TextEditingController();
  final _refCtrl = TextEditingController();

  String _moyenPaiement = 'ESPECES';
  bool _saving = false;
  double _montantPaye = 0;

  final _moyens = const [
    {'code': 'ESPECES', 'label': 'Espèces', 'icon': Icons.payments},
    {'code': 'WAVE', 'label': 'Wave', 'icon': Icons.phone_android},
    {'code': 'ORANGE_MONEY', 'label': 'Orange Money', 'icon': Icons.account_balance_wallet},
    {'code': 'MOOV_MONEY', 'label': 'Moov Money', 'icon': Icons.send_to_mobile},
    {'code': 'CARTE_BANCAIRE', 'label': 'Carte Bancaire', 'icon': Icons.credit_card},
    {'code': 'VIREMENT', 'label': 'Virement', 'icon': Icons.account_balance},
    {'code': 'CREDIT', 'label': 'À Crédit', 'icon': Icons.access_time},
  ];

  @override
  void initState() {
    super.initState();
    _montantPaye = widget.commande.totalTtc;
    _montantCtrl.text = widget.commande.totalTtc.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _montantCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  Future<void> _validerEtSolder() async {
    final double montant = _moyenPaiement == 'CREDIT'
        ? 0.0
        : (double.tryParse(_montantCtrl.text.trim().replaceAll(' ', '').replaceAll(',', '.')) ?? widget.commande.totalTtc);

    setState(() => _saving = true);
    try {
      final res = await _api.post('/documents/${widget.commande.id}/solder-commande', data: {
        'moyenPaiement': _moyenPaiement,
        'montantPaye': montant,
        'montantRecu': montant,
        'reference': _refCtrl.text.trim(),
      });

      final saleData = res.data['data'] as Map<String, dynamic>?;
      if (!mounted) return;

      Navigator.pop(context, true);

      if (saleData != null) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => TicketReceiptDialog(saleData: saleData),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiClient.formatErrorMessage(e, fallback: 'Impossible de valider cette commande.')),
            backgroundColor: QuantisColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final monnaie = ApiClient.entrepriseMonnaie;
    final isMobile = MediaQuery.of(context).size.width < 600;
    final reste = _moyenPaiement == 'CREDIT'
        ? widget.commande.totalTtc
        : (widget.commande.totalTtc - _montantPaye).clamp(0.0, double.infinity);

    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 32, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: isMobile ? double.infinity : 500,
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: QuantisColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.task_alt_rounded, color: QuantisColors.success, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Valider & Solder ${widget.commande.numero}',
                            style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold)),
                        Text('Client : ${widget.commande.clientNom ?? "Client"}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 10),

              // Explication limpide en 1 ligne
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: QuantisColors.royalBlue.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, size: 16, color: QuantisColors.royalBlue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'En 1 clic : valide la commande, met à jour le stock, génère la facture officielle et enregistre l\'encaissement en caisse.',
                        style: TextStyle(fontSize: 11.5, color: Colors.grey.shade800),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Montant total commande
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: QuantisColors.royalBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: QuantisColors.royalBlue.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Montant Commande :', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${widget.commande.totalTtc.toStringAsFixed(0)} $monnaie',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: QuantisColors.royalBlue),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Moyen de paiement
              const Text('Mode de règlement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _moyens.map((m) {
                  final isSel = _moyenPaiement == m['code'];
                  final isCredit = m['code'] == 'CREDIT';
                  return ChoiceChip(
                    avatar: Icon(m['icon'] as IconData,
                        size: 15, color: isSel ? Colors.white : (isCredit ? Colors.orange.shade800 : QuantisColors.royalBlue)),
                    label: Text(m['label'] as String),
                    selected: isSel,
                    selectedColor: isCredit ? Colors.orange.shade800 : QuantisColors.royalBlue,
                    labelStyle: TextStyle(
                      color: isSel ? Colors.white : Colors.black87,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                    onSelected: (s) {
                      if (s) {
                        setState(() {
                          _moyenPaiement = m['code'] as String;
                          if (isCredit) {
                            _montantPaye = 0;
                            _montantCtrl.text = '0';
                          } else if (_montantPaye == 0) {
                            _montantPaye = widget.commande.totalTtc;
                            _montantCtrl.text = widget.commande.totalTtc.toStringAsFixed(0);
                          }
                        });
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              if (_moyenPaiement != 'CREDIT') ...[
                TextField(
                  controller: _montantCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Montant encaissé ($monnaie)',
                    prefixIcon: const Icon(Icons.money),
                    suffixText: monnaie,
                  ),
                  onChanged: (v) => setState(() {
                    _montantPaye = double.tryParse(v.replaceAll(' ', '').replaceAll(',', '.')) ?? 0;
                  }),
                ),
                const SizedBox(height: 10),
              ],

              if (reste > 0)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: QuantisColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: QuantisColors.warning),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: QuantisColors.warning, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Reste de ${reste.toStringAsFixed(0)} $monnaie enregistré dans les créances de ${widget.commande.clientNom ?? "ce client"}.',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 12),
              TextField(
                controller: _refCtrl,
                decoration: const InputDecoration(
                  labelText: 'Référence paiement / Note (optionnel)',
                  prefixIcon: Icon(Icons.receipt_outlined),
                ),
              ),
              const SizedBox(height: 20),

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
                      onPressed: _saving ? null : _validerEtSolder,
                      icon: _saving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_circle, size: 18),
                      label: Text(
                        reste <= 0 ? 'Valider & Solder' : 'Facturer & Enregistrer',
                        overflow: TextOverflow.ellipsis,
                      ),
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

