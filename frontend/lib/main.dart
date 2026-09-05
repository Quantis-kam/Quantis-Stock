import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/quantis_theme.dart';
import 'core/network/api_client.dart';
import 'core/widgets/sync_indicator.dart';
import 'core/widgets/command_palette_dialog.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/dashboard/presentation/action_dashboard_screen.dart';
import 'features/sales/presentation/debiteurs_screen.dart';
import 'features/stock/presentation/arret_stock_screen.dart';
import 'features/tiers/presentation/clients_screen.dart';
import 'features/tiers/presentation/fournisseurs_screen.dart';
import 'features/achats/presentation/achats_screen.dart';
import 'features/sales/presentation/pos_screen.dart';
import 'features/documents/presentation/documents_screen.dart';
import 'features/comptabilite/presentation/comptabilite_screen.dart';
import 'features/stock/presentation/stock_screen.dart';
import 'features/auth/presentation/entreprise_screen.dart';
import 'features/auth/presentation/users_screen.dart';
import 'features/reports/presentation/exports_screen.dart';
import 'features/auth/presentation/audit_logs_screen.dart';
import 'features/auth/presentation/change_password_dialog.dart';
import 'features/quantis_ai/presentation/quantis_ai_launcher.dart';
import 'features/quantis_ai/services/quantis_voice_service.dart';
import 'features/produits/presentation/produits_screen.dart';
import 'features/admin/presentation/platform_admin_portal.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiClient.initialize();
  runApp(const ProviderScope(child: QuantisStockApp()));
}

class QuantisStockApp extends StatefulWidget {
  const QuantisStockApp({super.key});

  @override
  State<QuantisStockApp> createState() => _QuantisStockAppState();
}

class _QuantisStockAppState extends State<QuantisStockApp> {
  @override
  void initState() {
    super.initState();
    ApiClient.authStateNotifier.addListener(_onAuthChanged);
    // Auto-logout quand le refresh token expire
    ApiClient.onSessionExpired = () {
      ApiClient.clearToken();
    };
  }

  void _onAuthChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ApiClient.authStateNotifier.removeListener(_onAuthChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      key: ValueKey('${ApiClient.isAuthenticated}_${ApiClient.isSuperAdmin}'),
      title: 'Quantis-Stock',
      debugShowCheckedModeBanner: false,
      theme: QuantisTheme.lightTheme,
      darkTheme: QuantisTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: ApiClient.isAuthenticated
          ? (ApiClient.isSuperAdmin ? const PlatformAdminPortal() : const MainShell())
          : const LoginScreen(),
    );
  }
}

/// Shell principal avec navigation simplifiée (V2 UX Refactoring).
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  List<_NavItem> get _desktopItems {
    return [
      _NavItem(Icons.insights_outlined, Icons.insights, 'Tableau de bord', ActionDashboardScreen(onNavigate: (idx) => setState(() => _currentIndex = idx))),
      _NavItem(Icons.auto_awesome_outlined, Icons.auto_awesome, 'Quantis AI', const QuantisAiScreen()),
      _NavItem(Icons.point_of_sale_outlined, Icons.point_of_sale, 'Caisse POS', const PosScreen()),
      _NavItem(Icons.receipt_long_outlined, Icons.receipt_long, 'Factures & Devis', const DocumentsScreen()),
      _NavItem(Icons.category_outlined, Icons.category, 'Articles & Produits', const ProduitsScreen()),
      _NavItem(Icons.people_alt_outlined, Icons.people, 'Clients', const ClientsScreen()),
      _NavItem(Icons.inventory_2_outlined, Icons.inventory_2, 'Stock', const StockScreen()),
      _NavItem(Icons.camera_alt_outlined, Icons.camera_alt, 'Arrêts Stock', const ArretStockScreen()),
      _NavItem(Icons.shopping_cart_outlined, Icons.shopping_cart, 'Achats', const AchatsScreen()),
      _NavItem(Icons.business_outlined, Icons.business, 'Fournisseurs', const FournisseursScreen()),
      _NavItem(Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, 'Caisse & Compta', const ComptabiliteScreen()),
      _NavItem(Icons.table_view_outlined, Icons.table_view, 'Exports Compta', const ExportsScreen()),
      _NavItem(Icons.storefront_outlined, Icons.storefront, 'Entreprise', const EntrepriseScreen()),
      _NavItem(Icons.manage_accounts_outlined, Icons.manage_accounts, 'Utilisateurs', const UsersScreen()),
      _NavItem(Icons.history_edu_outlined, Icons.history_edu, 'Logs Audit', const AuditLogsScreen()),
    ];
  }

  List<_NavItem> get _mobileItems {
    return [
      _NavItem(Icons.insights_outlined, Icons.insights, 'Rapports', ActionDashboardScreen(onNavigate: (idx) => setState(() => _currentIndex = idx))),
      _NavItem(Icons.point_of_sale_outlined, Icons.point_of_sale, 'Caisse POS', const PosScreen()),
      _NavItem(Icons.receipt_long_outlined, Icons.receipt_long, 'Factures', const DocumentsScreen()),
      _NavItem(Icons.inventory_2_outlined, Icons.inventory_2, 'Stock', const StockScreen()),
      _NavItem(Icons.more_horiz_outlined, Icons.more_horiz, 'Plus', _buildPlusMenu()),
    ];
  }

  Widget _buildPlusMenu() {
    return Scaffold(
      appBar: AppBar(title: const Text('Menu Plus & Paramètres')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [QuantisColors.royalBlue, QuantisColors.blueDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: QuantisColors.luxuryGold, width: 1.5),
            ),
            child: ListTile(
              leading: const Icon(Icons.auto_awesome, color: QuantisColors.luxuryGold),
              title: const Text(
                'Quantis AI Assistant',
                style: TextStyle(
                  color: QuantisColors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text(
                'Expert en stock & actions automatisées',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right, color: QuantisColors.luxuryGold),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QuantisAiScreen()),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.category, color: QuantisColors.royalBlue),
            title: const Text('Catalogue Articles & Produits'),
            subtitle: const Text('Créer des articles, prix, marges, codes-barres et catégories'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProduitsScreen())),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.people, color: QuantisColors.royalBlue),
            title: const Text('Clients & Débiteurs'),
            subtitle: const Text('Gestion de la base clients et créances'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientsScreen())),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.account_balance, color: Colors.amber),
            title: const Text('Vue Débiteurs & Créances'),
            subtitle: const Text('Gestion dédiée des impayés et relances'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DebiteursScreen())),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.camera_alt, color: QuantisColors.royalBlue),
            title: const Text('Arrêts de Stock (Snapshots)'),
            subtitle: const Text('Gel du stock et audits de valorisation'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ArretStockScreen())),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.business, color: Colors.teal),
            title: const Text('Fournisseurs'),
            subtitle: const Text('Gestion des partenaires et achats'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FournisseursScreen())),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.shopping_cart, color: Colors.purple),
            title: const Text('Commandes Achats'),
            subtitle: const Text('Achats fournisseurs et approvisionnement'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AchatsScreen())),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.storefront, color: QuantisColors.royalBlue),
            title: const Text('Profil Entreprise & Logo'),
            subtitle: const Text('Raison sociale, NIF, RCCM, logo, devise et facturation'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EntrepriseScreen())),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.manage_accounts, color: QuantisColors.luxuryGold),
            title: const Text('Utilisateurs & Permissions'),
            subtitle: const Text('Gestion des comptes et droits granulaires'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UsersScreen())),
          ),
          const Divider(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.lock_reset, color: QuantisColors.royalBlue),
            title: const Text('Modifier mon mot de passe'),
            subtitle: const Text('Sécurité et accès au compte'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showDialog(
              context: context,
              builder: (_) => const ChangePasswordDialog(),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: QuantisColors.error),
            title: const Text('Déconnexion', style: TextStyle(color: QuantisColors.error, fontWeight: FontWeight.bold)),
            subtitle: const Text('Quitter la session en cours'),
            trailing: const Icon(Icons.chevron_right, color: QuantisColors.error),
            onTap: _logout,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPage(int index, bool isWide) {
    final items = isWide ? _desktopItems : _mobileItems;
    if (index < 0 || index >= items.length) {
      return const ActionDashboardScreen();
    }
    return items[index].page;
  }

  Future<void> _logout() async {
    try {
      await ApiClient.instance.post('/auth/logout');
    } catch (_) {}
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    ApiClient.clearToken();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;
    final items = isWide ? _desktopItems : _mobileItems;

    // Ajuster l'index si la liste d'items a changé
    if (_currentIndex >= items.length) {
      _currentIndex = 0;
    }

    final shortcuts = {
      const SingleActivator(LogicalKeyboardKey.keyK, control: true): () => CommandPaletteDialog.show(
        context,
        onNavigate: (i) => setState(() => _currentIndex = i),
        onOpenAi: () => showQuantisAiChat(context),
      ),
      const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () => CommandPaletteDialog.show(
        context,
        onNavigate: (i) => setState(() => _currentIndex = i),
        onOpenAi: () => showQuantisAiChat(context),
      ),
      const SingleActivator(LogicalKeyboardKey.space, control: true): () {
        QuantisVoiceService().startListening();
      },
      const SingleActivator(LogicalKeyboardKey.space, meta: true): () {
        QuantisVoiceService().startListening();
      },
    };

    final Widget content;
    if (isWide) {
      content = CallbackShortcuts(
        bindings: shortcuts,
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: Row(
              children: [
                Container(
                  width: 80,
                  color: QuantisColors.royalBlue,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Padding(
                              padding: const EdgeInsets.all(2.5),
                              child: Image.asset(
                                'assets/images/quantis_emblem_circle.png',
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Text('Q', style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: QuantisColors.royalBlue,
                                    fontSize: 22,
                                  )),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Divider(color: Colors.white12, height: 1),
                      Expanded(
                        child: ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (context, idx) {
                            final item = items[idx];
                            final isSelected = _currentIndex == idx;
                            return Tooltip(
                              message: item.label,
                              waitDuration: const Duration(milliseconds: 300),
                              child: InkWell(
                                onTap: () => setState(() => _currentIndex = idx),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.white.withValues(alpha: 0.15) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: isSelected ? Border.all(color: QuantisColors.luxuryGold, width: 1.2) : null,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isSelected ? item.selectedIcon : item.icon,
                                        color: isSelected ? QuantisColors.luxuryGold : Colors.white70,
                                        size: 22,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item.label,
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          color: isSelected ? QuantisColors.luxuryGold : Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const Divider(color: Colors.white24, height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Tooltip(
                              message: 'Modifier mon mot de passe',
                              child: IconButton(
                                icon: const Icon(Icons.vpn_key_outlined, color: Colors.white70, size: 22),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => const ChangePasswordDialog(),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 4),
                            Tooltip(
                              message: 'Déconnexion',
                              child: IconButton(
                                icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 22),
                                onPressed: _logout,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: const BoxDecoration(
                          color: QuantisColors.white,
                          border: Border(bottom: BorderSide(color: QuantisColors.border)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                // Bouton Recherche Universelle / Command Palette
                                InkWell(
                                  onTap: () => CommandPaletteDialog.show(
                                    context,
                                    onNavigate: (i) => setState(() => _currentIndex = i),
                                    onOpenAi: () => showQuantisAiChat(context),
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.search, size: 16, color: Colors.grey),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Recherche universelle & Actions...',
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.grey.shade300),
                                          ),
                                          child: const Text('Ctrl K', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Bouton Assistant Quantis IA
                                InkWell(
                                  onTap: () => showQuantisAiChat(context),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: QuantisColors.royalBlue.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: QuantisColors.luxuryGold.withValues(alpha: 0.6),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.auto_awesome, size: 16, color: QuantisColors.royalBlue),
                                        SizedBox(width: 6),
                                        Text(
                                          'Assistant Quantis IA',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: QuantisColors.royalBlue,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                const SyncIndicator(),
                                const SizedBox(width: 16),
                                PopupMenuButton<String>(
                                  tooltip: 'Compte & Options',
                                  offset: const Offset(0, 42),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: QuantisColors.royalBlue.withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: QuantisColors.royalBlue.withValues(alpha: 0.2)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircleAvatar(
                                          radius: 13,
                                          backgroundColor: QuantisColors.royalBlue,
                                          child: Text(
                                            (ApiClient.userName?.isNotEmpty == true ? ApiClient.userName![0] : 'U').toUpperCase(),
                                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              ApiClient.userName ?? 'Admin',
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: QuantisColors.textPrimary),
                                            ),
                                            Text(
                                              '${ApiClient.userRole ?? "ADMIN"} • ${ApiClient.entrepriseNom}',
                                              style: const TextStyle(fontSize: 10, color: QuantisColors.textMuted),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.arrow_drop_down, size: 20, color: QuantisColors.textMuted),
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
                                      _logout();
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    PopupMenuItem(
                                      value: 'header',
                                      enabled: false,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(ApiClient.userName ?? 'Utilisateur', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                                          Text(ApiClient.userEmail ?? '', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: QuantisColors.royalBlue.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(ApiClient.entrepriseNom, style: const TextStyle(fontSize: 10, color: QuantisColors.royalBlue, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuDivider(),
                                    const PopupMenuItem(
                                      value: 'password',
                                      child: Row(
                                        children: [
                                          Icon(Icons.lock_reset_rounded, size: 18, color: QuantisColors.royalBlue),
                                          SizedBox(width: 10),
                                          Text('Modifier le mot de passe'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuDivider(),
                                    const PopupMenuItem(
                                      value: 'logout',
                                      child: Row(
                                        children: [
                                          Icon(Icons.logout_rounded, size: 18, color: QuantisColors.error),
                                          SizedBox(width: 10),
                                          Text('Déconnexion', style: TextStyle(color: QuantisColors.error, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Expanded(child: _buildPage(_currentIndex, isWide)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      content = CallbackShortcuts(
        bindings: shortcuts,
        child: Scaffold(
          body: _buildPage(_currentIndex, isWide),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (i) => setState(() => _currentIndex = i),
            destinations: items.map((item) => NavigationDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.selectedIcon),
              label: item.label,
            )).toList(),
          ),
        ),
      );
    }

    return content;
  }
}

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Widget page;
  const _NavItem(this.icon, this.selectedIcon, this.label, this.page);
}
