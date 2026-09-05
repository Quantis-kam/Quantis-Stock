import 'package:flutter/material.dart';
import '../../../core/theme/quantis_theme.dart';

/// Dialogue d'encaissement rapide avec raccourcis de coupures et calcul de monnaie
class EncaissementDialog extends StatefulWidget {
  final double totalTtc;
  final String? clientNom;

  const EncaissementDialog({
    super.key,
    required this.totalTtc,
    this.clientNom,
  });

  @override
  State<EncaissementDialog> createState() => _EncaissementDialogState();
}

class _EncaissementDialogState extends State<EncaissementDialog> {
  String _moyenPaiement = 'ESPECES';
  final _montantRecuCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  double _montantRecu = 0;

  final _moyens = [
    {'code': 'ESPECES', 'label': 'Espèces', 'icon': Icons.payments},
    {'code': 'WAVE', 'label': 'Wave', 'icon': Icons.phone_android},
    {'code': 'ORANGE_MONEY', 'label': 'Orange Money', 'icon': Icons.account_balance_wallet},
    {'code': 'MOOV_MONEY', 'label': 'Moov Money', 'icon': Icons.send_to_mobile},
    {'code': 'CARTE_BANCAIRE', 'label': 'Carte Bancaire', 'icon': Icons.credit_card},
    {'code': 'CREDIT', 'label': 'À Crédit', 'icon': Icons.access_time},
  ];

  @override
  void initState() {
    super.initState();
    _montantRecu = widget.totalTtc;
    _montantRecuCtrl.text = widget.totalTtc.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _montantRecuCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _ajouterCoupure(double montant) {
    setState(() {
      _montantRecu += montant;
      _montantRecuCtrl.text = _montantRecu.toStringAsFixed(0);
    });
  }

  void _setMontantExact() {
    setState(() {
      _montantRecu = widget.totalTtc;
      _montantRecuCtrl.text = _montantRecu.toStringAsFixed(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final double monnaieRendue = _montantRecu > widget.totalTtc ? (_montantRecu - widget.totalTtc) : 0;
    final double resteAPayer = _montantRecu < widget.totalTtc ? (widget.totalTtc - _montantRecu) : 0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.point_of_sale, color: QuantisColors.royalBlue, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Encaissement de la Vente',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Client : ${widget.clientNom ?? "Client Divers / Comptoir"}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Total à Encaisser Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: QuantisColors.royalBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: QuantisColors.royalBlue.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'NET À PAYER :',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: QuantisColors.royalBlue),
                    ),
                    Text(
                      '${widget.totalTtc.toStringAsFixed(0)} FCFA',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: QuantisColors.royalBlue),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Mode de Paiement Selector
              const Text('Mode de règlement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _moyens.map((m) {
                  final isSelected = _moyenPaiement == m['code'];
                  return ChoiceChip(
                    avatar: Icon(
                      m['icon'] as IconData,
                      size: 16,
                      color: isSelected ? Colors.white : QuantisColors.royalBlue,
                    ),
                    label: Text(m['label'] as String),
                    selected: isSelected,
                    selectedColor: QuantisColors.royalBlue,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _moyenPaiement = m['code'] as String;
                          if (_moyenPaiement == 'CREDIT') {
                            _montantRecu = 0;
                            _montantRecuCtrl.text = '0';
                          } else if (_montantRecu == 0) {
                            _setMontantExact();
                          }
                        });
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Montant Reçu (si espèces ou mobile money)
              if (_moyenPaiement != 'CREDIT') ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _montantRecuCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          labelText: 'Montant Donné par le Client',
                          suffixText: 'FCFA',
                          prefixIcon: Icon(Icons.attach_money),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _montantRecu = double.tryParse(val) ?? 0;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _setMontantExact,
                      child: const Text('Compte Exact'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Coupures rapides
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ActionChip(label: const Text('+500'), onPressed: () => _ajouterCoupure(500)),
                    ActionChip(label: const Text('+1 000'), onPressed: () => _ajouterCoupure(1000)),
                    ActionChip(label: const Text('+2 000'), onPressed: () => _ajouterCoupure(2000)),
                    ActionChip(label: const Text('+5 000'), onPressed: () => _ajouterCoupure(5000)),
                    ActionChip(label: const Text('+10 000'), onPressed: () => _ajouterCoupure(10000)),
                  ],
                ),
                const SizedBox(height: 14),

                // Monnaie rendue ou solde restant
                if (monnaieRendue > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: QuantisColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: QuantisColors.success),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Monnaie à rendre :', style: TextStyle(fontWeight: FontWeight.bold, color: QuantisColors.success)),
                        Text('${monnaieRendue.toStringAsFixed(0)} FCFA',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: QuantisColors.success)),
                      ],
                    ),
                  ),

                if (resteAPayer > 0 && _moyenPaiement != 'CREDIT')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: QuantisColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: QuantisColors.warning),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Reste à payer (passera en crédit) :', style: TextStyle(fontWeight: FontWeight.bold, color: QuantisColors.warning)),
                        Text('${resteAPayer.toStringAsFixed(0)} FCFA',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: QuantisColors.warning)),
                      ],
                    ),
                  ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: QuantisColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: QuantisColors.warning),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.info, color: QuantisColors.warning, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'La totalité de la vente sera enregistrée à crédit sur le compte du client.',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Notes
              TextField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Notes ou Référence transaction (optionnel)',
                  prefixIcon: Icon(Icons.note_alt_outlined),
                ),
              ),
              const SizedBox(height: 24),

              // Boutons d'action
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      final double montantPaye = _moyenPaiement == 'CREDIT'
                          ? 0.0
                          : (_montantRecu >= widget.totalTtc ? widget.totalTtc : _montantRecu);

                      Navigator.pop(context, {
                        'moyenPaiement': _moyenPaiement,
                        'montantPaye': montantPaye,
                        'montantRecu': _montantRecu,
                        'notes': _notesCtrl.text.trim(),
                      });
                    },
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Valider & Imprimer Reçu'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: QuantisColors.royalBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
