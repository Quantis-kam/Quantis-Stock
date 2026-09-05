import 'package:flutter/material.dart';
import '../../../core/utils/permission_helper.dart';
import '../../../core/theme/quantis_theme.dart';
import '../data/tiers_models.dart';
import '../data/tiers_service.dart';
import 'tiers_form_screen.dart';
import 'tiers_details_screen.dart';

/// Écran liste des fournisseurs avec recherche et CRUD.
class FournisseursScreen extends StatefulWidget {
  const FournisseursScreen({super.key});

  @override
  State<FournisseursScreen> createState() => _FournisseursScreenState();
}

class _FournisseursScreenState extends State<FournisseursScreen> {
  final TiersService _service = TiersService();
  final TextEditingController _searchController = TextEditingController();

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

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      _load();
      return;
    }
    setState(() => _loading = true);
    try {
      _fournisseurs = await _service.searchFournisseurs(query);
      setState(() => _loading = false);
    } catch (e) {
      setState(() { _loading = false; _error = 'Erreur de recherche'; });
    }
  }

  void _openDetails(FournisseurModel fournisseur) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TiersDetailsScreen(
          isClient: false,
          id: fournisseur.id!,
        ),
      ),
    );
    if (result == true) _load();
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
      floatingActionButton: PermissionHelper.hasPermission('CRUD_FOURNISSEURS')
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add_business),
              label: const Text('Nouveau fournisseur'),
              backgroundColor: QuantisColors.royalBlue,
              foregroundColor: Colors.white,
            )
          : null,
      body: Column(
        children: [
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _search,
              decoration: InputDecoration(
                hintText: 'Rechercher par nom ou téléphone...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _load();
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Liste
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline, size: 48, color: QuantisColors.error),
                            const SizedBox(height: 8),
                            Text(_error!, style: TextStyle(color: QuantisColors.error)),
                            const SizedBox(height: 16),
                            ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
                          ],
                        ),
                      )
                    : _fournisseurs.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.business_outlined, size: 64, color: QuantisColors.textMuted),
                                SizedBox(height: 8),
                                Text('Aucun fournisseur trouvé', style: TextStyle(color: QuantisColors.textMuted)),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _fournisseurs.length,
                              itemBuilder: (_, i) => _FournisseurTile(
                                fournisseur: _fournisseurs[i],
                                onTap: () => _openDetails(_fournisseurs[i]),
                              ),
                            ),
                          ),
          ),
        ],
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
