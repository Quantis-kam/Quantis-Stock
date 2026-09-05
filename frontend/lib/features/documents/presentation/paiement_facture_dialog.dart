import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/quantis_theme.dart';
import '../data/document_models.dart';

/// Modal d'encaissement de reliquat sur facture
class PaiementFactureDialog extends StatefulWidget {
  final DocumentModel document;

  const PaiementFactureDialog({
    super.key,
    required this.document,
  });

  @override
  State<PaiementFactureDialog> createState() => _PaiementFactureDialogState();
}

class _PaiementFactureDialogState extends State<PaiementFactureDialog> {
  final ApiClient _api = ApiClient();
  final _montantCtrl = TextEditingController();
  final _refCtrl = TextEditingController();

  String _moyenPaiement = 'ESPECES';
  DateTime _datePaiement = DateTime.now();
  bool _saving = false;

  final _moyens = [
    {'code': 'ESPECES', 'label': 'Espèces'},
    {'code': 'WAVE', 'label': 'Wave'},
    {'code': 'ORANGE_MONEY', 'label': 'Orange Money'},
    {'code': 'MOOV_MONEY', 'label': 'Moov Money'},
    {'code': 'CARTE_BANCAIRE', 'label': 'Carte Bancaire'},
    {'code': 'VIREMENT', 'label': 'Virement'},
  ];

  @override
  void initState() {
    super.initState();
    _montantCtrl.text = widget.document.soldeRestant.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _montantCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  Future<void> _valider() async {
    final double montant = double.tryParse(_montantCtrl.text) ?? 0;
    if (montant <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Montant invalide'), backgroundColor: QuantisColors.warning),
      );
      return;
    }

    if (montant > widget.document.soldeRestant) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Le montant ne peut pas dépasser le solde restant (${widget.document.soldeRestant.toStringAsFixed(0)} FCFA)'),
          backgroundColor: QuantisColors.warning,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final payload = {
        'documentId': widget.document.id,
        'montant': montant,
        'moyen': _moyenPaiement,
        'datePaiement': _datePaiement.toIso8601String().substring(0, 10),
        'reference': _refCtrl.text.trim(),
      };

      await _api.post('/documents/payments', data: payload);
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 460,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.payment, color: QuantisColors.royalBlue, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Régler ${widget.document.numero}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Client : ${widget.document.clientNom ?? "Client"}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(height: 24),

            // Reliquat Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: QuantisColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: QuantisColors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Solde Restant à payer :', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    '${widget.document.soldeRestant.toStringAsFixed(0)} FCFA',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: QuantisColors.warning),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Montant à régler
            TextField(
              controller: _montantCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                labelText: 'Montant du Paiement (FCFA) *',
                prefixIcon: Icon(Icons.money),
              ),
            ),
            const SizedBox(height: 16),

            // Mode de règlement
            DropdownButtonFormField<String>(
              value: _moyenPaiement,
              decoration: const InputDecoration(
                labelText: 'Moyen de Règlement',
                prefixIcon: Icon(Icons.account_balance_wallet),
              ),
              items: _moyens.map((m) {
                return DropdownMenuItem<String>(
                  value: m['code']!,
                  child: Text(m['label']!),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _moyenPaiement = val);
              },
            ),
            const SizedBox(height: 16),

            // Référence
            TextField(
              controller: _refCtrl,
              decoration: const InputDecoration(
                labelText: 'Référence / Reçu (optionnel)',
                prefixIcon: Icon(Icons.receipt_outlined),
              ),
            ),
            const SizedBox(height: 24),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _valider,
                  icon: _saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check, size: 18),
                  label: const Text('Enregistrer le règlement'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: QuantisColors.royalBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
