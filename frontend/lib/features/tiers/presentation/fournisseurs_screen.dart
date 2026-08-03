import 'package:flutter/material.dart';
import '../../../core/theme/quantis_theme.dart';
import '../data/tiers_models.dart';
import '../data/tiers_service.dart';
import 'tiers_form_screen.dart';

/// Écran liste des fournisseurs avec CRUD.
class FournisseursScreen extends StatefulWidget {
  const FournisseursScreen({super.key});

  @override
  State<FournisseursScreen> createState() => _FournisseursScreenState();
}

class _FournisseursScreenState extends State<FournisseursScreen> {
  final TiersService _service = TiersService();
  List<FournisseurModel> _fournisseurs = [];
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
      _fournisseurs = await _service.getFournisseurs();
      setState(() => _loading = false);
    } catch (e) {
      setState(() { _loading = false; _error = 'Erreur: $e'; });
    }
  }

  void _openForm({FournisseurModel? fournisseur}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TiersFormScreen(
          isClient: false,
          fournisseur: fournisseur,
        ),
      ),
    );
    if (result == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fournisseurs'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_business),
        label: const Text('Nouveau fournisseur'),
        backgroundColor: QuantisColors.royalBlue,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _fournisseurs.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.business_outlined, size: 64, color: QuantisColors.textMuted),
                          SizedBox(height: 8),
                          Text('Aucun fournisseur', style: TextStyle(color: QuantisColors.textMuted)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _fournisseurs.length,
                        itemBuilder: (_, i) => _FournisseurTile(
                          fournisseur: _fournisseurs[i],
                          onTap: () => _openForm(fournisseur: _fournisseurs[i]),
                        ),
                      ),
                    ),
    );
  }
}

class _FournisseurTile extends StatelessWidget {
  final FournisseurModel fournisseur;
  final VoidCallback onTap;

  const _FournisseurTile({required this.fournisseur, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasDette = fournisseur.soldeDette > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: QuantisColors.luxuryGold.withValues(alpha: 0.15),
          child: const Icon(Icons.business, color: QuantisColors.luxuryGold),
        ),
        title: Text(fournisseur.nom, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          [
            if (fournisseur.telephone != null) fournisseur.telephone!,
            if (fournisseur.email != null) fournisseur.email!,
          ].join(' • '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13),
        ),
        trailing: hasDette
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: QuantisColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${fournisseur.soldeDette.toStringAsFixed(0)} FCFA',
                  style: const TextStyle(
                    color: QuantisColors.error,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              )
            : const Icon(Icons.chevron_right, color: QuantisColors.textMuted),
      ),
    );
  }
}
