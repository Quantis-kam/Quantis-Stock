import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/quantis_theme.dart';
import 'encaissement_dialog.dart';
import 'ticket_receipt_dialog.dart';

/// Écran Vente Rapide / Caisse Tactile (Point of Sale - POS)
class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final ApiClient _api = ApiClient();

  // Données de référence
  List<dynamic> _produits = [];
  List<dynamic> _categories = [];
  List<dynamic> _depots = [];
  List<dynamic> _clients = [];
  Map<String, dynamic>? _sessionCaisse;

  int? _selectedDepotId;
  int? _selectedClientId;
  int? _selectedCategorieId; // null = Tous
  String _searchQuery = '';
  bool _loading = true;

  // Panier
  final List<Map<String, dynamic>> _panier = [];
  final double _remiseGlobale = 0;
  bool _isDesktopCartCollapsed = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _loading = true);
    try {
      final resProduits = await _api.get('/products?size=100');
      final resCats = await _api.get('/categories');
      final resDepots = await _api.get('/stock/depots');
      final resClients = await _api.get('/clients?size=100');
      dynamic sessionData;
      try {
        final resSession = await _api.get('/caisses/session-active');
        sessionData = resSession.data['data'];
      } catch (se) {
        debugPrint('Notice session caisse info: $se');
      }

      if (mounted) {
        setState(() {
          _produits = resProduits.data['data']?['content'] ?? [];
          _categories = resCats.data['data'] ?? [];
          _depots = resDepots.data['data'] ?? [];
          _clients = resClients.data['data']?['content'] ?? [];
          _sessionCaisse = sessionData;

          if (_depots.isNotEmpty && _selectedDepotId == null) {
            _selectedDepotId = _depots.first['id'];
          }
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement POS: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _ajouterAuPanier(Map<String, dynamic> produit) {
    final int prodId = produit['id'];
    final existingIndex = _panier.indexWhere((item) => item['produitId'] == prodId);

    setState(() {
      if (existingIndex != -1) {
        _panier[existingIndex]['quantite'] += 1;
      } else {
        _panier.add({
          'produitId': prodId,
          'nom': produit['nom'],
          'sku': produit['sku'],
          'prixUnitaire': (produit['prixVente'] as num).toDouble(),
          'quantite': 1.0,
          'tauxTva': (produit['tauxTva'] as num?)?.toDouble() ?? 0.0,
          'stock': produit['stockCourant'] ?? 0,
        });
      }
    });
  }

  void _modifierQuantite(int index, double delta) {
    setState(() {
      final nouvelleQte = _panier[index]['quantite'] + delta;
      if (nouvelleQte <= 0) {
        _panier.removeAt(index);
      } else {
        _panier[index]['quantite'] = nouvelleQte;
      }
    });
  }

  void _supprimerDuPanier(int index) {
    setState(() {
      _panier.removeAt(index);
    });
  }

  void _viderPanier() {
    setState(() {
      _panier.clear();
    });
  }

  double get _totalPanier {
    double total = 0;
    for (final item in _panier) {
      final qte = item['quantite'] as double;
      final pu = item['prixUnitaire'] as double;
      total += (qte * pu);
    }
    return total - _remiseGlobale > 0 ? (total - _remiseGlobale) : 0;
  }

  Future<void> _lancerEncaissement() async {
    if (_panier.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le panier est vide !'), backgroundColor: QuantisColors.warning),
      );
      return;
    }

    String? clientNom;
    if (_selectedClientId != null) {
      final c = _clients.firstWhere((cl) => cl['id'] == _selectedClientId, orElse: () => null);
      if (c != null) clientNom = c['nom'];
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EncaissementDialog(
        totalTtc: _totalPanier,
        clientNom: clientNom,
      ),
    );

    if (result == null) return;

    try {
      final payload = {
        'clientId': _selectedClientId,
        'depotId': _selectedDepotId,
        'lignes': _panier.map((item) => {
          'produitId': item['produitId'],
          'quantite': item['quantite'],
          'prixUnitaire': item['prixUnitaire'],
          'tauxTva': item['tauxTva'],
        }).toList(),
        'moyenPaiement': result['moyenPaiement'],
        'montantPaye': result['montantPaye'],
        'montantRecu': result['montantRecu'],
        'notes': result['notes'],
      };

      final response = await _api.post('/documents/pos', data: payload);
      final saleData = response.data['data'] as Map<String, dynamic>;

      _viderPanier();
      _loadInitialData(); // Recharger stocks & session

      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => TicketReceiptDialog(saleData: saleData),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur encaissement: $e'), backgroundColor: QuantisColors.error),
        );
      }
    }
  }

  List<dynamic> get _produitsFiltres {
    return _produits.where((p) {
      final nom = (p['nom'] ?? '').toString().toLowerCase();
      final sku = (p['sku'] ?? '').toString().toLowerCase();
      final codeBarres = (p['codeBarres'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();

      final matchesQuery = query.isEmpty ||
          nom.contains(query) ||
          sku.contains(query) ||
          codeBarres.contains(query);

      final matchesCat = _selectedCategorieId == null ||
          p['categorie']?['id'] == _selectedCategorieId;

      return matchesQuery && matchesCat;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bool isWide = MediaQuery.of(context).size.width >= 900;
    final bool isCaisseOuverte = _sessionCaisse != null && _sessionCaisse!['statut'] == 'OUVERTE';
    final bool isMobile = MediaQuery.of(context).size.width < 750;
    final int totalArticles = _panier.fold<double>(0, (s, i) => s + (i['quantite'] as double)).toInt();

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.point_of_sale, color: QuantisColors.royalBlue),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                isMobile ? 'POS Tactile' : 'Caisse Comptoir / POS Tactile',
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            // Badge Caisse
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (isCaisseOuverte ? QuantisColors.success : QuantisColors.warning).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isCaisseOuverte ? Icons.check_circle : Icons.warning_amber,
                    size: 13,
                    color: isCaisseOuverte ? QuantisColors.success : QuantisColors.warning,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isCaisseOuverte ? 'Ouverte' : 'Fermée',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isCaisseOuverte ? QuantisColors.success : QuantisColors.warning,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Sur mobile / compact, bouton rapide pour ouvrir le panier
          if (!isWide)
            IconButton(
              icon: Badge(
                isLabelVisible: _panier.isNotEmpty,
                label: Text('$totalArticles'),
                backgroundColor: QuantisColors.royalBlue,
                child: const Icon(Icons.shopping_cart_outlined),
              ),
              tooltip: 'Voir le panier',
              onPressed: _openCartModal,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
            onPressed: _loadInitialData,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Barre de Contrôle Supérieure (Dépôt, Client, Recherche)
                _buildTopControls(isMobile),

                // Corps Principal : Catalogue en pleine largeur sur mobile !
                Expanded(
                  child: isWide
                      ? Row(
                          children: [
                            // Colonne Gauche : Catalogue Produits
                            Expanded(child: _buildCatalogSection(isMobile: false)),
                            // Colonne Droite : Panier latéral (normal ou rétracté)
                            if (!_isDesktopCartCollapsed)
                              SizedBox(width: 380, child: _buildCartSection(isWide: true))
                            else
                              _buildCollapsedDesktopCartBar(),
                          ],
                        )
                      : _buildCatalogSection(isMobile: true),
                ),
              ],
            ),
      // Sur mobile/compact, barre d'action panier discrète et extensible au bas
      bottomNavigationBar: isWide ? null : _buildMobileCartBar(),
    );
  }

  /// Barre de contrôle supérieure (Dépôt, Client, Recherche)
  Widget _buildTopControls(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 16, vertical: isMobile ? 6 : 8),
      color: Colors.white,
      child: isMobile
          ? Column(
              children: [
                Row(
                  children: [
                    // Sélecteur Dépôt compact
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _selectedDepotId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Dépôt',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        items: _depots.map((d) {
                          return DropdownMenuItem<int>(
                            value: d['id'] as int,
                            child: Text(d['nom'] ?? 'Dépôt', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedDepotId = val),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Sélecteur Client compact
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        value: _selectedClientId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Client',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Comptoir', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12), overflow: TextOverflow.ellipsis),
                          ),
                          ..._clients.map((c) {
                            return DropdownMenuItem<int?>(
                              value: c['id'] as int,
                              child: Text(c['nom'] ?? 'Client', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                            );
                          }),
                        ],
                        onChanged: (val) => setState(() => _selectedClientId = val),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Champ de recherche compact
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Scanner code-barres ou rechercher article...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ],
            )
          : Row(
              children: [
                // Sélecteur Dépôt
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<int>(
                    value: _selectedDepotId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Dépôt Vente',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    items: _depots.map((d) {
                      return DropdownMenuItem<int>(
                        value: d['id'] as int,
                        child: Text(d['nom'] ?? 'Dépôt', overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedDepotId = val),
                  ),
                ),
                const SizedBox(width: 12),

                // Sélecteur Client
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<int?>(
                    value: _selectedClientId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Client',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Client Divers / Comptoir', style: TextStyle(fontStyle: FontStyle.italic)),
                      ),
                      ..._clients.map((c) {
                        return DropdownMenuItem<int?>(
                          value: c['id'] as int,
                          child: Text(c['nom'] ?? 'Client', overflow: TextOverflow.ellipsis),
                        );
                      }),
                    ],
                    onChanged: (val) => setState(() => _selectedClientId = val),
                  ),
                ),
                const SizedBox(width: 12),

                // Champ de recherche / Code-barres
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Scanner code-barres ou rechercher article (Nom, SKU)...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => setState(() => _searchQuery = ''),
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
              ],
            ),
    );
  }

  /// Section Catalogue des Produits (plein écran sur mobile)
  Widget _buildCatalogSection({required bool isMobile}) {
    final filtered = _produitsFiltres;

    return Column(
      children: [
        // Filtres Catégories
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          color: Colors.white,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: const Text('Tous', style: TextStyle(fontSize: 12)),
                  selected: _selectedCategorieId == null,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  onSelected: (_) => setState(() => _selectedCategorieId = null),
                ),
              ),
              ..._categories.map((cat) {
                final isSelected = _selectedCategorieId == cat['id'];
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(cat['nom'] ?? '', style: const TextStyle(fontSize: 12)),
                    selected: isSelected,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    onSelected: (_) => setState(() => _selectedCategorieId = isSelected ? null : cat['id']),
                  ),
                );
              }),
            ],
          ),
        ),

        // Grille de Produits généreuse et aérée
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text('Aucun article trouvé', style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: EdgeInsets.all(isMobile ? 8 : 12),
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: isMobile ? 180 : 220,
                    childAspectRatio: isMobile ? 0.92 : 0.88,
                    crossAxisSpacing: isMobile ? 8 : 10,
                    mainAxisSpacing: isMobile ? 8 : 10,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final p = filtered[i];
                    final String nom = p['nom'] ?? 'Produit';
                    final String sku = p['sku'] ?? '';
                    final num prix = p['prixVente'] ?? 0;
                    final num? stock = p['stockCourant'];

                    // Nombre d'exemplaires déjà dans le panier
                    final cartMatch = _panier.firstWhere(
                      (item) => item['produitId'] == p['id'],
                      orElse: () => {},
                    );
                    final num inCartQte = (cartMatch['quantite'] as num?) ?? 0;

                    return Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: inCartQte > 0
                            ? const BorderSide(color: QuantisColors.royalBlue, width: 1.5)
                            : BorderSide(color: Colors.grey.shade200),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _ajouterAuPanier(p),
                        child: Padding(
                          padding: EdgeInsets.all(isMobile ? 8 : 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Vignette / Icône + Badge si dans le panier
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    width: isMobile ? 38 : 46,
                                    height: isMobile ? 38 : 46,
                                    decoration: BoxDecoration(
                                      color: QuantisColors.royalBlue.withValues(alpha: 0.08),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.shopping_bag,
                                      color: QuantisColors.royalBlue,
                                      size: isMobile ? 20 : 24,
                                    ),
                                  ),
                                  if (inCartQte > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: QuantisColors.royalBlue,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'x${inCartQte.toInt()}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const Spacer(),

                              // Nom et SKU
                              Text(
                                nom,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: isMobile ? 12 : 13,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (sku.isNotEmpty)
                                Text(
                                  sku,
                                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              const SizedBox(height: 4),

                              // Prix et Badge Stock
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Text(
                                      '$prix F',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: isMobile ? 13 : 14,
                                        color: QuantisColors.royalBlue,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (stock != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: (stock > 5 ? QuantisColors.success : QuantisColors.warning)
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Text(
                                        '$stock',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: stock > 5 ? QuantisColors.success : QuantisColors.warning,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// Barre d'action Panier au bas de l'écran pour mobile/tablette (hauteur réduite à ~56px)
  Widget _buildMobileCartBar() {
    final int totalArticles = _panier.fold<double>(0, (s, i) => s + (i['quantite'] as double)).toInt();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Zone cliquable pour ouvrir la feuille complète du panier
            InkWell(
              onTap: _openCartModal,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Badge(
                      isLabelVisible: _panier.isNotEmpty,
                      label: Text('$totalArticles'),
                      backgroundColor: QuantisColors.royalBlue,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: QuantisColors.royalBlue.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.shopping_cart, color: QuantisColors.royalBlue, size: 18),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _panier.isEmpty ? 'Panier vide' : '$totalArticles article${totalArticles > 1 ? 's' : ''}',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '${_totalPanier.toStringAsFixed(0)} FCFA',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: QuantisColors.royalBlue),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            if (_panier.isNotEmpty) ...[
              OutlinedButton(
                onPressed: _openCartModal,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  side: const BorderSide(color: QuantisColors.royalBlue),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Panier', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _lancerEncaissement,
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: const Text('ENCAISSER', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: QuantisColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 2,
                ),
              ),
            ] else ...[
              Text(
                'Touchez un article pour l\'ajouter',
                style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey.shade500),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Ouvre la vue complète du panier sous forme de BottomSheet rétractable
  void _openCartModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final double height = MediaQuery.of(context).size.height * 0.78;
            return Container(
              height: height,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 15, offset: Offset(0, -4)),
                ],
              ),
              child: Column(
                children: [
                  // Poignée de glissement (drag handle)
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 4),
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _buildCartSection(
                      isWide: false,
                      isModal: true,
                      onCartChanged: () {
                        setModalState(() {});
                        setState(() {});
                      },
                      onCloseModal: () => Navigator.pop(modalCtx),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Panier latéral replié pour desktop
  Widget _buildCollapsedDesktopCartBar() {
    final int totalArticles = _panier.fold<double>(0, (s, i) => s + (i['quantite'] as double)).toInt();
    return Container(
      width: 72,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          IconButton(
            icon: const Icon(Icons.chevron_left, color: QuantisColors.royalBlue),
            tooltip: 'Afficher le panier',
            onPressed: () => setState(() => _isDesktopCartCollapsed = false),
          ),
          const SizedBox(height: 8),
          Badge(
            isLabelVisible: _panier.isNotEmpty,
            label: Text('$totalArticles'),
            backgroundColor: QuantisColors.royalBlue,
            child: const Icon(Icons.shopping_cart, color: QuantisColors.royalBlue, size: 24),
          ),
          const Spacer(),
          RotatedBox(
            quarterTurns: 3,
            child: Text(
              '${_totalPanier.toStringAsFixed(0)} FCFA',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: QuantisColors.royalBlue),
            ),
          ),
          const SizedBox(height: 16),
          IconButton(
            icon: const Icon(Icons.payment, color: QuantisColors.success),
            tooltip: 'Encaisser',
            onPressed: _panier.isEmpty ? null : () => _lancerEncaissement(),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// Section Panier (latérale sur grand écran ou modal sur petit écran)
  Widget _buildCartSection({
    bool isWide = true,
    bool isModal = false,
    VoidCallback? onCartChanged,
    VoidCallback? onCloseModal,
  }) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // En-tête Panier
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: QuantisColors.royalBlue.withValues(alpha: 0.05),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shopping_cart, color: QuantisColors.royalBlue, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Panier (${_panier.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: QuantisColors.royalBlue),
                ),
                if (isWide) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 20, color: QuantisColors.textMuted),
                    tooltip: 'Masquer le panier',
                    onPressed: () => setState(() => _isDesktopCartCollapsed = true),
                  ),
                ],
                const Spacer(),
                if (_panier.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      _viderPanier();
                      onCartChanged?.call();
                    },
                    icon: const Icon(Icons.delete_sweep, size: 16, color: QuantisColors.error),
                    label: const Text('Vider', style: TextStyle(fontSize: 12, color: QuantisColors.error)),
                  ),
                if (isModal) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: 'Fermer',
                    onPressed: onCloseModal ?? () => Navigator.pop(context),
                  ),
                ],
              ],
            ),
          ),

          // Liste des articles du panier
          Expanded(
            child: _panier.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_shopping_cart, size: 40, color: Colors.grey.shade300),
                        const SizedBox(height: 6),
                        Text('Panier vide', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: _panier.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final item = _panier[i];
                      final qte = item['quantite'] as double;
                      final pu = item['prixUnitaire'] as double;
                      final totalLigne = qte * pu;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['nom'] ?? '',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${pu.toStringAsFixed(0)} FCFA x ${qte.toStringAsFixed(0)} = ${totalLigne.toStringAsFixed(0)} FCFA',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                  ),
                                ],
                              ),
                            ),
                            // Contrôleurs Quantité
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                _modifierQuantite(i, -1);
                                onCartChanged?.call();
                              },
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(qte.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, size: 20, color: QuantisColors.royalBlue),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                _modifierQuantite(i, 1);
                                onCartChanged?.call();
                              },
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                _supprimerDuPanier(i);
                                onCartChanged?.call();
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Résumé et Bouton d'Encaissement
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2)),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Net :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(
                      '${_totalPanier.toStringAsFixed(0)} FCFA',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: QuantisColors.royalBlue),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: _panier.isEmpty
                        ? null
                        : () {
                            if (isModal && onCloseModal != null) {
                              onCloseModal();
                            }
                            _lancerEncaissement();
                          },
                    icon: const Icon(Icons.payment, size: 18),
                    label: Text(
                      isWide ? 'ENCAISSER (F10)' : 'ENCAISSER',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: QuantisColors.royalBlue,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
