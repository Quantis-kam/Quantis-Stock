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
  double _remiseGlobale = 0;

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
    final bool isWide = MediaQuery.of(context).size.width >= 950;
    final bool isCaisseOuverte = _sessionCaisse != null && _sessionCaisse!['statut'] == 'OUVERTE';

    final bool isMobile = MediaQuery.of(context).size.width < 750;

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
                  Icon(isCaisseOuverte ? Icons.check_circle : Icons.warning_amber,
                      size: 13, color: isCaisseOuverte ? QuantisColors.success : QuantisColors.warning),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  color: Colors.white,
                  child: isMobile
                      ? Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    value: _selectedDepotId,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Dépôt Vente',
                                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                                const SizedBox(width: 8),
                                Expanded(
                                  child: DropdownButtonFormField<int?>(
                                    value: _selectedClientId,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Client',
                                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    ),
                                    items: [
                                      const DropdownMenuItem<int?>(
                                        value: null,
                                        child: Text('Divers / Comptoir', style: TextStyle(fontStyle: FontStyle.italic), overflow: TextOverflow.ellipsis),
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
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              decoration: InputDecoration(
                                hintText: 'Scanner code-barres ou rechercher article...',
                                prefixIcon: const Icon(Icons.search, size: 20),
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
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                ),

                // Corps Principal
                Expanded(
                  child: isWide
                      ? Row(
                          children: [
                            // Colonne Gauche : Catalogue Produits
                            Expanded(flex: 6, child: _buildCatalogSection()),
                            // Colonne Droite : Panier
                            SizedBox(width: 380, child: _buildCartSection(isWide: true)),
                          ],
                        )
                      : Column(
                          children: [
                            Expanded(child: _buildCatalogSection()),
                            Container(
                              height: 250,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                              ),
                              child: _buildCartSection(isWide: false),
                            ),
                          ],
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildCatalogSection() {
    final filtered = _produitsFiltres;

    return Column(
      children: [
        // Filtres Catégories
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: Colors.white,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: const Text('Tous'),
                  selected: _selectedCategorieId == null,
                  onSelected: (_) => setState(() => _selectedCategorieId = null),
                ),
              ),
              ..._categories.map((cat) {
                final isSelected = _selectedCategorieId == cat['id'];
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(cat['nom'] ?? ''),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedCategorieId = isSelected ? null : cat['id']),
                  ),
                );
              }),
            ],
          ),
        ),

        // Grille de Produits
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
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final p = filtered[i];
                    final String nom = p['nom'] ?? 'Produit';
                    final String sku = p['sku'] ?? '';
                    final num prix = p['prixVente'] ?? 0;
                    final num? stock = p['stockCourant'];

                    return Card(
                      elevation: 1.5,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _ajouterAuPanier(p),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Vignette / Icone
                              Center(
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: QuantisColors.royalBlue.withValues(alpha: 0.08),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.shopping_bag, color: QuantisColors.royalBlue, size: 28),
                                ),
                              ),
                              const Spacer(),

                              // Nom et SKU
                              Text(
                                nom,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                sku,
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 6),

                              // Prix et Badge Stock
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '$prix F',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                      color: QuantisColors.royalBlue,
                                    ),
                                  ),
                                  if (stock != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: (stock > 5 ? QuantisColors.success : QuantisColors.warning)
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '$stock en stock',
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

  Widget _buildCartSection({bool isWide = true}) {
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
                const Spacer(),
                if (_panier.isNotEmpty)
                  TextButton.icon(
                    onPressed: _viderPanier,
                    icon: const Icon(Icons.delete_sweep, size: 16, color: QuantisColors.error),
                    label: const Text('Vider', style: TextStyle(fontSize: 12, color: QuantisColors.error)),
                  ),
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
                              onPressed: () => _modifierQuantite(i, -1),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(qte.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, size: 20, color: QuantisColors.royalBlue),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _modifierQuantite(i, 1),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _supprimerDuPanier(i),
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
                    onPressed: _panier.isEmpty ? null : _lancerEncaissement,
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
