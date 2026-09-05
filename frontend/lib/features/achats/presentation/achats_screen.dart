import 'package:flutter/material.dart';
import '../../../core/utils/permission_helper.dart';
import '../../../core/theme/quantis_theme.dart';
import '../data/achat_models.dart';
import '../data/achat_service.dart';
import 'commande_form_screen.dart';
import 'commande_detail_screen.dart';

/// Écran liste des commandes fournisseur.
class AchatsScreen extends StatefulWidget {
  const AchatsScreen({super.key});

  @override
  State<AchatsScreen> createState() => _AchatsScreenState();
}

class _AchatsScreenState extends State<AchatsScreen> {
  final AchatService _service = AchatService();
  List<CommandeModel> _commandes = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _commandes = await _service.getCommandes();
      setState(() => _loading = false);
    } catch (e) {
      setState(() { _loading = false; _error = 'Erreur: $e'; });
    }
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
        title: const Text('Commandes Fournisseur'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: PermissionHelper.hasPermission('CREER_ACHAT')
          ? FloatingActionButton.extended(
              onPressed: () async {
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const CommandeFormScreen()),
                );
                if (result == true) _load();
              },
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Nouvelle commande'),
              backgroundColor: QuantisColors.royalBlue,
              foregroundColor: Colors.white,
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _commandes.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shopping_cart_outlined, size: 64, color: QuantisColors.textMuted),
                          SizedBox(height: 8),
                          Text('Aucune commande', style: TextStyle(color: QuantisColors.textMuted)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _commandes.length,
                        itemBuilder: (_, i) {
                          final cmd = _commandes[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _statutColor(cmd.statut).withValues(alpha: 0.12),
                                child: Icon(_statutIcon(cmd.statut), color: _statutColor(cmd.statut)),
                              ),
                              title: Text(cmd.numero, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (cmd.fournisseurNom != null)
                                    Text(cmd.fournisseurNom!, style: const TextStyle(fontSize: 13)),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _statutColor(cmd.statut).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          cmd.statutLabel,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: _statutColor(cmd.statut),
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        '${cmd.totalHt.toStringAsFixed(0)} FCFA',
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              isThreeLine: true,
                              trailing: const Icon(Icons.chevron_right, color: QuantisColors.textMuted),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CommandeDetailScreen(commandeId: cmd.id!),
                                  ),
                                );
                                _load();
                              },
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
