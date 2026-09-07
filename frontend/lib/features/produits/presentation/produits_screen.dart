import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/quantis_theme.dart';
import '../../../core/utils/permission_helper.dart';
import '../data/produit_service.dart';
import '../data/categorie_service.dart';
import 'produit_form_dialog.dart';
import 'csv_import_dialog.dart';

/// Écran catalogue produits — liste avec recherche, prix, marge et gestion des catégories.
class ProduitsScreen extends StatefulWidget {
  const ProduitsScreen({super.key});

  @override
  State<ProduitsScreen> createState() => _ProduitsScreenState();
}

class _ProduitsScreenState extends State<ProduitsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ProduitService _service = ProduitService();
  final CategorieService _categorieService = CategorieService();
  final TextEditingController _searchCtrl = TextEditingController();

  List<ProduitModel> _produits = [];
  List<CategorieModel> _categoriesTree = [];
  
  bool _loadingProducts = true;
  bool _loadingCategories = true;
  String? _productsError;
  String? _categoriesError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Met à jour le FAB en fonction de l'onglet actif
    });
    _load();
    _loadCategories();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({String? search}) async {
    setState(() { _loadingProducts = true; _productsError = null; });
    try {
      final prds = await _service.getProduits(search: search);
      setState(() {
        _produits = prds;
        _loadingProducts = false;
      });
    } catch (e) {
      setState(() { _loadingProducts = false; _productsError = 'Erreur: $e'; });
    }
  }

  Future<void> _loadCategories() async {
    setState(() { _loadingCategories = true; _categoriesError = null; });
    try {
      final cats = await _categorieService.getRoots();
      setState(() {
        _categoriesTree = cats;
        _loadingCategories = false;
      });
    } catch (e) {
      setState(() { _loadingCategories = false; _categoriesError = 'Erreur: $e'; });
    }
  }

  void _openAddProductForm() async {
    final success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const ProduitFormDialog(),
    );
    if (success == true) {
      _load();
    }
  }

  void _openEditProductForm(ProduitModel prod) async {
    final success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ProduitFormDialog(produit: prod),
    );
    if (success == true) {
      _load();
    }
  }

  void _openImportCsv() async {
    final count = await showDialog<int>(
      context: context,
      builder: (ctx) => const CsvImportDialog(),
    );
    if (count != null && count > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$count produit(s) importé(s) avec succès !'),
          backgroundColor: QuantisColors.success,
        ),
      );
      _load();
      _loadCategories(); // Des catégories peuvent avoir été créées
    }
  }

  List<CategorieModel> _flatCategories([int? excludeId]) {
    List<CategorieModel> flat = [];
    void traverse(CategorieModel cat) {
      if (excludeId != null && cat.id == excludeId) return;
      flat.add(cat);
      for (var sub in cat.sousCategories) {
        traverse(sub);
      }
    }
    for (var root in _categoriesTree) {
      traverse(root);
    }
    return flat;
  }

  void _openCategoryForm([CategorieModel? cat]) {
    final nomCtrl = TextEditingController(text: cat?.nom ?? '');
    final descCtrl = TextEditingController(text: cat?.description ?? '');
    int? parentId = cat?.parentId;
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(cat == null ? 'Ajouter une catégorie' : 'Modifier la catégorie'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nomCtrl,
                  decoration: const InputDecoration(labelText: 'Nom de la catégorie *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  value: parentId,
                  decoration: const InputDecoration(labelText: 'Catégorie parente'),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Aucune (Racine)')),
                    ..._flatCategories(cat?.id).map((c) => DropdownMenuItem<int?>(value: c.id, child: Text(c.nom))),
                  ],
                  onChanged: (val) => setDialogState(() => parentId = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: QuantisColors.royalBlue, foregroundColor: Colors.white),
              onPressed: saving
                  ? null
                  : () async {
                      if (nomCtrl.text.trim().isEmpty) return;
                      setDialogState(() => saving = true);
                      try {
                        final newCat = CategorieModel(
                          id: cat?.id,
                          nom: nomCtrl.text.trim(),
                          description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                          parentId: parentId,
                        );
                        if (cat == null) {
                          await _categorieService.create(newCat);
                        } else {
                          await _categorieService.update(cat.id!, newCat);
                        }
                        Navigator.pop(ctx);
                        _loadCategories();
                      } catch (e) {
                        setDialogState(() => saving = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erreur: $e'), backgroundColor: QuantisColors.error),
                        );
                      }
                    },
              child: saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteCategory(CategorieModel cat) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la catégorie ?'),
        content: Text('Voulez-vous vraiment supprimer la catégorie "${cat.nom}" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: QuantisColors.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _categorieService.delete(cat.id!);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Catégorie supprimée avec succès'), backgroundColor: QuantisColors.success),
        );
        _loadCategories();
      } catch (e) {
        String msg = e.toString();
        if (e is DioException && e.response?.data != null) {
          msg = e.response?.data['message'] ?? msg;
        }
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Impossible de supprimer'),
            content: Text(msg),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
            ],
          ),
        );
      }
    }
  }

  Widget _buildCategoryTile(CategorieModel cat) {
    if (cat.sousCategories.isEmpty) {
      return ListTile(
        contentPadding: const EdgeInsets.only(left: 16, right: 8),
        title: Text(cat.nom, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: cat.description != null ? Text(cat.description!) : null,
        trailing: PermissionHelper.hasPermission('GERER_CATEGORIES')
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                    onPressed: () => _openCategoryForm(cat),
                    tooltip: 'Modifier',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    onPressed: () => _deleteCategory(cat),
                    tooltip: 'Supprimer',
                  ),
                ],
              )
            : null,
      );
    }

    return ExpansionTile(
      leading: const Icon(Icons.folder_open, color: QuantisColors.luxuryGold),
      title: Text(cat.nom, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: cat.description != null ? Text(cat.description!) : null,
      trailing: PermissionHelper.hasPermission('GERER_CATEGORIES')
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                  onPressed: () => _openCategoryForm(cat),
                  tooltip: 'Modifier',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: () => _deleteCategory(cat),
                  tooltip: 'Supprimer',
                ),
              ],
            )
          : null,
      childrenPadding: const EdgeInsets.only(left: 16),
      children: cat.sousCategories.map((sub) => _buildCategoryTile(sub)).toList(),
    );
  }

  Widget _buildProductsTab() {
    return Column(
      children: [
        // Barre de recherche et bouton d'importation
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => _load(search: v),
                  decoration: InputDecoration(
                    hintText: 'Rechercher par nom ou référence...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () { _searchCtrl.clear(); _load(); },
                          )
                        : null,
                  ),
                ),
              ),
              if (PermissionHelper.hasPermission('IMPORT_EXPORTS')) ...[
                const SizedBox(width: 8),
                if (MediaQuery.of(context).size.width >= 600)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.file_upload, size: 18),
                    label: const Text('Importer CSV'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onPressed: _openImportCsv,
                  )
                else
                  IconButton.filledTonal(
                    icon: const Icon(Icons.file_upload_outlined),
                    tooltip: 'Importer CSV',
                    onPressed: _openImportCsv,
                  ),
              ],
            ],
          ),
        ),

        // Compteur
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: QuantisColors.royalBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_produits.length} produit${_produits.length > 1 ? 's' : ''}',
                  style: const TextStyle(fontSize: 12, color: QuantisColors.royalBlue, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Liste des produits
        Expanded(
          child: _loadingProducts
              ? const Center(child: CircularProgressIndicator())
              : _productsError != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: QuantisColors.error),
                          const SizedBox(height: 8),
                          Text(_productsError!, style: const TextStyle(color: QuantisColors.error)),
                          const SizedBox(height: 16),
                          ElevatedButton(onPressed: () => _load(), child: const Text('Réessayer')),
                        ],
                      ),
                    )
                  : _produits.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 64, color: QuantisColors.textMuted),
                              SizedBox(height: 8),
                              Text('Aucun produit trouvé', style: TextStyle(color: QuantisColors.textMuted)),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () => _load(),
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _produits.length,
                            itemBuilder: (_, i) {
                              final prod = _produits[i];
                              return GestureDetector(
                                onTap: PermissionHelper.hasPermission('CREER_MODIFIER_PRODUIT')
                                    ? () => _openEditProductForm(prod)
                                    : null,
                                child: _ProduitCard(produit: prod),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildCategoriesTab() {
    return _loadingCategories
        ? const Center(child: CircularProgressIndicator())
        : _categoriesError != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: QuantisColors.error),
                    const SizedBox(height: 8),
                    Text(_categoriesError!, style: const TextStyle(color: QuantisColors.error)),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _loadCategories, child: const Text('Réessayer')),
                  ],
                ),
              )
            : _categoriesTree.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.category_outlined, size: 64, color: QuantisColors.textMuted),
                        SizedBox(height: 8),
                        Text('Aucune catégorie enregistrée', style: TextStyle(color: QuantisColors.textMuted)),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadCategories,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _categoriesTree.length,
                      itemBuilder: (_, i) => _buildCategoryTile(_categoriesTree[i]),
                    ),
                  );
  }

  @override
  Widget build(BuildContext context) {
    final activeTab = _tabController.index;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion Catalogue', style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: QuantisColors.royalBlue,
          unselectedLabelColor: QuantisColors.textMuted,
          indicatorColor: QuantisColors.royalBlue,
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Catalogue Produits'),
            Tab(icon: Icon(Icons.category_outlined), text: 'Catégories'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (activeTab == 0) {
                _load();
              } else {
                _loadCategories();
              }
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProductsTab(),
          _buildCategoriesTab(),
        ],
      ),
      floatingActionButton: (() {
        if (activeTab == 0 && PermissionHelper.hasPermission('CREER_MODIFIER_PRODUIT')) {
          return FloatingActionButton(
            backgroundColor: QuantisColors.royalBlue,
            foregroundColor: Colors.white,
            child: const Icon(Icons.add),
            onPressed: _openAddProductForm,
          );
        }
        if (activeTab == 1 && PermissionHelper.hasPermission('GERER_CATEGORIES')) {
          return FloatingActionButton(
            backgroundColor: QuantisColors.royalBlue,
            foregroundColor: Colors.white,
            child: const Icon(Icons.add),
            onPressed: () => _openCategoryForm(),
          );
        }
        return null;
      })(),
    );
  }
}

class _ProduitCard extends StatelessWidget {
  final ProduitModel produit;
  const _ProduitCard({required this.produit});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: QuantisColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: QuantisColors.royalBlue.withValues(alpha: 0.1),
          child: Text(
            produit.nom.isNotEmpty ? produit.nom[0].toUpperCase() : '?',
            style: const TextStyle(fontWeight: FontWeight.w700, color: QuantisColors.royalBlue),
          ),
        ),
        title: Text(produit.nom, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Réf: ${produit.reference}', style: const TextStyle(fontSize: 12, color: QuantisColors.textMuted)),
                if (produit.uniteAbreviation != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      produit.uniteAbreviation!,
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade700, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            if (produit.categorieNom != null)
              Text(produit.categorieNom!, style: const TextStyle(fontSize: 12, color: QuantisColors.textSecondary)),
            if (produit.variantes.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Variantes: ${produit.variantes.map((v) => "${v.attribut}:${v.valeur}").join(", ")}',
                style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: QuantisColors.luxuryGold),
              ),
            ],
          ],
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${produit.prixVente.toStringAsFixed(0)} FCFA',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            if (produit.marge > 0)
              Text('+${produit.margePercent.toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 11, color: QuantisColors.success, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
