import 'package:flutter/material.dart';
import '../../../core/theme/quantis_theme.dart';
import '../../documents/data/document_models.dart';
import '../../achats/data/achat_models.dart';
import '../data/tiers_models.dart';
import '../data/tiers_service.dart';
import 'tiers_form_screen.dart';

class TiersDetailsScreen extends StatefulWidget {
  final bool isClient;
  final int id;

  const TiersDetailsScreen({
    super.key,
    required this.isClient,
    required this.id,
  });

  @override
  State<TiersDetailsScreen> createState() => _TiersDetailsScreenState();
}

class _TiersDetailsScreenState extends State<TiersDetailsScreen> {
  final TiersService _service = TiersService();
  bool _loadingDetails = true;
  bool _loadingTransactions = true;
  
  ClientModel? _client;
  FournisseurModel? _fournisseur;
  List<DocumentModel> _clientDocs = [];
  List<CommandeModel> _supplierCmds = [];
  
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loadingDetails = true;
      _loadingTransactions = true;
      _error = null;
    });

    try {
      if (widget.isClient) {
        _client = await _service.getClient(widget.id);
        setState(() => _loadingDetails = false);
        _clientDocs = await _service.getClientTransactions(widget.id);
      } else {
        _fournisseur = await _service.getFournisseur(widget.id);
        setState(() => _loadingDetails = false);
        _supplierCmds = await _service.getFournisseurTransactions(widget.id);
      }
      setState(() => _loadingTransactions = false);
    } catch (e) {
      setState(() {
        _loadingDetails = false;
        _loadingTransactions = false;
        _error = 'Erreur lors du chargement des informations: $e';
      });
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return dateStr;
    }
  }

  void _openEditForm() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TiersFormScreen(
          isClient: widget.isClient,
          client: _client,
          fournisseur: _fournisseur,
        ),
      ),
    );
    if (result == true) {
      _loadAll();
    }
  }

  void _confirmDelete() {
    final name = widget.isClient ? (_client?.nom ?? '') : (_fournisseur?.nom ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Désactiver $name'),
        content: Text('Êtes-vous sûr de vouloir désactiver ce ${widget.isClient ? "client" : "fournisseur"} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _loadingDetails = true);
              try {
                if (widget.isClient) {
                  await _service.deleteClient(widget.id);
                } else {
                  await _service.deleteFournisseur(widget.id);
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${widget.isClient ? "Client" : "Fournisseur"} désactivé avec succès'),
                      backgroundColor: QuantisColors.success,
                    ),
                  );
                  Navigator.pop(context, true);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erreur: $e'),
                      backgroundColor: QuantisColors.error,
                    ),
                  );
                  setState(() => _loadingDetails = false);
                }
              }
            },
            child: Text('Désactiver', style: TextStyle(color: QuantisColors.error)),
          ),
        ],
      ),
    );
  }

  void _adjustBalance() {
    final currentVal = widget.isClient ? (_client?.soldeCredit ?? 0.0) : (_fournisseur?.soldeDette ?? 0.0);
    final ctrl = TextEditingController(text: currentVal.toStringAsFixed(0));
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(widget.isClient ? 'Ajuster la créance' : 'Ajuster la dette'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Saisissez le nouveau solde en FCFA :',
              style: TextStyle(color: QuantisColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                suffixText: 'FCFA',
                hintText: 'Ex: 150000',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = double.tryParse(ctrl.text.trim());
              if (val == null) return;
              Navigator.pop(ctx);
              setState(() => _loadingDetails = true);
              try {
                if (widget.isClient && _client != null) {
                  final updated = _client!.copyWith(soldeCredit: val);
                  await _service.updateClient(_client!.id!, updated);
                } else if (!widget.isClient && _fournisseur != null) {
                  final updated = _fournisseur!.copyWith(soldeDette: val);
                  await _service.updateFournisseur(_fournisseur!.id!, updated);
                }
                _loadAll();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erreur: $e'),
                      backgroundColor: QuantisColors.error,
                    ),
                  );
                  setState(() => _loadingDetails = false);
                }
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isClient ? 'Fiche Client' : 'Fiche Fournisseur';
    final name = widget.isClient ? (_client?.nom ?? '') : (_fournisseur?.nom ?? '');
    
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (!_loadingDetails && _error == null) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Modifier',
              onPressed: _openEditForm,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: 'Désactiver',
              onPressed: _confirmDelete,
            ),
          ],
        ],
      ),
      body: _loadingDetails
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: QuantisColors.error),
                        const SizedBox(height: 12),
                        Text(_error!, style: TextStyle(color: QuantisColors.error), textAlign: TextAlign.center),
                        const SizedBox(height: 20),
                        ElevatedButton(onPressed: _loadAll, child: const Text('Réessayer')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAll,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // En-tête / Profil
                        _buildProfileCard(name),
                        
                        // Solde / Balance
                        _buildBalanceCard(),
                        
                        // Section Transactions
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                          child: Text(
                            'Historique des Transactions',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: QuantisColors.textPrimary,
                                ),
                          ),
                        ),
                        
                        _loadingTransactions
                            ? const Padding(
                                padding: EdgeInsets.all(40),
                                child: Center(child: CircularProgressIndicator()),
                              )
                            : widget.isClient
                                ? _buildClientTransactions()
                                : _buildSupplierTransactions(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildProfileCard(String name) {
    final tel = widget.isClient ? _client?.telephone : _fournisseur?.telephone;
    final email = widget.isClient ? _client?.email : _fournisseur?.email;
    final adresse = widget.isClient ? _client?.adresse : _fournisseur?.adresse;
    final notes = widget.isClient ? _client?.notes : _fournisseur?.notes;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
        border: Border.all(color: QuantisColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: widget.isClient
                    ? QuantisColors.royalBlue.withValues(alpha: 0.1)
                    : QuantisColors.luxuryGold.withValues(alpha: 0.15),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: widget.isClient ? QuantisColors.royalBlue : QuantisColors.luxuryGold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: QuantisColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: (widget.isClient ? (_client?.actif ?? true) : (_fournisseur?.actif ?? true))
                            ? QuantisColors.success.withValues(alpha: 0.1)
                            : QuantisColors.textMuted.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        (widget.isClient ? (_client?.actif ?? true) : (_fournisseur?.actif ?? true))
                            ? 'Actif'
                            : 'Désactivé',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: (widget.isClient ? (_client?.actif ?? true) : (_fournisseur?.actif ?? true))
                              ? QuantisColors.success
                              : QuantisColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          
          if (tel != null && tel.isNotEmpty) ...[
            _buildInfoRow(Icons.phone_outlined, 'Téléphone', tel),
            const SizedBox(height: 12),
          ],
          if (email != null && email.isNotEmpty) ...[
            _buildInfoRow(Icons.email_outlined, 'Email', email),
            const SizedBox(height: 12),
          ],
          if (adresse != null && adresse.isNotEmpty) ...[
            _buildInfoRow(Icons.location_on_outlined, 'Adresse', adresse),
            const SizedBox(height: 12),
          ],
          if (notes != null && notes.isNotEmpty) ...[
            _buildInfoRow(Icons.notes_outlined, 'Notes', notes),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: QuantisColors.textMuted),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: QuantisColors.textMuted),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 14, color: QuantisColors.textPrimary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceCard() {
    final isClient = widget.isClient;
    final balance = isClient ? (_client?.soldeCredit ?? 0.0) : (_fournisseur?.soldeDette ?? 0.0);
    final cardColor = isClient ? QuantisColors.warning : QuantisColors.error;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cardColor,
            cardColor.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: cardColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isClient ? 'CRÉANCE EN COURS' : 'DETTE EN COURS',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.1,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_note, color: Colors.white),
                tooltip: 'Ajuster le solde',
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
                onPressed: _adjustBalance,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${balance.toStringAsFixed(0)} FCFA',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isClient 
                ? 'Cette valeur correspond à la somme totale des factures en attente de paiement.'
                : 'Cette valeur correspond au total des réceptions de marchandises non payées.',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientTransactions() {
    if (_clientDocs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Text('Aucune transaction trouvée pour ce client', style: TextStyle(color: QuantisColors.textMuted)),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _clientDocs.length,
      itemBuilder: (ctx, i) {
        final doc = _clientDocs[i];
        
        Color statusColor;
        switch (doc.statut) {
          case 'VALIDE':
            statusColor = QuantisColors.success;
            break;
          case 'ANNULE':
            statusColor = QuantisColors.error;
            break;
          default:
            statusColor = QuantisColors.warning;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      doc.numero,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: QuantisColors.textPrimary),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        doc.statutLabel,
                        style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Type: ${doc.typeLabel}',
                      style: const TextStyle(fontSize: 12, color: QuantisColors.textSecondary),
                    ),
                    Text(
                      _formatDate(doc.dateDocument),
                      style: const TextStyle(fontSize: 12, color: QuantisColors.textMuted),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total TTC: ${doc.totalTtc.toStringAsFixed(0)} FCFA',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: QuantisColors.textPrimary),
                    ),
                    Text(
                      'Reste: ${doc.soldeRestant.toStringAsFixed(0)} FCFA',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: doc.soldeRestant > 0 ? QuantisColors.warning : QuantisColors.success,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSupplierTransactions() {
    if (_supplierCmds.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Text('Aucun achat trouvé pour ce fournisseur', style: TextStyle(color: QuantisColors.textMuted)),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _supplierCmds.length,
      itemBuilder: (ctx, i) {
        final cmd = _supplierCmds[i];
        
        Color statusColor;
        switch (cmd.statut) {
          case 'RECUE':
            statusColor = QuantisColors.success;
            break;
          case 'RECUE_PARTIELLE':
            statusColor = QuantisColors.warning;
            break;
          case 'ANNULEE':
            statusColor = QuantisColors.error;
            break;
          case 'EN_COURS':
            statusColor = QuantisColors.royalBlue;
            break;
          default:
            statusColor = QuantisColors.textMuted;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      cmd.numero,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: QuantisColors.textPrimary),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        cmd.statutLabel,
                        style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Dépôt: ${cmd.depotNom ?? ""}',
                      style: const TextStyle(fontSize: 12, color: QuantisColors.textSecondary),
                    ),
                    Text(
                      _formatDate(cmd.dateCommande),
                      style: const TextStyle(fontSize: 12, color: QuantisColors.textMuted),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Montant Total HT :', style: TextStyle(fontSize: 13)),
                    Text(
                      '${cmd.totalHt.toStringAsFixed(0)} FCFA',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: QuantisColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
