import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/quantis_theme.dart';
import '../../../core/utils/permission_helper.dart';
import '../../comptabilite/presentation/session_caisse_dialog.dart';
import '../../core/presentation/command_palette_dialog.dart';
import '../../tiers/presentation/debiteurs_screen.dart';
import '../../produits/presentation/produits_screen.dart';
import '../../stock/presentation/stock_screen.dart';
import '../../sales/presentation/pos_screen.dart';
import '../../documents/presentation/documents_screen.dart';
import '../../auth/presentation/change_password_dialog.dart';
import '../../comptabilite/presentation/comptabilite_screen.dart';
import '../../reports/presentation/exports_screen.dart';

/// Tableau de bord axé sur les ACTIONS rapides par rôle + Synthèse du Patrimoine d'Entreprise.
class ActionDashboardScreen extends StatefulWidget {
  final Function(int navIndex)? onNavigate;

  const ActionDashboardScreen({super.key, this.onNavigate});

  @override
  State<ActionDashboardScreen> createState() => _ActionDashboardScreenState();
}

class _ActionDashboardScreenState extends State<ActionDashboardScreen> {
  final ApiClient _api = ApiClient();

  Map<String, dynamic>? _activeSession;
  Map<String, dynamic>? _patrimoine;
  bool _loading = true;
  String _userRole = 'ADMIN';

  @override
  void initState() {
    super.initState();
    _userRole = ApiClient.userRole ?? 'ADMIN';
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _loading = true);
    try {
      final sessionFuture = _api.get('/caisses/session-active');
      final patrimoineFuture = _api.get('/dashboard/patrimoine');

      final results = await Future.wait([
        sessionFuture.catchError((_) => null as dynamic),
        patrimoineFuture.catchError((_) => null as dynamic),
      ]);

      if (mounted) {
        setState(() {
          final dynamic res0 = results[0];
          final dynamic res1 = results[1];
          if (res0 != null) {
            _activeSession = res0.data?['data'] as Map<String, dynamic>?;
          }
          if (res1 != null) {
            _patrimoine = res1.data?['data'] as Map<String, dynamic>?;
          }
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openSessionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => SessionCaisseDialog(
        activeSession: _activeSession,
        onSessionChanged: _loadDashboardData,
      ),
    );
  }

  void _openCommandPalette() {
    showDialog(
      context: context,
      builder: (ctx) => const CommandPaletteDialog(),
    );
  }

  void _openDebiteursScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DebiteursScreen()),
    ).then((_) => _loadDashboardData());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ApiClient.userEmail ?? 'Utilisateur';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.storefront, color: QuantisColors.royalBlue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Quantis-Stock — ${ApiClient.entrepriseNom}',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: QuantisColors.royalBlue),
            tooltip: 'Recherche universelle (Ctrl+K)',
            onPressed: _openCommandPalette,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
            onPressed: _loadDashboardData,
          ),
          PopupMenuButton<String>(
            tooltip: 'Compte & Sécurité',
            offset: const Offset(0, 36),
            child: Container(
              margin: const EdgeInsets.only(right: 16, left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: QuantisColors.royalBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: QuantisColors.royalBlue.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _userRole,
                    style: const TextStyle(color: QuantisColors.royalBlue, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down, size: 16, color: QuantisColors.royalBlue),
                ],
              ),
            ),
            onSelected: (val) {
              if (val == 'password') {
                showDialog(
                  context: context,
                  builder: (_) => const ChangePasswordDialog(),
                );
              } else if (val == 'logout') {
                ApiClient.clearToken();
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'header',
                enabled: false,
                child: Text(ApiClient.userEmail ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'password',
                child: Row(
                  children: [
                    Icon(Icons.lock_reset_rounded, size: 18, color: QuantisColors.royalBlue),
                    SizedBox(width: 8),
                    Text('Modifier mot de passe'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 18, color: QuantisColors.error),
                    SizedBox(width: 8),
                    Text('Déconnexion', style: TextStyle(color: QuantisColors.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner Welcome
              _buildWelcomeBanner(user),
              const SizedBox(height: 24),

              // SYNTHÈSE DU PATRIMOINE D'ENTREPRISE (NAFA STOCK REFERENCE)
              if (PermissionHelper.canViewDashboard) ...[
                _buildPatrimoineSection(),
                const SizedBox(height: 28),
              ],

              // Action Buttons Section (Section 3.1)
              Builder(
                builder: (context) {
                  final bool isMobile = MediaQuery.of(context).size.width < 600;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'ACTIONS RAPIDES',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: QuantisColors.textMuted,
                            letterSpacing: 1.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _openCommandPalette,
                        icon: const Icon(Icons.search, size: 16),
                        label: Text(isMobile ? 'Rechercher' : 'Recherche rapide (Ctrl+K)', style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildActionGrid(),
              const SizedBox(height: 28),

              // Status Session Caisse Widget
              if (PermissionHelper.hasPermission('JOURNAL_CAISSE') || PermissionHelper.hasPermission('PAIEMENT_CLIENT'))
                _buildCaisseStatusCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner(String email) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [QuantisColors.royalBlue, Color(0xFF1E3A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: QuantisColors.royalBlue.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: const Icon(Icons.person, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bienvenue sur Quantis-Stock', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                  email.contains('@') ? email.split('@').first.toUpperCase() : email.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: _openCommandPalette,
            icon: const Icon(Icons.search, size: 18),
            label: const Text('Rechercher'),
            style: ElevatedButton.styleFrom(
              backgroundColor: QuantisColors.luxuryGold,
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // SYNTHÈSE DU PATRIMOINE NET D'ENTREPRISE (Valeur Stock + Caisses + Créances - Dettes)
  // =========================================================================
  Widget _buildPatrimoineSection() {
    final monnaie = ApiClient.entrepriseMonnaie;
    final double net = (_patrimoine?['patrimoineNet'] as num?)?.toDouble() ?? 0.0;
    final double stock = (_patrimoine?['valeurStock'] as num?)?.toDouble() ?? 0.0;
    final double caisses = (_patrimoine?['soldeCaisses'] as num?)?.toDouble() ?? 0.0;
    final double creances = (_patrimoine?['creancesClients'] as num?)?.toDouble() ?? 0.0;
    final double dettes = (_patrimoine?['dettesFournisseurs'] as num?)?.toDouble() ?? 0.0;
    final int nbDebiteurs = (_patrimoine?['nbDebiteurs'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête Patrimoine Net
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 500;
              if (isSmall) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.account_balance, color: QuantisColors.royalBlue, size: 18),
                            SizedBox(width: 6),
                            Text(
                              'PATRIMOINE NET',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: QuantisColors.textMuted, letterSpacing: 0.8),
                            ),
                          ],
                        ),
                        OutlinedButton.icon(
                          onPressed: _openDebiteursScreen,
                          icon: const Icon(Icons.people_alt, size: 14),
                          label: Text(nbDebiteurs > 0 ? '$nbDebiteurs Débiteurs' : 'Débiteurs', style: const TextStyle(fontSize: 11)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.amber.shade900,
                            side: BorderSide(color: Colors.amber.shade400),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${net.toStringAsFixed(0)} $monnaie',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: net >= 0 ? const Color(0xFF0F172A) : QuantisColors.error,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Stock + Caisses + Créances − Dettes',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.account_balance, color: QuantisColors.royalBlue, size: 20),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'PATRIMOINE NET DE L\'ENTREPRISE',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: QuantisColors.textMuted, letterSpacing: 0.8),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${net.toStringAsFixed(0)} $monnaie',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: net >= 0 ? const Color(0xFF0F172A) : QuantisColors.error,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Formule de synthèse : Stock + Caisses + Créances Clients − Dettes Fournisseurs',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _openDebiteursScreen,
                    icon: const Icon(Icons.people_alt, size: 16),
                    label: Text(nbDebiteurs > 0 ? '$nbDebiteurs Débiteurs' : 'Débiteurs'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.amber.shade900,
                      side: BorderSide(color: Colors.amber.shade400),
                    ),
                  ),
                ],
              );
            },
          ),
          const Divider(height: 28),

          // 4 Cadrans Financiers
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              return isWide
                  ? Row(
                      children: [
                        Expanded(child: _patrimoineMetric('Valeur du Stock', '${stock.toStringAsFixed(0)} $monnaie', Icons.inventory_2, QuantisColors.royalBlue, 'Valorisation PMP/Achat')),
                        const SizedBox(width: 12),
                        Expanded(child: _patrimoineMetric('Solde Caisses', '${caisses.toStringAsFixed(0)} $monnaie', Icons.point_of_sale, QuantisColors.success, 'Trésorerie disponible')),
                        const SizedBox(width: 12),
                        Expanded(child: _patrimoineMetric('Créances Clients', '${creances.toStringAsFixed(0)} $monnaie', Icons.account_balance_wallet, Colors.amber.shade900, '$nbDebiteurs clients à crédit', onTap: _openDebiteursScreen)),
                        const SizedBox(width: 12),
                        Expanded(child: _patrimoineMetric('Dettes Fournisseurs', '${dettes.toStringAsFixed(0)} $monnaie', Icons.local_shipping, QuantisColors.error, 'Factures à payer')),
                      ],
                    )
                  : Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: _patrimoineMetric('Valeur Stock', '${stock.toStringAsFixed(0)} $monnaie', Icons.inventory_2, QuantisColors.royalBlue, 'Valorisation PMP')),
                            const SizedBox(width: 12),
                            Expanded(child: _patrimoineMetric('Caisses', '${caisses.toStringAsFixed(0)} $monnaie', Icons.point_of_sale, QuantisColors.success, 'Trésorerie dispo')),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _patrimoineMetric('Créances', '${creances.toStringAsFixed(0)} $monnaie', Icons.account_balance_wallet, Colors.amber.shade900, '$nbDebiteurs débiteurs', onTap: _openDebiteursScreen)),
                            const SizedBox(width: 12),
                            Expanded(child: _patrimoineMetric('Dettes Fourn.', '${dettes.toStringAsFixed(0)} $monnaie', Icons.local_shipping, QuantisColors.error, 'À régler')),
                          ],
                        ),
                      ],
                    );
            },
          ),
        ],
      ),
    );
  }

  Widget _patrimoineMetric(String title, String value, IconData icon, Color color, String subtitle, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionGrid() {
    final actions = <Widget>[];

    if (PermissionHelper.canAccessPos) {
      actions.add(_actionCard(
        'Caisse POS',
        'Vente rapide & encaissement',
        Icons.point_of_sale,
        QuantisColors.success,
        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PosScreen())),
      ));
    }

    if (PermissionHelper.canAccessDocuments) {
      actions.add(_actionCard(
        'Factures & Devis',
        'Gestion commerciale',
        Icons.receipt_long,
        QuantisColors.royalBlue,
        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DocumentsScreen())),
      ));
    }

    if (PermissionHelper.canAccessProduits) {
      actions.add(_actionCard(
        'Catalogue Articles',
        'Créer & gérer produits',
        Icons.category,
        Colors.indigo,
        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProduitsScreen())),
      ));
    }

    if (PermissionHelper.canAccessStock) {
      actions.add(_actionCard(
        'Gestion Stock',
        'Entrées, sorties & inventaire',
        Icons.inventory_2,
        Colors.teal,
        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StockScreen())),
      ));
    }

    if (PermissionHelper.canAccessDebiteurs) {
      actions.add(_actionCard(
        'Suivi Débiteurs',
        'Créances à recouvrer',
        Icons.account_balance_wallet,
        Colors.amber.shade900,
        _openDebiteursScreen,
      ));
    }

    if (PermissionHelper.hasPermission('JOURNAL_CAISSE') || PermissionHelper.hasPermission('PAIEMENT_CLIENT')) {
      actions.add(_actionCard(
        _activeSession != null ? 'Session Caisse (Ouverte)' : 'Ouvrir Caisse',
        _activeSession != null ? 'Fond & clôture' : 'Initialiser session',
        Icons.savings,
        Colors.purple,
        _openSessionDialog,
      ));
    }

    if (PermissionHelper.canAccessComptabilite) {
      actions.add(_actionCard(
        'Caisse & Compta',
        'Journal, sessions & Grand Livre',
        Icons.account_balance_wallet,
        QuantisColors.royalBlue,
        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ComptabiliteScreen())),
      ));
    }

    if (PermissionHelper.canAccessExports) {
      actions.add(_actionCard(
        'Exports Compta',
        'Grand Livre CSV, TVA & caisse',
        Icons.table_view_outlined,
        Colors.teal,
        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExportsScreen())),
      ));
    }

    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 600 ? 2 : 1);
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 2.2,
          children: actions,
        );
      },
    );
  }

  Widget _actionCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 11, color: QuantisColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCaisseStatusCard() {
    if (_loading) return const SizedBox.shrink();

    final isOpen = _activeSession != null;
    final solde = isOpen ? (_activeSession!['soldeTheorique'] as num? ?? 0).toDouble() : 0.0;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isOpen ? QuantisColors.success.withValues(alpha: 0.05) : Colors.amber.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              isOpen ? Icons.check_circle : Icons.warning_amber_rounded,
              color: isOpen ? QuantisColors.success : Colors.amber.shade800,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOpen ? 'Session de Caisse Active' : 'Aucune Caisse Ouverte',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isOpen ? QuantisColors.success : Colors.amber.shade800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isOpen
                        ? 'Solde théorique : ${solde.toStringAsFixed(0)} ${ApiClient.entrepriseMonnaie}'
                        : 'Ouvrez une session de caisse pour enregistrer les encaissements.',
                    style: const TextStyle(fontSize: 12, color: QuantisColors.textMuted),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: _openSessionDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: isOpen ? QuantisColors.warning : QuantisColors.royalBlue,
                foregroundColor: Colors.white,
              ),
              child: Text(isOpen ? 'Fermer' : 'Ouvrir'),
            ),
          ],
        ),
      ),
    );
  }
}
