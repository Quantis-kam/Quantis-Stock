import 'package:flutter/material.dart';
import '../../../core/theme/quantis_theme.dart';
import '../../../core/utils/permission_helper.dart';
import '../data/achat_models.dart';
import '../data/achat_service.dart';

/// Écran détail d'une commande fournisseur avec actions et réception.
class CommandeDetailScreen extends StatefulWidget {
  final int commandeId;
  const CommandeDetailScreen({super.key, required this.commandeId});

  @override
  State<CommandeDetailScreen> createState() => _CommandeDetailScreenState();
}

class _CommandeDetailScreenState extends State<CommandeDetailScreen> {
  final AchatService _service = AchatService();
  CommandeModel? _commande;
  bool _loading = true;
  bool _actionLoading = false;
  bool _receptionMode = false;

  // Contrôleurs pour les quantités reçues (par index de ligne)
  final Map<int, TextEditingController> _qtyControllers = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (var c in _qtyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _commande = await _service.getCommande(widget.commandeId);
      // Initialiser les contrôleurs pour chaque ligne
      _qtyControllers.clear();
      for (int i = 0; i < (_commande?.lignes.length ?? 0); i++) {
        _qtyControllers[i] = TextEditingController();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: QuantisColors.error),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _valider() async {
    setState(() => _actionLoading = true);
    try {
      await _service.valider(widget.commandeId);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Commande validée'), backgroundColor: QuantisColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: QuantisColors.error),
        );
      }
    }
    if (mounted) setState(() => _actionLoading = false);
  }

  Future<void> _annuler() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Annuler la commande ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Non')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Oui, annuler', style: TextStyle(color: QuantisColors.error)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _actionLoading = true);
    try {
      await _service.annuler(widget.commandeId);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Commande annulée'), backgroundColor: QuantisColors.warning),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: QuantisColors.error),
        );
      }
    }
    if (mounted) setState(() => _actionLoading = false);
  }

  Future<void> _submitReception() async {
    final lignes = <Map<String, dynamic>>[];
    for (int i = 0; i < (_commande?.lignes.length ?? 0); i++) {
      final qty = double.tryParse(_qtyControllers[i]?.text ?? '') ?? 0;
      if (qty > 0 && _commande!.lignes[i].id != null) {
        lignes.add({
          'ligneCommandeId': _commande!.lignes[i].id,
          'quantiteRecue': qty,
        });
      }
    }

    if (lignes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saisissez au moins une quantité reçue'), backgroundColor: QuantisColors.error),
      );
      return;
    }

    setState(() => _actionLoading = true);
    try {
      await _service.receptionner(widget.commandeId, {'lignes': lignes});
      setState(() => _receptionMode = false);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Réception enregistrée — Stock mis à jour'), backgroundColor: QuantisColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: QuantisColors.error),
        );
      }
    }
    if (mounted) setState(() => _actionLoading = false);
  }

  Color _statutColor(String statut) => switch (statut) {
        'BROUILLON' => QuantisColors.textMuted,
        'EN_COURS' => QuantisColors.info,
        'RECUE_PARTIELLE' => QuantisColors.warning,
        'RECUE' => QuantisColors.success,
        'ANNULEE' => QuantisColors.error,
        _ => QuantisColors.textMuted,
      };

  IconData _statutIcon(String statut) => switch (statut) {
        'BROUILLON' => Icons.edit_note,
        'EN_COURS' => Icons.local_shipping,
        'RECUE_PARTIELLE' => Icons.indeterminate_check_box_outlined,
        'RECUE' => Icons.check_circle,
        'ANNULEE' => Icons.cancel,
        _ => Icons.help_outline,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_commande?.numero ?? 'Chargement...'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _commande == null
              ? const Center(child: Text('Commande introuvable'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // === HEADER ===
                      _buildHeader(),
                      const SizedBox(height: 16),

                      // === ACTIONS ===
                      if (!_receptionMode) _buildActions(),
                      const SizedBox(height: 16),

                      // === LIGNES ===
                      const Text('Lignes de commande',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      ..._buildLignes(),

                      // === TOTAL ===
                      const SizedBox(height: 16),
                      _buildTotal(),

                      // === BOUTON RECEPTION ===
                      if (_receptionMode) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => setState(() => _receptionMode = false),
                                child: const Text('Annuler'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _actionLoading ? null : _submitReception,
                                icon: _actionLoading
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(Icons.check),
                                label: const Text('Valider Réception'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: QuantisColors.success,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeader() {
    final cmd = _commande!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_statutIcon(cmd.statut), color: _statutColor(cmd.statut), size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(cmd.numero,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statutColor(cmd.statut).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    cmd.statutLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _statutColor(cmd.statut),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _infoRow(Icons.business, 'Fournisseur', cmd.fournisseurNom ?? '—'),
            _infoRow(Icons.warehouse, 'Dépôt', cmd.depotNom ?? '—'),
            if (cmd.dateCommande != null)
              _infoRow(Icons.calendar_today, 'Date commande', cmd.dateCommande!),
            if (cmd.dateLivraisonPrevue != null)
              _infoRow(Icons.event, 'Livraison prévue', cmd.dateLivraisonPrevue!),
            if (cmd.notes != null && cmd.notes!.isNotEmpty)
              _infoRow(Icons.notes, 'Notes', cmd.notes!),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: QuantisColors.textMuted),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(color: QuantisColors.textMuted, fontSize: 13)),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildActions() {
    final cmd = _commande!;
    final canValidate = cmd.canValidate && PermissionHelper.hasPermission('CREER_ACHAT');
    final canReceive = cmd.canReceive && PermissionHelper.hasPermission('RECEPTIONNER_ACHAT');
    final canCancel = cmd.canCancel && PermissionHelper.hasPermission('CREER_ACHAT');

    if (!canValidate && !canReceive && !canCancel) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (canValidate)
          ElevatedButton.icon(
            onPressed: _actionLoading ? null : _valider,
            icon: const Icon(Icons.verified, size: 18),
            label: const Text('Valider'),
            style: ElevatedButton.styleFrom(
              backgroundColor: QuantisColors.royalBlue,
              foregroundColor: Colors.white,
            ),
          ),
        if (canReceive)
          ElevatedButton.icon(
            onPressed: () => setState(() => _receptionMode = true),
            icon: const Icon(Icons.inventory, size: 18),
            label: const Text('Réceptionner'),
            style: ElevatedButton.styleFrom(
              backgroundColor: QuantisColors.success,
              foregroundColor: Colors.white,
            ),
          ),
        if (canCancel)
          OutlinedButton.icon(
            onPressed: _actionLoading ? null : _annuler,
            icon: const Icon(Icons.cancel, size: 18),
            label: const Text('Annuler'),
            style: OutlinedButton.styleFrom(foregroundColor: QuantisColors.error),
          ),
      ],
    );
  }

  List<Widget> _buildLignes() {
    final cmd = _commande!;
    return List.generate(cmd.lignes.length, (i) {
      final ligne = cmd.lignes[i];
      final hasEcart = ligne.quantiteRecue > 0 && !ligne.isComplete;
      final isComplete = ligne.isComplete;

      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isComplete
                ? QuantisColors.success.withValues(alpha: 0.4)
                : hasEcart
                    ? QuantisColors.warning.withValues(alpha: 0.4)
                    : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Produit nom
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ligne.produitNom ?? 'Produit #${ligne.produitId}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                  if (isComplete)
                    const Icon(Icons.check_circle, color: QuantisColors.success, size: 20)
                  else if (hasEcart)
                    const Icon(Icons.warning_amber, color: QuantisColors.warning, size: 20),
                ],
              ),
              const SizedBox(height: 8),

              // Quantités
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _qtyChip('Commandée', ligne.quantiteCommandee, QuantisColors.royalBlue),
                  _qtyChip('Reçue', ligne.quantiteRecue,
                      isComplete ? QuantisColors.success : QuantisColors.warning),
                  if (ligne.quantiteRestante > 0)
                    _qtyChip('Restante', ligne.quantiteRestante, QuantisColors.error),
                ],
              ),
              const SizedBox(height: 8),

              // Prix
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${ligne.prixUnitaire.toStringAsFixed(0)} FCFA/unité',
                      style: const TextStyle(fontSize: 12, color: QuantisColors.textMuted)),
                  Text('${ligne.montantTotal.toStringAsFixed(0)} FCFA',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),

              // Champ réception
              if (_receptionMode && ligne.quantiteRestante > 0) ...[
                const Divider(height: 16),
                Row(
                  children: [
                    const Icon(Icons.input, size: 16, color: QuantisColors.success),
                    const SizedBox(width: 8),
                    const Text('Qté reçue:', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 100,
                      child: TextField(
                        controller: _qtyControllers[i],
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: '0',
                          suffixText: '/ ${ligne.quantiteRestante.toStringAsFixed(0)}',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    });
  }

  Widget _qtyChip(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(value.toStringAsFixed(0),
              style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 14)),
          Text(label, style: TextStyle(fontSize: 10, color: color)),
        ],
      ),
    );
  }

  Widget _buildTotal() {
    return Card(
      color: QuantisColors.royalBlue.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total HT', style: TextStyle(fontSize: 12, color: QuantisColors.textMuted)),
                Text(
                  '${_commande!.totalHt.toStringAsFixed(0)} FCFA',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: QuantisColors.royalBlue),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('Lignes', style: TextStyle(fontSize: 12, color: QuantisColors.textMuted)),
                Text('${_commande!.lignes.length}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
