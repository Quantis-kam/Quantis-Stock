import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/quantis_theme.dart';
import '../../../core/widgets/keyboard_safe_dialog.dart';

/// Dialogue d'encaissement rapide avec identification client OBLIGATOIRE en cas de crédit (total ou partiel).
class EncaissementDialog extends StatefulWidget {
  final double totalTtc;
  final int? selectedClientId;
  final String? clientNom;
  final List<dynamic> clients;

  const EncaissementDialog({
    super.key,
    required this.totalTtc,
    this.selectedClientId,
    this.clientNom,
    this.clients = const [],
  });

  @override
  State<EncaissementDialog> createState() => _EncaissementDialogState();
}

class _EncaissementDialogState extends State<EncaissementDialog> {
  String _moyenPaiement = 'ESPECES';
  final _montantRecuCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  // Identification client obligatoire si vente à crédit ou paiement partiel
  final _scrollCtrl = ScrollController();
  final _debtorSectionKey = GlobalKey();
  bool _wasNeedsDebtorForm = false;
  bool _useNewClient = true;
  int? _pickedExistingClientId;
  final _newClientNomCtrl = TextEditingController();
  final _newClientTelCtrl = TextEditingController();
  final _newClientAdresseCtrl = TextEditingController();
  String? _validationError;

  double _montantRecu = 0;

  final _moyens = const [
    {'code': 'ESPECES', 'label': 'Espèces', 'icon': Icons.payments},
    {'code': 'WAVE', 'label': 'Wave', 'icon': Icons.phone_android},
    {'code': 'ORANGE_MONEY', 'label': 'Orange Money', 'icon': Icons.account_balance_wallet},
    {'code': 'MOOV_MONEY', 'label': 'Moov Money', 'icon': Icons.send_to_mobile},
    {'code': 'CARTE_BANCAIRE', 'label': 'Carte Bancaire', 'icon': Icons.credit_card},
    {'code': 'CREDIT', 'label': 'À Crédit', 'icon': Icons.access_time},
  ];

  static bool _isAnonymousClientName(String? nom) {
    if (nom == null || nom.trim().isEmpty) return true;
    final lower = nom.toLowerCase();
    return lower.contains('client divers') || lower.contains('comptoir') || lower == 'anonyme';
  }

  List<dynamic> get _namedClients => widget.clients
      .where((c) => !_isAnonymousClientName(c['nom']?.toString()))
      .toList();

  bool get _hasPreselectedNamedClient =>
      widget.selectedClientId != null && !_isAnonymousClientName(widget.clientNom);

  @override
  void initState() {
    super.initState();
    _montantRecu = widget.totalTtc;
    _montantRecuCtrl.text = widget.totalTtc.toStringAsFixed(0);
    if (_hasPreselectedNamedClient) {
      _pickedExistingClientId = widget.selectedClientId;
      _useNewClient = false;
    } else {
      // Affiche directement les champs Nom & Contact (avec onglet Client existant à côté)
      _useNewClient = true;
    }
  }

  void _scrollToDebtorSection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _debtorSectionKey.currentContext;
      if (ctx != null && mounted) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.15,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _montantRecuCtrl.dispose();
    _notesCtrl.dispose();
    _newClientNomCtrl.dispose();
    _newClientTelCtrl.dispose();
    _newClientAdresseCtrl.dispose();
    super.dispose();
  }

  void _ajouterCoupure(double montant) {
    setState(() {
      _montantRecu += montant;
      _montantRecuCtrl.text = _montantRecu.toStringAsFixed(0);
      _validationError = null;
    });
  }

  void _setMontantExact() {
    setState(() {
      _montantRecu = widget.totalTtc;
      _montantRecuCtrl.text = _montantRecu.toStringAsFixed(0);
      _validationError = null;
    });
  }

  void _valider() {
    final double montantPaye = _moyenPaiement == 'CREDIT'
        ? 0.0
        : (_montantRecu >= widget.totalTtc ? widget.totalTtc : _montantRecu);
    final double resteAPayer = (widget.totalTtc - montantPaye).clamp(0.0, double.infinity);
    final bool isCreditSale = _moyenPaiement == 'CREDIT' || resteAPayer > 0.01;

    int? finalClientId = widget.selectedClientId;
    String? newNom;
    String? newTel;
    String? newAdr;

    if (isCreditSale && !_hasPreselectedNamedClient) {
      if (_useNewClient) {
        newNom = _newClientNomCtrl.text.trim();
        newTel = _newClientTelCtrl.text.trim();
        newAdr = _newClientAdresseCtrl.text.trim();
        if (newNom.isEmpty || newTel.isEmpty) {
          setState(() {
            _validationError =
                'Pour une vente à crédit, veuillez renseigner le Nom et le Téléphone du client.';
          });
          _scrollToDebtorSection();
          return;
        }
        finalClientId = null;
      } else {
        if (_pickedExistingClientId == null) {
          setState(() {
            _validationError =
                'Veuillez sélectionner un client existant ou basculer sur « Nouveau client ».';
          });
          _scrollToDebtorSection();
          return;
        }
        finalClientId = _pickedExistingClientId;
      }
    }

    Navigator.pop(context, {
      'moyenPaiement': _moyenPaiement,
      'montantPaye': montantPaye,
      'montantRecu': _montantRecu,
      'notes': _notesCtrl.text.trim(),
      'clientId': finalClientId,
      if (newNom != null && newNom.isNotEmpty) 'nouveauClientNom': newNom,
      if (newTel != null && newTel.isNotEmpty) 'nouveauClientTelephone': newTel,
      if (newAdr != null && newAdr.isNotEmpty) 'nouveauClientAdresse': newAdr,
    });
  }

  @override
  Widget build(BuildContext context) {
    final monnaie = ApiClient.entrepriseMonnaie;
    final double monnaieRendue = _montantRecu > widget.totalTtc ? (_montantRecu - widget.totalTtc) : 0;
    final double resteAPayer = _moyenPaiement == 'CREDIT'
        ? widget.totalTtc
        : (_montantRecu < widget.totalTtc ? (widget.totalTtc - _montantRecu) : 0);
    final bool isCreditSale = _moyenPaiement == 'CREDIT' || resteAPayer > 0.01;
    final bool needsDebtorForm = isCreditSale && !_hasPreselectedNamedClient;
    final namedClients = _namedClients;

    if (needsDebtorForm && !_wasNeedsDebtorForm) {
      _wasNeedsDebtorForm = true;
      _scrollToDebtorSection();
    } else if (!needsDebtorForm) {
      _wasNeedsDebtorForm = false;
    }

    return KeyboardSafeDialog(
      desktopWidth: 530,
      scrollController: _scrollCtrl,
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
              const Divider(height: 20),

              // Total à Encaisser Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
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
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${widget.totalTtc.toStringAsFixed(0)} $monnaie',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: QuantisColors.royalBlue),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Mode de Paiement Selector
              const Text('Mode de règlement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _moyens.map((m) {
                  final isSelected = _moyenPaiement == m['code'];
                  final isCreditChip = m['code'] == 'CREDIT';
                  return ChoiceChip(
                    avatar: Icon(
                      m['icon'] as IconData,
                      size: 16,
                      color: isSelected
                          ? Colors.white
                          : (isCreditChip ? Colors.orange.shade800 : QuantisColors.royalBlue),
                    ),
                    label: Text(m['label'] as String),
                    selected: isSelected,
                    selectedColor: isCreditChip ? Colors.orange.shade800 : QuantisColors.royalBlue,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _validationError = null;
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
              const SizedBox(height: 14),

              // Montant Reçu (si non crédit intégral)
              if (_moyenPaiement != 'CREDIT') ...[
                Row(
                  children: [
                    Expanded(
                      child: EnsureVisibleWhenFocused(
                        child: TextField(
                          controller: _montantRecuCtrl,
                          keyboardType: TextInputType.number,
                          scrollPadding: const EdgeInsets.only(top: 24, bottom: 160),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            labelText: 'Montant Donné par le Client',
                            suffixText: monnaie,
                            prefixIcon: const Icon(Icons.attach_money),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _montantRecu = double.tryParse(val.replaceAll(' ', '').replaceAll(',', '.')) ?? 0;
                              _validationError = null;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _setMontantExact,
                      child: const Text('Exact'),
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
                const SizedBox(height: 12),

                if (monnaieRendue > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: QuantisColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: QuantisColors.success),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text('Monnaie à rendre :', style: TextStyle(fontWeight: FontWeight.bold, color: QuantisColors.success)),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text('${monnaieRendue.toStringAsFixed(0)} $monnaie',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: QuantisColors.success)),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (resteAPayer > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: QuantisColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: QuantisColors.warning),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text('Reste à payer (passera en crédit) :',
                              style: TextStyle(fontWeight: FontWeight.bold, color: QuantisColors.warning, fontSize: 12.5)),
                        ),
                        Text('${resteAPayer.toStringAsFixed(0)} $monnaie',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: QuantisColors.warning)),
                      ],
                    ),
                  ),
              ],

              // =================== IDENTIFICATION CLIENT OBLIGATOIRE POUR CRÉDIT ===================
              if (isCreditSale) ...[
                const SizedBox(height: 12),
                if (_hasPreselectedNamedClient)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: QuantisColors.success.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: QuantisColors.success.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_user, color: QuantisColors.success, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Crédit de ${resteAPayer.toStringAsFixed(0)} $monnaie enregistré sur le compte de ${widget.clientNom}.',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    key: _debtorSectionKey,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade400, width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.person_search_rounded, color: Colors.orange.shade900, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Qui doit ce crédit ? (Obligatoire)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                  color: Colors.orange.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Identifiez le client pour pouvoir suivre et encaisser sa créance plus tard.',
                          style: TextStyle(fontSize: 11.5, color: Colors.orange.shade900.withValues(alpha: 0.85)),
                        ),
                        const SizedBox(height: 10),

                        // Choix rapide : Client existant / Nouveau client
                        Row(
                          children: [
                            Expanded(
                              child: ChoiceChip(
                                label: const Center(child: Text('Nouveau client')),
                                selected: _useNewClient,
                                selectedColor: QuantisColors.royalBlue,
                                labelStyle: TextStyle(
                                  color: _useNewClient ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                onSelected: (_) => setState(() {
                                  _useNewClient = true;
                                  _validationError = null;
                                }),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ChoiceChip(
                                label: Center(child: Text('Client existant (${namedClients.length})')),
                                selected: !_useNewClient,
                                selectedColor: QuantisColors.royalBlue,
                                labelStyle: TextStyle(
                                  color: !_useNewClient ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                onSelected: namedClients.isEmpty
                                    ? null
                                    : (_) => setState(() {
                                          _useNewClient = false;
                                          _validationError = null;
                                        }),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        if (_useNewClient) ...[
                          EnsureVisibleWhenFocused(
                            child: TextField(
                              controller: _newClientNomCtrl,
                              textCapitalization: TextCapitalization.words,
                              scrollPadding: const EdgeInsets.only(top: 24, bottom: 160),
                              decoration: const InputDecoration(
                                labelText: 'Nom complet du client *',
                                hintText: 'Ex: Moussa Ouédraogo',
                                prefixIcon: Icon(Icons.person_outline),
                                filled: true,
                                fillColor: Colors.white,
                                isDense: true,
                              ),
                              onChanged: (_) => setState(() => _validationError = null),
                            ),
                          ),
                          const SizedBox(height: 10),
                          EnsureVisibleWhenFocused(
                            child: TextField(
                              controller: _newClientTelCtrl,
                              keyboardType: TextInputType.phone,
                              scrollPadding: const EdgeInsets.only(top: 24, bottom: 160),
                              decoration: const InputDecoration(
                                labelText: 'Téléphone / Contact *',
                                hintText: 'Ex: 70 12 34 56',
                                prefixIcon: Icon(Icons.phone_outlined),
                                filled: true,
                                fillColor: Colors.white,
                                isDense: true,
                              ),
                              onChanged: (_) => setState(() => _validationError = null),
                            ),
                          ),
                          const SizedBox(height: 10),
                          EnsureVisibleWhenFocused(
                            child: TextField(
                              controller: _newClientAdresseCtrl,
                              scrollPadding: const EdgeInsets.only(top: 24, bottom: 160),
                              decoration: const InputDecoration(
                                labelText: 'Quartier / Adresse (optionnel)',
                                hintText: 'Ex: Gounghin, Ouaga',
                                prefixIcon: Icon(Icons.location_on_outlined),
                                filled: true,
                                fillColor: Colors.white,
                                isDense: true,
                              ),
                            ),
                          ),
                        ] else ...[
                          DropdownButtonFormField<int>(
                            value: _pickedExistingClientId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Sélectionnez le client *',
                              prefixIcon: Icon(Icons.people_outline),
                              filled: true,
                              fillColor: Colors.white,
                              isDense: true,
                            ),
                            items: namedClients.map((c) {
                              final tel = c['telephone']?.toString();
                              final label = (tel != null && tel.isNotEmpty)
                                  ? '${c['nom']} ($tel)'
                                  : '${c['nom']}';
                              return DropdownMenuItem<int>(
                                value: c['id'] as int,
                                child: Text(label, overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (val) => setState(() {
                              _pickedExistingClientId = val;
                              _validationError = null;
                            }),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],

              if (_validationError != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: QuantisColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: QuantisColors.error),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: QuantisColors.error, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _validationError!,
                          style: const TextStyle(color: QuantisColors.error, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // Notes
              EnsureVisibleWhenFocused(
                child: TextField(
                  controller: _notesCtrl,
                  scrollPadding: const EdgeInsets.only(top: 24, bottom: 160),
                  decoration: const InputDecoration(
                    labelText: 'Notes ou Référence transaction (optionnel)',
                    prefixIcon: Icon(Icons.note_alt_outlined),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Boutons d'action
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: ElevatedButton.icon(
                      onPressed: _valider,
                      icon: Icon(needsDebtorForm ? Icons.assignment_ind : Icons.check, size: 18),
                      label: Text(
                        isCreditSale ? 'Enregistrer le Crédit' : 'Valider & Reçu',
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isCreditSale ? Colors.orange.shade800 : QuantisColors.royalBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
    );
  }
}
