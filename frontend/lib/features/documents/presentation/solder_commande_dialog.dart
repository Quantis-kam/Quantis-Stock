import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/quantis_theme.dart';
import '../../../core/widgets/keyboard_safe_dialog.dart';
import '../../sales/presentation/ticket_receipt_dialog.dart';
import '../data/document_models.dart';

/// Dialogue simple en 1 étape pour valider, déstocker, facturer et solder une Commande Client.
/// Si un reliquat reste à crédit sur un client anonyme (ex. Client Divers), affiche directement
/// le formulaire d'identification client (Nom + Téléphone ou sélection d'un client existant).
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
  final _scrollCtrl = ScrollController();
  final _debtorSectionKey = GlobalKey();
  final _montantCtrl = TextEditingController();
  final _refCtrl = TextEditingController();

  // Identification client à la volée si reste à crédit sur Client Divers / Comptoir
  List<dynamic> _namedClients = [];
  bool _loadingClients = false;
  bool _useNewClient = true;
  int? _pickedExistingClientId;
  final _newClientNomCtrl = TextEditingController();
  final _newClientTelCtrl = TextEditingController();
  final _newClientAdresseCtrl = TextEditingController();
  String? _validationError;
  bool _wasNeedsDebtorForm = false;

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

  static bool _isAnonymousClientName(String? nom) {
    if (nom == null || nom.trim().isEmpty) return true;
    final lower = nom.toLowerCase();
    return lower.contains('client divers') || lower.contains('comptoir') || lower == 'anonyme';
  }

  bool get _hasAnonymousOrderClient => _isAnonymousClientName(widget.commande.clientNom);

  String _formatMontant(num amount) {
    return NumberFormat('#,##0', 'fr_FR')
        .format(amount.round())
        .replaceAll('\u202F', ' ')
        .replaceAll('\u00A0', ' ');
  }

  @override
  void initState() {
    super.initState();
    _montantPaye = widget.commande.totalTtc;
    _montantCtrl.text = widget.commande.totalTtc.toStringAsFixed(0);
    if (_hasAnonymousOrderClient) {
      _loadNamedClients();
    }
  }

  Future<void> _loadNamedClients() async {
    setState(() => _loadingClients = true);
    try {
      final res = await _api.get('/clients?size=100');
      final list = (res.data['data']?['content'] as List?) ?? [];
      final named = list.where((c) => !_isAnonymousClientName(c['nom']?.toString())).toList();
      if (mounted) {
        setState(() {
          _namedClients = named;
          _loadingClients = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingClients = false);
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
    _montantCtrl.dispose();
    _refCtrl.dispose();
    _newClientNomCtrl.dispose();
    _newClientTelCtrl.dispose();
    _newClientAdresseCtrl.dispose();
    super.dispose();
  }

  Future<void> _validerEtSolder() async {
    final double montant = _moyenPaiement == 'CREDIT'
        ? 0.0
        : (double.tryParse(_montantCtrl.text.trim().replaceAll(' ', '').replaceAll(',', '.')) ?? widget.commande.totalTtc);
    final double reste = _moyenPaiement == 'CREDIT'
        ? widget.commande.totalTtc
        : (widget.commande.totalTtc - montant).clamp(0.0, double.infinity);
    final bool needsDebtorForm = reste > 0.01 && _hasAnonymousOrderClient;

    int? overrideClientId;
    String? newNom;
    String? newTel;
    String? newAdr;

    if (needsDebtorForm) {
      if (_useNewClient) {
        newNom = _newClientNomCtrl.text.trim();
        newTel = _newClientTelCtrl.text.trim();
        newAdr = _newClientAdresseCtrl.text.trim();
        if (newNom.isEmpty || newTel.isEmpty) {
          setState(() {
            _validationError =
                'Veuillez renseigner le Nom et le Téléphone du client pour enregistrer ce crédit.';
          });
          _scrollToDebtorSection();
          return;
        }
      } else {
        if (_pickedExistingClientId == null) {
          setState(() {
            _validationError =
                'Veuillez sélectionner un client existant ou basculer sur « Nouveau client ».';
          });
          _scrollToDebtorSection();
          return;
        }
        overrideClientId = _pickedExistingClientId;
      }
    }

    setState(() {
      _saving = true;
      _validationError = null;
    });
    try {
      final res = await _api.post('/documents/${widget.commande.id}/solder-commande', data: {
        'moyenPaiement': _moyenPaiement,
        'montantPaye': montant,
        'montantRecu': montant,
        'reference': _refCtrl.text.trim(),
        if (overrideClientId != null) 'clientId': overrideClientId,
        if (newNom != null && newNom.isNotEmpty) 'nouveauClientNom': newNom,
        if (newTel != null && newTel.isNotEmpty) 'nouveauClientTelephone': newTel,
        if (newAdr != null && newAdr.isNotEmpty) 'nouveauClientAdresse': newAdr,
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
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 60;
    final reste = _moyenPaiement == 'CREDIT'
        ? widget.commande.totalTtc
        : (widget.commande.totalTtc - _montantPaye).clamp(0.0, double.infinity);
    final bool needsDebtorForm = reste > 0.01 && _hasAnonymousOrderClient;

    if (needsDebtorForm && !_wasNeedsDebtorForm) {
      _wasNeedsDebtorForm = true;
      _scrollToDebtorSection();
    } else if (!needsDebtorForm) {
      _wasNeedsDebtorForm = false;
    }

    return KeyboardSafeDialog(
      desktopWidth: 520,
      scrollController: _scrollCtrl,
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
                child: const Icon(Icons.task_alt_rounded, color: QuantisColors.success, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Valider & Solder ${widget.commande.numero}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('Client : ${widget.commande.clientNom ?? "Client Divers / Comptoir"}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),

          // Masquer le bandeau décoratif pendant la saisie clavier mobile pour maximiser la visibilité
          if (!keyboardOpen) ...[
            const SizedBox(height: 10),
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
          ],
          const SizedBox(height: 12),

          // Montant total commande
          Container(
            padding: EdgeInsets.all(keyboardOpen ? 10 : 14),
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
                      '${_formatMontant(widget.commande.totalTtc)} $monnaie',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19, color: QuantisColors.royalBlue),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

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
                      _validationError = null;
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
          const SizedBox(height: 12),

          if (_moyenPaiement != 'CREDIT') ...[
            EnsureVisibleWhenFocused(
              child: TextField(
                controller: _montantCtrl,
                keyboardType: TextInputType.number,
                scrollPadding: const EdgeInsets.only(top: 24, bottom: 160),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'Montant encaissé ($monnaie)',
                  prefixIcon: const Icon(Icons.money),
                  suffixText: monnaie,
                ),
                onChanged: (v) => setState(() {
                  _montantPaye = double.tryParse(v.replaceAll(' ', '').replaceAll(',', '.')) ?? 0;
                  _validationError = null;
                }),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Si crédit/partiel sur client déjà identifié -> simple info
          if (reste > 0.01 && !_hasAnonymousOrderClient)
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
                      'Reste de ${_formatMontant(reste)} $monnaie enregistré dans les créances de ${widget.commande.clientNom}.',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

          // =================== IDENTIFICATION CLIENT À LA VOLÉE SI CRÉDIT SUR COMPTOIR ===================
          if (needsDebtorForm)
            Container(
              key: _debtorSectionKey,
              padding: const EdgeInsets.all(12),
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
                      Icon(Icons.person_add_alt_1_rounded, color: Colors.orange.shade900, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Qui doit les ${_formatMontant(reste)} $monnaie ?',
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
                    'Renseignez le nom et le contact du client (ou sélectionnez-le) pour suivre cette créance.',
                    style: TextStyle(fontSize: 11.5, color: Colors.orange.shade900.withValues(alpha: 0.85)),
                  ),
                  const SizedBox(height: 10),
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
                          label: Center(
                            child: Text(
                              _loadingClients
                                  ? 'Clients...'
                                  : 'Client existant (${_namedClients.length})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          selected: !_useNewClient,
                          selectedColor: QuantisColors.royalBlue,
                          labelStyle: TextStyle(
                            color: !_useNewClient ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          onSelected: _namedClients.isEmpty
                              ? null
                              : (_) => setState(() {
                                    _useNewClient = false;
                                    _validationError = null;
                                  }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
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
                    const SizedBox(height: 8),
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
                    const SizedBox(height: 8),
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
                      items: _namedClients.map((c) {
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

          const SizedBox(height: 12),
          EnsureVisibleWhenFocused(
            child: TextField(
              controller: _refCtrl,
              scrollPadding: const EdgeInsets.only(top: 24, bottom: 160),
              decoration: const InputDecoration(
                labelText: 'Référence paiement / Note (optionnel)',
                prefixIcon: Icon(Icons.receipt_outlined),
              ),
            ),
          ),
          const SizedBox(height: 18),

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
                      : Icon(needsDebtorForm ? Icons.assignment_ind : Icons.check_circle, size: 18),
                  label: Text(
                    reste <= 0.01 ? 'Valider & Solder' : 'Facturer & Enregistrer',
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: reste <= 0.01 ? QuantisColors.success : Colors.orange.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
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
