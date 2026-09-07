import 'package:flutter/material.dart';
import '../../../core/theme/quantis_theme.dart';
import '../../../core/network/api_client.dart';

class SuperAdminScreen extends StatefulWidget {
  const SuperAdminScreen({super.key});

  @override
  State<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends State<SuperAdminScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  Map<String, dynamic>? _stats;
  List<dynamic> _entreprises = [];
  String _searchQuery = '';
  String _statusFilter = 'ALL'; // ALL, ACTIVE, SUSPENDED

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final statsResponse = await ApiClient.instance.get('/platform/stats');
      final entreprisesResponse = await ApiClient.instance.get('/platform/entreprises');

      if (mounted) {
        setState(() {
          _stats = statsResponse.data is Map ? statsResponse.data['data'] : null;
          _entreprises = (entreprisesResponse.data is Map && entreprisesResponse.data['data'] is List)
              ? entreprisesResponse.data['data']
              : [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Erreur lors du chargement des données de la plateforme: $e';
          _isLoading = false;
        });
      }
    }
  }

  List<dynamic> get _filteredEntreprises {
    return _entreprises.where((e) {
      final nom = (e['nom'] ?? '').toString().toLowerCase();
      final email = (e['email'] ?? '').toString().toLowerCase();
      final nif = (e['nif'] ?? '').toString().toLowerCase();
      final rccm = (e['rccm'] ?? '').toString().toLowerCase();
      final adminEmail = (e['adminEmail'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();

      final matchesSearch = nom.contains(q) ||
          email.contains(q) ||
          nif.contains(q) ||
          rccm.contains(q) ||
          adminEmail.contains(q);

      final isActif = e['estActif'] == true;
      final isLicenceValide = e['isLicenceValide'] != false;
      final matchesFilter = _statusFilter == 'ALL' ||
          (_statusFilter == 'ACTIVE' && isActif && isLicenceValide) ||
          (_statusFilter == 'SUSPENDED' && !isActif) ||
          (_statusFilter == 'EXPIRED' && !isLicenceValide);

      return matchesSearch && matchesFilter;
    }).toList();
  }

  Future<void> _toggleStatus(dynamic ent) async {
    final bool currentlyActive = ent['estActif'] == true;
    final String titleWord = currentlyActive ? 'Suspension' : 'Réactivation';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              currentlyActive ? Icons.warning_amber_rounded : Icons.check_circle_outline,
              color: currentlyActive ? Colors.red : Colors.green,
            ),
            const SizedBox(width: 10),
            Text('$titleWord de ${ent['nom']}'),
          ],
        ),
        content: Text(
          currentlyActive
              ? 'Attention : En suspendant cette entreprise, tous ses utilisateurs seront immédiatement bloqués et ne pourront plus se connecter à Quantis Stock.\n\nVoulez-vous continuer ?'
              : 'En réactivant cette entreprise, les utilisateurs autorisés pourront à nouveau accéder à leurs données.\n\nVoulez-vous réactiver ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: currentlyActive ? Colors.red : Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(currentlyActive ? 'Confirmer la suspension' : 'Confirmer la réactivation'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await ApiClient.instance.patch('/platform/entreprises/${ent['id']}/status');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.data['message'] ?? 'Statut mis à jour'),
            backgroundColor: currentlyActive ? Colors.orange.shade800 : Colors.green,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showCreateEntrepriseDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CreateEntrepriseDialog(onSuccess: _loadData),
    );
  }

  void _showUsersDialog(dynamic ent) {
    showDialog(
      context: context,
      builder: (ctx) => _EntrepriseUsersDialog(entreprise: ent),
    );
  }

  void _showResetPasswordDialog(dynamic ent) {
    showDialog(
      context: context,
      builder: (ctx) => _ResetAdminPasswordDialog(entreprise: ent),
    );
  }

  void _showSupervisionDialog(dynamic ent) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _EntrepriseSupervisionDialog(entreprise: ent),
    );
  }

  void _showRenewLicenceDialog(dynamic ent) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _RenewLicenceDialog(
        entreprise: ent,
        onSuccess: _loadData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              if (_errorMessage != null) ...[
                _buildErrorBanner(),
                const SizedBox(height: 20),
              ],
              _buildStatsGrid(),
              const SizedBox(height: 28),
              _buildSearchAndFilters(),
              const SizedBox(height: 16),
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_filteredEntreprises.isEmpty)
                _buildEmptyState()
              else
                _buildEntrepriseCards(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final bool isMobile = MediaQuery.of(context).size.width < 700;

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [QuantisColors.royalBlue, Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: QuantisColors.royalBlue.withValues(alpha: 0.25),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: QuantisColors.luxuryGold.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: QuantisColors.luxuryGold, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        size: 26,
                        color: QuantisColors.luxuryGold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Console Super-Admin',
                                  style: TextStyle(
                                    fontFamily: 'SpaceGrotesk',
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: QuantisColors.luxuryGold,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'SaaS',
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Supervision globale du parc multi-entreprises',
                            style: TextStyle(color: Colors.white70, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white70),
                      onPressed: _loadData,
                      tooltip: 'Actualiser les données',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: QuantisColors.luxuryGold,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.add_business_rounded, size: 18),
                    label: const Text(
                      'Nouvelle Entreprise',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: _showCreateEntrepriseDialog,
                  ),
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: QuantisColors.luxuryGold.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: QuantisColors.luxuryGold, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    size: 32,
                    color: QuantisColors.luxuryGold,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Console Super-Administrateur Plateforme',
                            style: TextStyle(
                              fontFamily: 'SpaceGrotesk',
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: QuantisColors.luxuryGold,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'SUPER ADMIN',
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Supervision globale du parc multi-entreprises Quantis SaaS : isolations des données, souscriptions et gouvernance.',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: QuantisColors.luxuryGold,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 3,
                  ),
                  icon: const Icon(Icons.add_business_rounded, size: 20),
                  label: const Text(
                    'Nouvelle Entreprise',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  onPressed: _showCreateEntrepriseDialog,
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white70),
                  onPressed: _loadData,
                  tooltip: 'Actualiser les données',
                ),
              ],
            ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
            ),
          ),
          TextButton(
            onPressed: _loadData,
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  String _formatMontant(dynamic val, [String currency = 'FCFA']) {
    if (val == null) return '0 $currency';
    final num numVal = val is num ? val : (num.tryParse(val.toString()) ?? 0);
    final String str = numVal.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write(' ');
      }
      buffer.write(str[i]);
    }
    return '${buffer.toString()} $currency';
  }

  Widget _buildStatsGrid() {
    final totalEnt = _stats?['totalEntreprises'] ?? _entreprises.length;
    final actives = _stats?['entreprisesActives'] ?? _entreprises.where((e) => e['estActif'] == true).length;
    final suspendues = _stats?['entreprisesSuspendues'] ?? _entreprises.where((e) => e['estActif'] == false).length;
    final users = _stats?['totalUtilisateurs'] ?? 0;
    final docs = _stats?['totalDocuments'] ?? 0;
    final prods = _stats?['totalProduits'] ?? 0;

    final caGlobal = _stats?['chiffreAffairesGlobal'] ?? 0;
    final achatsGlobal = _stats?['totalAchatsGlobal'] ?? 0;
    final margeGlobale = _stats?['margeGlobale'] ?? 0;
    final ventesCount = _stats?['totalVentesCount'] ?? 0;
    final achatsCount = _stats?['totalAchatsCount'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Titre supervision financière consolidée
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.analytics_rounded, size: 18, color: Color(0xFF059669)),
            ),
            const SizedBox(width: 10),
            const Text(
              'Supervision Financière Consolidée (Plateforme SaaS)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'SpaceGrotesk',
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 1100
                ? 4
                : constraints.maxWidth > 700
                    ? 2
                    : 1;

            return GridView.count(
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: constraints.maxWidth > 1100
                  ? 1.85
                  : (constraints.maxWidth > 600 ? 2.0 : 2.5),
              children: [
                _buildStatCard(
                  'Chiffre d\'Affaires Global',
                  _formatMontant(caGlobal, 'FCFA'),
                  Icons.trending_up_rounded,
                  const Color(0xFF059669),
                  '$ventesCount vente(s) formalisée(s)',
                ),
                _buildStatCard(
                  'Achats Fournisseurs Globaux',
                  _formatMontant(achatsGlobal, 'FCFA'),
                  Icons.shopping_bag_outlined,
                  const Color(0xFFD97706),
                  '$achatsCount commande(s) d\'approvisionnement',
                ),
                _buildStatCard(
                  'Marge Brute Consolidée',
                  _formatMontant(margeGlobale, 'FCFA'),
                  Icons.account_balance_wallet_rounded,
                  QuantisColors.royalBlue,
                  'Bénéfice commercial net plateforme',
                ),
                _buildStatCard(
                  'Trésorerie Globale Réseau',
                  _formatMontant(_stats?['soldeCaisseGlobal'] ?? 0, 'FCFA'),
                  Icons.savings_rounded,
                  const Color(0xFF4F46E5),
                  'Liquidités disponibles en caisses',
                ),
                _buildStatCard(
                  'Comptes Entreprises SaaS',
                  '$totalEnt ($actives Actives)',
                  Icons.business_rounded,
                  QuantisColors.royalBlue,
                  '$suspendues suspendue(s)',
                ),
                _buildStatCard(
                  'Utilisateurs Déclarés',
                  '$users',
                  Icons.people_alt_rounded,
                  Colors.purple.shade700,
                  'Comptes actifs sur le parc',
                ),
                _buildStatCard(
                  'Documents & Factures',
                  '$docs',
                  Icons.receipt_long_rounded,
                  Colors.amber.shade800,
                  'Total transactions émises',
                ),
                _buildStatCard(
                  'Catalogue Produits Réseau',
                  '$prods',
                  Icons.inventory_2_rounded,
                  Colors.indigo.shade700,
                  'Références articles gérées',
                ),
                _buildStatCard(
                  'Santé Multi-Tenant',
                  '100% Isolé',
                  Icons.verified_user_rounded,
                  Colors.teal.shade700,
                  'Bases & Schémas sécurisés',
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, String subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade900,
              fontFamily: 'SpaceGrotesk',
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    final bool isMobile = MediaQuery.of(context).size.width < 800;
    final activeCount = _entreprises.where((e) => e['estActif'] == true && e['isLicenceValide'] != false).length;
    final suspendedCount = _entreprises.where((e) => e['estActif'] == false).length;
    final expiredCount = _entreprises.where((e) => e['isLicenceValide'] == false).length;

    final chips = [
      ChoiceChip(
        label: Text('Toutes (${_entreprises.length})'),
        selected: _statusFilter == 'ALL',
        onSelected: (_) => setState(() => _statusFilter = 'ALL'),
        selectedColor: QuantisColors.royalBlue,
        labelStyle: TextStyle(
          color: _statusFilter == 'ALL' ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
      const SizedBox(width: 8),
      ChoiceChip(
        label: Text('Actives ($activeCount)'),
        selected: _statusFilter == 'ACTIVE',
        onSelected: (_) => setState(() => _statusFilter = 'ACTIVE'),
        selectedColor: Colors.green.shade700,
        labelStyle: TextStyle(
          color: _statusFilter == 'ACTIVE' ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
      const SizedBox(width: 8),
      ChoiceChip(
        label: Text('Licences Expirées ($expiredCount)'),
        selected: _statusFilter == 'EXPIRED',
        onSelected: (_) => setState(() => _statusFilter = 'EXPIRED'),
        selectedColor: Colors.red.shade700,
        labelStyle: TextStyle(
          color: _statusFilter == 'EXPIRED' ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
      const SizedBox(width: 8),
      ChoiceChip(
        label: Text('Suspendues ($suspendedCount)'),
        selected: _statusFilter == 'SUSPENDED',
        onSelected: (_) => setState(() => _statusFilter = 'SUSPENDED'),
        selectedColor: Colors.grey.shade800,
        labelStyle: TextStyle(
          color: _statusFilter == 'SUSPENDED' ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    ];

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Rechercher une entreprise...',
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: chips),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Rechercher par nom, email, NIF, RCCM, administrateur...',
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: chips,
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(40),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(Icons.business_center_outlined, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'Aucune entreprise trouvée',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Aucun résultat ne correspond à votre recherche "$_searchQuery".'
                  : 'Commencez par ajouter votre première entreprise SaaS.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: QuantisColors.royalBlue,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.add),
              label: const Text('Créer une entreprise'),
              onPressed: _showCreateEntrepriseDialog,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntrepriseCards() {
    final bool isMobile = MediaQuery.of(context).size.width < 850;

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredEntreprises.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (ctx, index) {
        final ent = _filteredEntreprises[index];
        final bool isActif = ent['estActif'] == true;

        final badgeActif = Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isActif ? Colors.green.shade50 : Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActif ? Colors.green.shade400 : Colors.red.shade400,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isActif ? Icons.check_circle : Icons.cancel,
                size: 12,
                color: isActif ? Colors.green.shade700 : Colors.red.shade700,
              ),
              const SizedBox(width: 4),
              Text(
                isActif ? 'ACTIF' : 'SUSPENDU',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isActif ? Colors.green.shade800 : Colors.red.shade800,
                ),
              ),
            ],
          ),
        );

        final badgeLicence = Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: ent['isLicenceValide'] == false
                ? Colors.red.shade50
                : (ent['joursRestantsLicence'] != null && (ent['joursRestantsLicence'] as num) <= 5)
                    ? Colors.amber.shade50
                    : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: ent['isLicenceValide'] == false
                  ? Colors.red.shade400
                  : (ent['joursRestantsLicence'] != null && (ent['joursRestantsLicence'] as num) <= 5)
                      ? Colors.amber.shade400
                      : Colors.blue.shade300,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                ent['isLicenceValide'] == false
                    ? Icons.lock_clock_rounded
                    : Icons.vpn_key_rounded,
                size: 12,
                color: ent['isLicenceValide'] == false
                    ? Colors.red.shade700
                    : (ent['joursRestantsLicence'] != null && (ent['joursRestantsLicence'] as num) <= 5)
                        ? Colors.amber.shade900
                        : Colors.blue.shade800,
              ),
              const SizedBox(width: 4),
              Text(
                ent['isLicenceValide'] == false
                    ? 'LICENCE EXPIRÉE (${ent['dateExpirationLicence'] ?? 'Fin de mois'})'
                    : (ent['joursRestantsLicence'] != null && (ent['joursRestantsLicence'] as num) <= 5)
                        ? 'EXPIRE DANS ${ent['joursRestantsLicence']}J'
                        : 'LICENCE ACTIVE (${ent['dateExpirationLicence'] ?? 'Fin de mois'})',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: ent['isLicenceValide'] == false
                    ? Colors.red.shade900
                    : (ent['joursRestantsLicence'] != null && (ent['joursRestantsLicence'] as num) <= 5)
                        ? Colors.amber.shade900
                        : Colors.blue.shade900,
                ),
              ),
            ],
          ),
        );

        final switchStatusButton = Container(
          decoration: BoxDecoration(
            color: isActif ? Colors.red.shade50 : Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActif ? Colors.red.shade200 : Colors.green.shade200,
            ),
          ),
          child: TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: isActif ? Colors.red.shade700 : Colors.green.shade800,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            icon: Icon(
              isActif ? Icons.block_rounded : Icons.check_circle_outline,
              size: 15,
            ),
            label: Text(
              isActif ? 'Suspendre' : 'Réactiver',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            ),
            onPressed: () => _toggleStatus(ent),
          ),
        );

        return Container(
          padding: EdgeInsets.all(isMobile ? 14 : 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActif ? Colors.grey.shade200 : Colors.red.shade300,
              width: isActif ? 1.0 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isMobile) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isActif
                              ? [QuantisColors.royalBlue, const Color(0xFF1E3A8A)]
                              : [Colors.grey.shade600, Colors.grey.shade800],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          (ent['nom'] ?? 'Q').toString().substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            color: QuantisColors.luxuryGold,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            fontFamily: 'SpaceGrotesk',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ent['nom'] ?? 'Sans Nom',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'SpaceGrotesk',
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [badgeActif, badgeLicence],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'ID: #${ent['id']} • IFU: ${ent['nif'] ?? '-'} • RCCM: ${ent['rccm'] ?? '-'}',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: switchStatusButton,
                ),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isActif
                              ? [QuantisColors.royalBlue, const Color(0xFF1E3A8A)]
                              : [Colors.grey.shade600, Colors.grey.shade800],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          (ent['nom'] ?? 'Q').toString().substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            color: QuantisColors.luxuryGold,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                            fontFamily: 'SpaceGrotesk',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              Text(
                                ent['nom'] ?? 'Sans Nom',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'SpaceGrotesk',
                                ),
                              ),
                              badgeActif,
                              badgeLicence,
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'ID: #${ent['id']} • IFU/NIF: ${ent['nif'] ?? 'N/A'} • RCCM: ${ent['rccm'] ?? 'N/A'} • Monnaie: ${ent['monnaie'] ?? 'FCFA'}',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    switchStatusButton,
                  ],
                ),
              ],
              const SizedBox(height: 14),
              // Bandeau de Supervision Financière de l'Entreprise
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: isMobile
                    ? Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildFinancialMetric(
                                  'Chiffre d\'Affaires (CA)',
                                  _formatMontant(ent['chiffreAffaires'], ent['monnaie'] ?? 'FCFA'),
                                  '${ent['ventesCount'] ?? 0} vente(s)',
                                  const Color(0xFF059669),
                                  Icons.trending_up_rounded,
                                ),
                              ),
                              Container(width: 1, height: 36, color: Colors.grey.shade300, margin: const EdgeInsets.symmetric(horizontal: 8)),
                              Expanded(
                                child: _buildFinancialMetric(
                                  'Achats Fournisseurs',
                                  _formatMontant(ent['totalAchats'], ent['monnaie'] ?? 'FCFA'),
                                  '${ent['achatsCount'] ?? 0} commande(s)',
                                  const Color(0xFFD97706),
                                  Icons.shopping_bag_outlined,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildFinancialMetric(
                                  'Marge Commerciale',
                                  _formatMontant(ent['margeBrute'], ent['monnaie'] ?? 'FCFA'),
                                  (ent['chiffreAffaires'] != null && (ent['chiffreAffaires'] as num) > 0)
                                      ? 'Taux: ${(((ent['margeBrute'] ?? 0) as num) / (ent['chiffreAffaires'] as num) * 100).toStringAsFixed(1)}%'
                                      : 'Marge directe',
                                  ((ent['margeBrute'] ?? 0) as num) >= 0 ? QuantisColors.royalBlue : Colors.red.shade700,
                                  Icons.account_balance_wallet_outlined,
                                ),
                              ),
                              Container(width: 1, height: 36, color: Colors.grey.shade300, margin: const EdgeInsets.symmetric(horizontal: 8)),
                              Expanded(
                                child: _buildFinancialMetric(
                                  'Trésorerie Caisse',
                                  _formatMontant(ent['soldeCaisse'], ent['monnaie'] ?? 'FCFA'),
                                  'Solde caisse',
                                  const Color(0xFF4F46E5),
                                  Icons.savings_outlined,
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: _buildFinancialMetric(
                              'Chiffre d\'Affaires (CA)',
                              _formatMontant(ent['chiffreAffaires'], ent['monnaie'] ?? 'FCFA'),
                              '${ent['ventesCount'] ?? 0} vente(s) formalisée(s)',
                              const Color(0xFF059669),
                              Icons.trending_up_rounded,
                            ),
                          ),
                          Container(width: 1, height: 40, color: Colors.grey.shade300, margin: const EdgeInsets.symmetric(horizontal: 10)),
                          Expanded(
                            child: _buildFinancialMetric(
                              'Achats Fournisseurs',
                              _formatMontant(ent['totalAchats'], ent['monnaie'] ?? 'FCFA'),
                              '${ent['achatsCount'] ?? 0} commande(s) reçue(s)',
                              const Color(0xFFD97706),
                              Icons.shopping_bag_outlined,
                            ),
                          ),
                          Container(width: 1, height: 40, color: Colors.grey.shade300, margin: const EdgeInsets.symmetric(horizontal: 10)),
                          Expanded(
                            child: _buildFinancialMetric(
                              'Marge Commerciale',
                              _formatMontant(ent['margeBrute'], ent['monnaie'] ?? 'FCFA'),
                              (ent['chiffreAffaires'] != null && (ent['chiffreAffaires'] as num) > 0)
                                  ? 'Taux: ${(((ent['margeBrute'] ?? 0) as num) / (ent['chiffreAffaires'] as num) * 100).toStringAsFixed(1)}%'
                                  : 'Marge directe',
                              ((ent['margeBrute'] ?? 0) as num) >= 0 ? QuantisColors.royalBlue : Colors.red.shade700,
                              Icons.account_balance_wallet_outlined,
                            ),
                          ),
                          Container(width: 1, height: 40, color: Colors.grey.shade300, margin: const EdgeInsets.symmetric(horizontal: 10)),
                          Expanded(
                            child: _buildFinancialMetric(
                              'Trésorerie Caisse',
                              _formatMontant(ent['soldeCaisse'], ent['monnaie'] ?? 'FCFA'),
                              'Solde net en caisse',
                              const Color(0xFF4F46E5),
                              Icons.savings_outlined,
                            ),
                          ),
                        ],
                      ),
              ),

              const Divider(height: 1),
              const SizedBox(height: 12),
              // Détails, Badges & Actions
              if (isMobile) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.admin_panel_settings_outlined, size: 15, color: QuantisColors.royalBlue),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Admin: ${ent['adminEmail'] ?? 'Non configuré'}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.contact_phone_outlined, size: 15, color: Colors.blueGrey),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${ent['telephone'] ?? 'Tel: -'} • ${ent['email'] ?? 'Mail: -'}',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildMiniBadge(Icons.people, '${ent['userCount'] ?? 0} users', Colors.purple),
                        _buildMiniBadge(Icons.inventory_2, '${ent['productCount'] ?? 0} produits', Colors.teal),
                        _buildMiniBadge(Icons.receipt_long, '${ent['documentCount'] ?? 0} docs', Colors.amber.shade900),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ent['isLicenceValide'] == false ? Colors.red.shade700 : const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 1,
                          ),
                          icon: const Icon(Icons.vpn_key_rounded, size: 14),
                          label: Text(
                            ent['isLicenceValide'] == false ? 'Réactiver Licence' : 'Prolonger (+1M)',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () => _showRenewLicenceDialog(ent),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: QuantisColors.luxuryGold,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 1,
                          ),
                          icon: const Icon(Icons.insights_rounded, size: 15, color: QuantisColors.luxuryGold),
                          label: const Text('Détails', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: () => _showSupervisionDialog(ent),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                          ),
                          icon: const Icon(Icons.people_outline, size: 14),
                          label: const Text('Users', style: TextStyle(fontSize: 11)),
                          onPressed: () => _showUsersDialog(ent),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                          ),
                          icon: const Icon(Icons.password, size: 14),
                          label: const Text('Reset Mdp', style: TextStyle(fontSize: 11)),
                          onPressed: () => _showResetPasswordDialog(ent),
                        ),
                      ],
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Row(
                        children: [
                          const Icon(Icons.admin_panel_settings_outlined, size: 16, color: QuantisColors.royalBlue),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Admin: ${ent['adminEmail'] ?? 'Non configuré'}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Row(
                        children: [
                          const Icon(Icons.contact_phone_outlined, size: 16, color: Colors.blueGrey),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${ent['telephone'] ?? 'Tel: -'} • ${ent['email'] ?? 'Mail: -'}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildMiniBadge(Icons.people, '${ent['userCount'] ?? 0} utilisateurs', Colors.purple),
                    const SizedBox(width: 8),
                    _buildMiniBadge(Icons.inventory_2, '${ent['productCount'] ?? 0} produits', Colors.teal),
                    const SizedBox(width: 8),
                    _buildMiniBadge(Icons.receipt_long, '${ent['documentCount'] ?? 0} docs', Colors.amber.shade900),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ent['isLicenceValide'] == false ? Colors.red.shade700 : const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 1,
                      ),
                      icon: const Icon(Icons.vpn_key_rounded, size: 15),
                      label: Text(
                        ent['isLicenceValide'] == false ? 'Réactiver Licence' : 'Prolonger (+1M)',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _showRenewLicenceDialog(ent),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: QuantisColors.luxuryGold,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 1,
                      ),
                      icon: const Icon(Icons.insights_rounded, size: 16, color: QuantisColors.luxuryGold),
                      label: const Text('Supervision Détaillée', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () => _showSupervisionDialog(ent),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      icon: const Icon(Icons.people_outline, size: 16),
                      label: const Text('Utilisateurs', style: TextStyle(fontSize: 12)),
                      onPressed: () => _showUsersDialog(ent),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      icon: const Icon(Icons.password, size: 16),
                      label: const Text('Reset Mdp', style: TextStyle(fontSize: 12)),
                      onPressed: () => _showResetPasswordDialog(ent),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildFinancialMetric(String title, String value, String subtitle, Color color, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'SpaceGrotesk',
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMiniBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialogue de création d'une nouvelle entreprise SaaS
class _CreateEntrepriseDialog extends StatefulWidget {
  final VoidCallback onSuccess;
  const _CreateEntrepriseDialog({required this.onSuccess});

  @override
  State<_CreateEntrepriseDialog> createState() => _CreateEntrepriseDialogState();
}

class _CreateEntrepriseDialogState extends State<_CreateEntrepriseDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  String? _error;

  // Entreprise
  final _nomController = TextEditingController();
  final _nifController = TextEditingController();
  final _rccmController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _adresseController = TextEditingController();
  String _monnaie = 'FCFA';

  // Admin
  final _adminNomController = TextEditingController();
  final _adminPrenomController = TextEditingController();
  final _adminEmailController = TextEditingController();
  final _adminMotDePasseController = TextEditingController(text: 'Admin@2026');

  @override
  void dispose() {
    _nomController.dispose();
    _nifController.dispose();
    _rccmController.dispose();
    _telephoneController.dispose();
    _emailController.dispose();
    _adresseController.dispose();
    _adminNomController.dispose();
    _adminPrenomController.dispose();
    _adminEmailController.dispose();
    _adminMotDePasseController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final payload = {
        'nom': _nomController.text.trim(),
        'nif': _nifController.text.trim(),
        'rccm': _rccmController.text.trim(),
        'telephone': _telephoneController.text.trim(),
        'email': _emailController.text.trim(),
        'adresse': _adresseController.text.trim(),
        'monnaie': _monnaie,
        'formatFacture': 'FAC-{YYYY}-{NNNNN}',
        'adminNom': _adminNomController.text.trim(),
        'adminPrenom': _adminPrenomController.text.trim(),
        'adminEmail': _adminEmailController.text.trim(),
        'adminMotDePasse': _adminMotDePasseController.text.trim(),
      };

      await ApiClient.instance.post('/platform/entreprises', data: payload);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Entreprise "${_nomController.text}" créée avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erreur lors de la création : $e';
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 650;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 40,
        vertical: 16,
      ),
      child: Container(
        width: isMobile ? screenWidth * 0.95 : 680,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        padding: EdgeInsets.all(isMobile ? 16 : 28),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(isMobile ? 6 : 8),
                          decoration: BoxDecoration(
                            color: QuantisColors.royalBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.add_business, color: QuantisColors.royalBlue, size: isMobile ? 20 : 24),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Créer une Entreprise SaaS',
                            style: TextStyle(
                              fontFamily: 'SpaceGrotesk',
                              fontSize: isMobile ? 17 : 20,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
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
              const SizedBox(height: 8),
              Text(
                'Crée un espace multi-tenant isolé avec son dépôt principal et son compte administrateur dédié.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: isMobile ? 12 : 13),
              ),
              const Divider(height: 24),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              ],
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '1. Informations de l\'Entreprise',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: QuantisColors.royalBlue),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nomController,
                        decoration: const InputDecoration(
                          labelText: 'Raison sociale / Nom commercial *',
                          prefixIcon: Icon(Icons.storefront),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Nom obligatoire' : null,
                      ),
                      const SizedBox(height: 12),
                      if (isMobile) ...[
                        TextFormField(
                          controller: _nifController,
                          decoration: const InputDecoration(
                            labelText: 'IFU / NIF (Optionnel)',
                            prefixIcon: Icon(Icons.receipt),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _rccmController,
                          decoration: const InputDecoration(
                            labelText: 'RCCM (Optionnel)',
                            prefixIcon: Icon(Icons.badge),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _nifController,
                                decoration: const InputDecoration(
                                  labelText: 'IFU / NIF (Optionnel)',
                                  prefixIcon: Icon(Icons.receipt),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _rccmController,
                                decoration: const InputDecoration(
                                  labelText: 'RCCM (Optionnel)',
                                  prefixIcon: Icon(Icons.badge),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      if (isMobile) ...[
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email de l\'entreprise',
                            prefixIcon: Icon(Icons.email_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _telephoneController,
                          decoration: const InputDecoration(
                            labelText: 'Téléphone',
                            prefixIcon: Icon(Icons.phone_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _emailController,
                                decoration: const InputDecoration(
                                  labelText: 'Email de l\'entreprise',
                                  prefixIcon: Icon(Icons.email_outlined),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _telephoneController,
                                decoration: const InputDecoration(
                                  labelText: 'Téléphone',
                                  prefixIcon: Icon(Icons.phone_outlined),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      if (isMobile) ...[
                        TextFormField(
                          controller: _adresseController,
                          decoration: const InputDecoration(
                            labelText: 'Adresse / Ville',
                            prefixIcon: Icon(Icons.location_on_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _monnaie,
                          decoration: const InputDecoration(
                            labelText: 'Devise',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'FCFA', child: Text('FCFA (XOF/XAF)')),
                            DropdownMenuItem(value: 'EUR', child: Text('EUR (€)')),
                            DropdownMenuItem(value: 'USD', child: Text('USD (\$)')),
                          ],
                          onChanged: (v) => setState(() => _monnaie = v ?? 'FCFA'),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _adresseController,
                                decoration: const InputDecoration(
                                  labelText: 'Adresse / Ville',
                                  prefixIcon: Icon(Icons.location_on_outlined),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _monnaie,
                                decoration: const InputDecoration(
                                  labelText: 'Devise',
                                  border: OutlineInputBorder(),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'FCFA', child: Text('FCFA (XOF/XAF)')),
                                  DropdownMenuItem(value: 'EUR', child: Text('EUR (€)')),
                                  DropdownMenuItem(value: 'USD', child: Text('USD (\$)')),
                                ],
                                onChanged: (v) => setState(() => _monnaie = v ?? 'FCFA'),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 24),
                      const Text(
                        '2. Compte Administrateur Initial',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: QuantisColors.royalBlue),
                      ),
                      const SizedBox(height: 12),
                      if (isMobile) ...[
                        TextFormField(
                          controller: _adminNomController,
                          decoration: const InputDecoration(
                            labelText: 'Nom Admin *',
                            prefixIcon: Icon(Icons.person_outline),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Nom admin obligatoire' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _adminPrenomController,
                          decoration: const InputDecoration(
                            labelText: 'Prénom Admin *',
                            prefixIcon: Icon(Icons.person_outline),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Prénom admin obligatoire' : null,
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _adminNomController,
                                decoration: const InputDecoration(
                                  labelText: 'Nom Admin *',
                                  prefixIcon: Icon(Icons.person_outline),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) => v == null || v.trim().isEmpty ? 'Nom admin obligatoire' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _adminPrenomController,
                                decoration: const InputDecoration(
                                  labelText: 'Prénom Admin *',
                                  prefixIcon: Icon(Icons.person_outline),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) => v == null || v.trim().isEmpty ? 'Prénom admin obligatoire' : null,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _adminEmailController,
                        decoration: const InputDecoration(
                          labelText: 'Email de connexion Admin *',
                          prefixIcon: Icon(Icons.alternate_email),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Email obligatoire';
                          if (!v.contains('@')) return 'Email invalide';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _adminMotDePasseController,
                        decoration: const InputDecoration(
                          labelText: 'Mot de passe temporaire *',
                          prefixIcon: Icon(Icons.lock_outline),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.length < 6) ? 'Min 6 caractères' : null,
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 24),
              if (isMobile) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: QuantisColors.royalBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _isSaving ? null : _submit,
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Créer l\'entreprise'),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSaving ? null : () => Navigator.pop(context),
                      child: const Text('Annuler'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: QuantisColors.royalBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: _isSaving ? null : _submit,
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Créer l\'entreprise'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialogue affichant les utilisateurs de l'entreprise
class _EntrepriseUsersDialog extends StatefulWidget {
  final dynamic entreprise;
  const _EntrepriseUsersDialog({required this.entreprise});

  @override
  State<_EntrepriseUsersDialog> createState() => _EntrepriseUsersDialogState();
}

class _EntrepriseUsersDialogState extends State<_EntrepriseUsersDialog> {
  bool _isLoading = true;
  List<dynamic> _users = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final res = await ApiClient.instance.get('/platform/entreprises/${widget.entreprise['id']}/users');
      if (mounted) {
        setState(() {
          _users = res.data['data'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 580,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.people_alt, color: QuantisColors.royalBlue),
                    const SizedBox(width: 10),
                    Text(
                      'Utilisateurs de ${widget.entreprise['nom']}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 20),
            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()))
            else if (_error != null)
              Padding(padding: const EdgeInsets.all(16), child: Text('Erreur: $_error', style: const TextStyle(color: Colors.red)))
            else if (_users.isEmpty)
              const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('Aucun utilisateur trouvé')))
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 350),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _users.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, idx) {
                    final u = _users[idx];
                    final role = u['role'] ?? 'USER';
                    final bool isActif = u['actif'] == true;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: role == 'ADMIN' ? QuantisColors.luxuryGold : Colors.blueGrey.shade100,
                        child: Text(
                          (u['prenom'] ?? u['nom'] ?? 'U').toString().substring(0, 1).toUpperCase(),
                          style: TextStyle(
                            color: role == 'ADMIN' ? Colors.black87 : Colors.blueGrey.shade900,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text('${u['prenom'] ?? ''} ${u['nom'] ?? ''}'),
                      subtitle: Text('${u['email']} • Rôle: $role'),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isActif ? Colors.green.shade50 : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isActif ? Colors.green : Colors.red),
                        ),
                        child: Text(
                          isActif ? 'Actif' : 'Inactif',
                          style: TextStyle(fontSize: 10, color: isActif ? Colors.green.shade900 : Colors.red.shade900),
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialogue de réinitialisation de mot de passe administrateur
class _ResetAdminPasswordDialog extends StatefulWidget {
  final dynamic entreprise;
  const _ResetAdminPasswordDialog({required this.entreprise});

  @override
  State<_ResetAdminPasswordDialog> createState() => _ResetAdminPasswordDialogState();
}

class _ResetAdminPasswordDialogState extends State<_ResetAdminPasswordDialog> {
  final _controller = TextEditingController(text: 'Admin@2026');
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pwd = _controller.text.trim();
    if (pwd.length < 6) {
      setState(() => _error = 'Le mot de passe doit comporter au moins 6 caractères');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await ApiClient.instance.post(
        '/platform/entreprises/${widget.entreprise['id']}/reset-admin-password',
        data: {'newPassword': pwd},
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mot de passe de l\'administrateur réinitialisé avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erreur : $e';
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.vpn_key_outlined, color: QuantisColors.royalBlue),
          const SizedBox(width: 10),
          Text('Reset Mot de Passe Admin'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Réinitialiser le mot de passe du compte administrateur de ${widget.entreprise['nom']} (${widget.entreprise['adminEmail'] ?? 'Admin'}).',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Nouveau mot de passe',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: QuantisColors.royalBlue,
            foregroundColor: Colors.white,
          ),
          onPressed: _isSaving ? null : _submit,
          child: _isSaving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Confirmer le changement'),
        ),
      ],
    );
  }
}

/// Dialogue de supervision financière et opérationnelle approfondie d'une entreprise
class _EntrepriseSupervisionDialog extends StatefulWidget {
  final dynamic entreprise;
  const _EntrepriseSupervisionDialog({required this.entreprise});

  @override
  State<_EntrepriseSupervisionDialog> createState() => _EntrepriseSupervisionDialogState();
}

class _EntrepriseSupervisionDialogState extends State<_EntrepriseSupervisionDialog> with SingleTickerProviderStateMixin {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _supervision;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSupervision();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSupervision() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await ApiClient.instance.get('/platform/entreprises/${widget.entreprise['id']}/supervision');
      if (mounted) {
        setState(() {
          _supervision = res.data is Map ? res.data['data'] : null;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erreur lors de la récupération des indicateurs de supervision: $e';
          _loading = false;
        });
      }
    }
  }

  String _formatCurrency(dynamic val, [String currency = 'FCFA']) {
    if (val == null) return '0 $currency';
    final num numVal = val is num ? val : (num.tryParse(val.toString()) ?? 0);
    final String str = numVal.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write(' ');
      }
      buffer.write(str[i]);
    }
    return '${buffer.toString()} $currency';
  }

  @override
  Widget build(BuildContext context) {
    final ent = widget.entreprise;
    final String nom = _supervision?['entrepriseNom'] ?? ent['nom'] ?? 'Entreprise';
    final String monnaie = _supervision?['monnaie'] ?? ent['monnaie'] ?? 'FCFA';
    final bool isActif = ent['estActif'] == true;

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 700;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 40,
        vertical: 16,
      ),
      child: Container(
        width: isMobile ? screenWidth * 0.95 : 960,
        height: isMobile ? MediaQuery.of(context).size.height * 0.9 : 720,
        padding: EdgeInsets.all(isMobile ? 14 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header modal
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: isMobile ? 42 : 52,
                  height: isMobile ? 42 : 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [QuantisColors.royalBlue, Color(0xFF0F172A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      nom.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        color: QuantisColors.luxuryGold,
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? 20 : 24,
                        fontFamily: 'SpaceGrotesk',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              nom,
                              style: TextStyle(
                                fontSize: isMobile ? 17 : 20,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'SpaceGrotesk',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isActif ? Colors.green.shade50 : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isActif ? Colors.green : Colors.red),
                            ),
                            child: Text(
                              isActif ? 'ACTIF' : 'SUSPENDU',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isActif ? Colors.green.shade800 : Colors.red.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID: #${ent['id']} • IFU: ${ent['nif'] ?? 'N/A'} • RCCM: ${ent['rccm'] ?? 'N/A'} • Devise: $monnaie',
                        style: TextStyle(fontSize: isMobile ? 11 : 12, color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Actualiser',
                  onPressed: _loadSupervision,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Fermer',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Contenu
            Expanded(
              child: _loading
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Calcul des métriques financières et chargement des flux...'),
                        ],
                      ),
                    )
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: Colors.red),
                              const SizedBox(height: 12),
                              Text(_error!, style: const TextStyle(color: Colors.red)),
                              const SizedBox(height: 12),
                              ElevatedButton(onPressed: _loadSupervision, child: const Text('Réessayer')),
                            ],
                          ),
                        )
                      : _buildSupervisionContent(monnaie, isMobile),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupervisionContent(String monnaie, bool isMobile) {
    final data = _supervision ?? {};
    final ca = data['chiffreAffaires'] ?? 0;
    final achats = data['totalAchats'] ?? 0;
    final marge = data['margeBrute'] ?? 0;
    final soldeCaisse = data['soldeCaisse'] ?? 0;

    final ventesCount = data['ventesCount'] ?? 0;
    final achatsCount = data['achatsCount'] ?? 0;
    final clientsCount = data['clientsCount'] ?? 0;
    final fournisseursCount = data['fournisseursCount'] ?? 0;
    final produitsCount = data['produitsCount'] ?? 0;
    final utilisateursCount = data['utilisateursCount'] ?? 0;

    final List<dynamic> dernieresVentes = data['dernieresVentes'] ?? [];
    final List<dynamic> derniersAchats = data['derniersAchats'] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 4 KPI financiers principaux
        if (isMobile) ...[
          Row(
            children: [
              Expanded(
                child: _buildKpiBox(
                  'Chiffre d\'Affaires',
                  _formatCurrency(ca, monnaie),
                  '$ventesCount vente(s)',
                  const Color(0xFF059669),
                  Icons.trending_up_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildKpiBox(
                  'Achats Fourn.',
                  _formatCurrency(achats, monnaie),
                  '$achatsCount cde(s)',
                  const Color(0xFFD97706),
                  Icons.shopping_bag_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildKpiBox(
                  'Marge Commerciale',
                  _formatCurrency(marge, monnaie),
                  (ca is num && ca > 0)
                      ? '${((marge as num) / ca * 100).toStringAsFixed(1)}% CA'
                      : 'Marge directe',
                  (marge as num) >= 0 ? QuantisColors.royalBlue : Colors.red.shade700,
                  Icons.account_balance_wallet_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildKpiBox(
                  'Trésorerie Caisse',
                  _formatCurrency(soldeCaisse, monnaie),
                  'Disponible',
                  const Color(0xFF4F46E5),
                  Icons.savings_outlined,
                ),
              ),
            ],
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: _buildKpiBox(
                  'Chiffre d\'Affaires (CA)',
                  _formatCurrency(ca, monnaie),
                  '$ventesCount vente(s) formalisée(s)',
                  const Color(0xFF059669),
                  Icons.trending_up_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKpiBox(
                  'Achats Fournisseurs',
                  _formatCurrency(achats, monnaie),
                  '$achatsCount commande(s) d\'approvisionnement',
                  const Color(0xFFD97706),
                  Icons.shopping_bag_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKpiBox(
                  'Marge Commerciale Brute',
                  _formatCurrency(marge, monnaie),
                  (ca is num && ca > 0)
                      ? 'Taux: ${((marge as num) / ca * 100).toStringAsFixed(1)}% du CA'
                      : 'Marge directe',
                  (marge as num) >= 0 ? QuantisColors.royalBlue : Colors.red.shade700,
                  Icons.account_balance_wallet_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKpiBox(
                  'Trésorerie / Caisse',
                  _formatCurrency(soldeCaisse, monnaie),
                  'Solde net disponible',
                  const Color(0xFF4F46E5),
                  Icons.savings_outlined,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),

        // Périmètre d'activité (badges avec Wrap pour éviter tout overflow)
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 6,
            alignment: WrapAlignment.spaceAround,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildScopeItem(Icons.business, '$clientsCount Clients', Colors.blueGrey),
              _buildScopeItem(Icons.local_shipping_outlined, '$fournisseursCount Fournisseurs', Colors.amber.shade900),
              _buildScopeItem(Icons.inventory_2_outlined, '$produitsCount Articles Stock', Colors.teal.shade800),
              _buildScopeItem(Icons.group_outlined, '$utilisateursCount Utilisateurs', Colors.purple.shade700),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Onglets Ventes & Achats
        TabBar(
          controller: _tabController,
          labelColor: QuantisColors.royalBlue,
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: QuantisColors.royalBlue,
          indicatorWeight: 3,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.receipt_long, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    isMobile ? 'Ventes (${dernieresVentes.length})' : 'Dernières Ventes (${dernieresVentes.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shopping_cart_checkout, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    isMobile ? 'Achats (${derniersAchats.length})' : 'Derniers Achats Fournisseurs (${derniersAchats.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Tab Views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Vue Ventes
              dernieresVentes.isEmpty
                  ? _buildEmptyTabState('Aucune vente formalisée enregistrée pour cette entreprise.')
                  : ListView.separated(
                      itemCount: dernieresVentes.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final v = dernieresVentes[i];
                        final statut = v['statut'] ?? 'VALIDE';
                        final isPaye = statut == 'PAYE' || statut == 'VALIDE';

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF059669).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.receipt, color: Color(0xFF059669), size: 20),
                          ),
                          title: Row(
                            children: [
                              Text(
                                v['numero'] ?? 'Sans numéro',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  v['type'] ?? 'FACTURE',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isPaye ? Colors.green.shade50 : Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  statut,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isPaye ? Colors.green.shade800 : Colors.orange.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text('Client: ${v['clientNom'] ?? 'Client Standard'} • Date: ${v['date'] ?? 'N/A'}'),
                          trailing: Text(
                            _formatCurrency(v['totalTtc'], monnaie),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'SpaceGrotesk',
                              color: Color(0xFF059669),
                            ),
                          ),
                        );
                      },
                    ),

              // Vue Achats
              derniersAchats.isEmpty
                  ? _buildEmptyTabState('Aucune commande fournisseur enregistrée pour cette entreprise.')
                  : ListView.separated(
                      itemCount: derniersAchats.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final a = derniersAchats[i];
                        final statut = a['statut'] ?? 'RECUE';
                        final isRecue = statut == 'RECUE';

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD97706).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.shopping_cart, color: Color(0xFFD97706), size: 20),
                          ),
                          title: Row(
                            children: [
                              Text(
                                a['numero'] ?? 'Sans numéro',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isRecue ? Colors.green.shade50 : Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  statut,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isRecue ? Colors.green.shade800 : Colors.amber.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text('Fournisseur: ${a['fournisseurNom'] ?? 'Fournisseur'} • Date: ${a['date'] ?? 'N/A'}'),
                          trailing: Text(
                            _formatCurrency(a['totalHt'], monnaie),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'SpaceGrotesk',
                              color: Color(0xFFD97706),
                            ),
                          ),
                        );
                      },
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKpiBox(String title, String value, String subtitle, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
              ),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
                fontFamily: 'SpaceGrotesk',
              ),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildScopeItem(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
        ),
      ],
    );
  }

  Widget _buildEmptyTabState(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          Text(message, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        ],
      ),
    );
  }
}

/// Dialogue de renouvellement de licence et abonnement par le Super Admin
class _RenewLicenceDialog extends StatefulWidget {
  final dynamic entreprise;
  final VoidCallback onSuccess;

  const _RenewLicenceDialog({
    required this.entreprise,
    required this.onSuccess,
  });

  @override
  State<_RenewLicenceDialog> createState() => _RenewLicenceDialogState();
}

class _RenewLicenceDialogState extends State<_RenewLicenceDialog> {
  int _nbMois = 1;
  final _refController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _refController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final res = await ApiClient.instance.post(
        '/platform/entreprises/${widget.entreprise['id']}/renew-licence',
        data: {
          'nbMois': _nbMois,
          'referencePaiement': _refController.text.trim().isNotEmpty
              ? _refController.text.trim()
              : 'Paiement USSD *144*2*1*65189261*20200# ($_nbMois mois)',
          'notes': _notesController.text.trim(),
        },
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        final String newDate = res.data is Map && res.data['data'] != null
            ? (res.data['data']['dateExpirationLicence'] ?? 'fin de mois')
            : 'prochain mois';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.verified, color: Colors.white),
                const SizedBox(width: 8),
                Text('Licence de ${widget.entreprise['nom']} renouvelée jusqu\'au $newDate !'),
              ],
            ),
            backgroundColor: Colors.green.shade800,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erreur: $e';
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ent = widget.entreprise;
    final String currentExp = ent['dateExpirationLicence'] ?? 'Expirée';
    final int tarifTotal = _nbMois * 20200;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: QuantisColors.luxuryGold.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.vpn_key_rounded, color: QuantisColors.royalBlue, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Renouveler la Licence / Abonnement', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                Text(ent['nom'] ?? 'Entreprise', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: QuantisColors.royalBlue, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Échéance actuelle : $currentExp\nTarif standard : 20 200 FCFA / mois (*144*2*1*65189261*20200#)',
                        style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                const SizedBox(height: 8),
              ],
              const Text('Durée du renouvellement :', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              DropdownButtonFormField<int>(
                value: _nbMois,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('1 Mois (20 200 FCFA)')),
                  DropdownMenuItem(value: 2, child: Text('2 Mois (40 400 FCFA)')),
                  DropdownMenuItem(value: 3, child: Text('1 Trimestre / 3 Mois (60 600 FCFA)')),
                  DropdownMenuItem(value: 6, child: Text('Semestre / 6 Mois (121 200 FCFA)')),
                  DropdownMenuItem(value: 12, child: Text('Année complète / 12 Mois (242 400 FCFA)')),
                ],
                onChanged: (v) => setState(() => _nbMois = v ?? 1),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _refController,
                decoration: const InputDecoration(
                  labelText: 'Réf. Paiement Orange Money / N° Téléphone',
                  hintText: 'Ex: OM-2026-987654 ou +226 70 00 00 00',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.receipt_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Commentaire Super-Admin (Optionnel)',
                  hintText: 'Ex: Paiement validé par Orange Money',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note_alt_outlined),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Montant total confirmé :', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      '$tarifTotal FCFA',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF059669)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF059669),
            foregroundColor: Colors.white,
          ),
          onPressed: _isSaving ? null : _submit,
          child: _isSaving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Valider & Réactiver la Licence'),
        ),
      ],
    );
  }
}
