import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/quantis_theme.dart';
import 'core/network/api_client.dart';
import 'core/utils/permission_helper.dart';
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
      if (PermissionHelper.canViewDashboard)
        _NavItem(Icons.insights_outlined, Icons.insights, 'Tableau de bord', ActionDashboardScreen(onNavigate: _onNavigateToModule)),
      if (PermissionHelper.canAccessAi)
        _NavItem(Icons.auto_awesome_outlined, Icons.auto_awesome, 'Quantis AI', const QuantisAiScreen()),
      if (PermissionHelper.canAccessPos)
        _NavItem(Icons.point_of_sale_outlined, Icons.point_of_sale, 'Caisse POS', const PosScreen()),
      if (PermissionHelper.canAccessDocuments)
        _NavItem(Icons.receipt_long_outlined, Icons.receipt_long, 'Factures & Devis', const DocumentsScreen()),
      if (PermissionHelper.canAccessProduits)
        _NavItem(Icons.category_outlined, Icons.category, 'Articles & Produits', const ProduitsScreen()),
      if (PermissionHelper.canAccessClients)
        _NavItem(Icons.people_alt_outlined, Icons.people, 'Clients', const ClientsScreen()),
      if (PermissionHelper.canAccessStock)
        _NavItem(Icons.inventory_2_outlined, Icons.inventory_2, 'Stock', const StockScreen()),
      if (PermissionHelper.canAccessArretStock)
        _NavItem(Icons.camera_alt_outlined, Icons.camera_alt, 'Arrêts Stock', const ArretStockScreen()),
      if (PermissionHelper.canAccessAchats)
        _NavItem(Icons.shopping_cart_outlined, Icons.shopping_cart, 'Achats', const AchatsScreen()),
      if (PermissionHelper.canAccessFournisseurs)
        _NavItem(Icons.business_outlined, Icons.business, 'Fournisseurs', const FournisseursScreen()),
      if (PermissionHelper.canAccessComptabilite)
        _NavItem(Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, 'Caisse & Compta', const ComptabiliteScreen()),
      if (PermissionHelper.canAccessExports)
        _NavItem(Icons.table_view_outlined, Icons.table_view, 'Exports Compta', const ExportsScreen()),
      if (PermissionHelper.canAccessEntreprise)
        _NavItem(Icons.storefront_outlined, Icons.storefront, 'Entreprise', const EntrepriseScreen()),
      if (PermissionHelper.canAccessUsers)
        _NavItem(Icons.manage_accounts_outlined, Icons.manage_accounts, 'Utilisateurs', const UsersScreen()),
      if (PermissionHelper.canAccessAudit)
        _NavItem(Icons.history_edu_outlined, Icons.history_edu, 'Logs Audit', const AuditLogsScreen()),
    ];
  }

  List<_NavItem> get _mobileItems {
    final list = <_NavItem>[];
    if (PermissionHelper.canViewDashboard) {
      list.add(_NavItem(Icons.insights_outlined, Icons.insights, 'Rapports', ActionDashboardScreen(onNavigate: _onNavigateToModule)));
    }
    if (PermissionHelper.canAccessPos) {
      list.add(_NavItem(Icons.point_of_sale_outlined, Icons.point_of_sale, 'POS', const PosScreen()));
    }
    if (PermissionHelper.canAccessDocuments) {
      list.add(_NavItem(Icons.receipt_long_outlined, Icons.receipt_long, 'Factures', const DocumentsScreen()));
    }
    if (PermissionHelper.canAccessStock) {
      list.add(_NavItem(Icons.inventory_2_outlined, Icons.inventory_2, 'Stock', const StockScreen()));
    }
    if (PermissionHelper.canAccessComptabilite) {
      list.add(_NavItem(Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, 'Caisse', const ComptabiliteScreen()));
    }
    if (PermissionHelper.canAccessExports) {
      list.add(_NavItem(Icons.table_view_outlined, Icons.table_view, 'Exports', const ExportsScreen()));
    }
    // Menu Plus pour les fonctionnalités autorisées restantes et paramètres de compte
    list.add(_NavItem(Icons.more_horiz_outlined, Icons.more_horiz, 'Plus', _buildPlusMenu()));
    return list;
  }

  void _onNavigateToModule(int targetIndex) {
    final isWide = MediaQuery.of(context).size.width >= 800;
    final items = isWide ? _desktopItems : _mobileItems;
    if (targetIndex >= 0 && targetIndex < items.length) {
      setState(() => _currentIndex = targetIndex);
    }
  }

  Widget _buildPlusMenu() {
    return Scaffold(
      appBar: AppBar(title: const Text('Menu Plus & Paramètres')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (PermissionHelper.canAccessAi) ...[
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
          ],
          // Accès direct & mis en avant : Caisse & Exports
          if (PermissionHelper.canAccessComptabilite || PermissionHelper.canAccessExports) ...[
            Row(
              children: [
                if (PermissionHelper.canAccessComptabilite)
                  Expanded(
                    child: InkWell(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ComptabiliteScreen())),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          color: QuantisColors.royalBlue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: QuantisColors.royalBlue.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: QuantisColors.royalBlue,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Caisse',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: QuantisColors.royalBlue),
                                  ),
                                  Text(
                                    'Sessions & Compta',
                                    style: TextStyle(fontSize: 10, color: QuantisColors.textMuted),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (PermissionHelper.canAccessComptabilite && PermissionHelper.canAccessExports)
                  const SizedBox(width: 10),
                if (PermissionHelper.canAccessExports)
                  Expanded(
                    child: InkWell(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExportsScreen())),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.teal.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.teal,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.table_view_rounded, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Exports',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.teal),
                                  ),
                                  Text(
                                    'CSV Excel & Fisc',
                                    style: TextStyle(fontSize: 10, color: QuantisColors.textMuted),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
          ],
          if (PermissionHelper.canAccessProduits) ...[
            ListTile(
              leading: const Icon(Icons.category, color: QuantisColors.royalBlue),
              title: const Text('Catalogue Articles & Produits'),
              subtitle: const Text('Créer des articles, prix, marges, codes-barres et catégories'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProduitsScreen())),
            ),
            const Divider(),
          ],
          if (PermissionHelper.canAccessClients) ...[
            ListTile(
              leading: const Icon(Icons.people, color: QuantisColors.royalBlue),
              title: const Text('Clients & Débiteurs'),
              subtitle: const Text('Gestion de la base clients et créances'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientsScreen())),
            ),
            const Divider(),
          ],
          if (PermissionHelper.canAccessDebiteurs) ...[
            ListTile(
              leading: const Icon(Icons.account_balance, color: Colors.amber),
              title: const Text('Vue Débiteurs & Créances'),
              subtitle: const Text('Gestion dédiée des impayés et relances'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DebiteursScreen())),
            ),
            const Divider(),
          ],
          if (PermissionHelper.canAccessArretStock) ...[
            ListTile(
              leading: const Icon(Icons.camera_alt, color: QuantisColors.royalBlue),
              title: const Text('Arrêts de Stock (Snapshots)'),
              subtitle: const Text('Gel du stock et audits de valorisation'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ArretStockScreen())),
            ),
            const Divider(),
          ],
          if (PermissionHelper.canAccessFournisseurs) ...[
            ListTile(
              leading: const Icon(Icons.business, color: Colors.teal),
              title: const Text('Fournisseurs'),
              subtitle: const Text('Gestion des partenaires et achats'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FournisseursScreen())),
            ),
            const Divider(),
          ],
          if (PermissionHelper.canAccessAchats) ...[
            ListTile(
              leading: const Icon(Icons.shopping_cart, color: Colors.purple),
              title: const Text('Commandes Achats'),
              subtitle: const Text('Achats fournisseurs et approvisionnement'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AchatsScreen())),
            ),
            const Divider(),
          ],
          if (PermissionHelper.canAccessComptabilite) ...[
            ListTile(
              leading: const Icon(Icons.account_balance_wallet, color: QuantisColors.royalBlue),
              title: const Text('Caisse & Comptabilité'),
              subtitle: const Text('Journal de caisse, sessions, Grand Livre et clôtures'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ComptabiliteScreen())),
            ),
            const Divider(),
          ],
          if (PermissionHelper.canAccessExports) ...[
            ListTile(
              leading: const Icon(Icons.table_view_outlined, color: Colors.teal),
              title: const Text('Exports Comptables & Fiscaux'),
              subtitle: const Text('Exports CSV pour comptabilité, ventes, caisse, créances'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExportsScreen())),
            ),
            const Divider(),
          ],
          if (PermissionHelper.canAccessEntreprise) ...[
            ListTile(
              leading: const Icon(Icons.storefront, color: QuantisColors.royalBlue),
              title: const Text('Profil Entreprise & Logo'),
              subtitle: const Text('Raison sociale, NIF, RCCM, logo, devise et facturation'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EntrepriseScreen())),
            ),
            const Divider(),
          ],
          if (PermissionHelper.canAccessUsers) ...[
            ListTile(
              leading: const Icon(Icons.manage_accounts, color: QuantisColors.luxuryGold),
              title: const Text('Utilisateurs & Permissions'),
              subtitle: const Text('Gestion des comptes et droits granulaires'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UsersScreen())),
            ),
            const Divider(),
          ],
          if (PermissionHelper.canAccessAudit) ...[
            ListTile(
              leading: const Icon(Icons.history_edu, color: Colors.blueGrey),
              title: const Text('Logs d\'Audit & Sécurité'),
              subtitle: const Text('Traçabilité des opérations et actions sensibles'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AuditLogsScreen())),
            ),
            const Divider(),
          ],
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
          const SizedBox(height: 20),
          Center(
            child: Text(
              'Quantis Stock Mobile • Version 1.0.3 (Build 4)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: QuantisColors.textMuted.withValues(alpha: 0.8),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildPage(int index, bool isWide) {
    final items = isWide ? _desktopItems : _mobileItems;
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    if (index < 0 || index >= items.length) {
      return items[0].page;
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

    if (items.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(ApiClient.entrepriseNom),
          actions: [
            IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.security, size: 64, color: QuantisColors.luxuryGold),
                const SizedBox(height: 16),
                const Text(
                  'Espace utilisateur restreint',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Votre compte (${ApiClient.userEmail}) n\'a aucun module attribué pour le moment.\nVeuillez contacter votre administrateur.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Déconnexion'),
                ),
              ],
            ),
          ),
        ),
      );
    }

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
          drawer: _buildMobileDrawer(),
          body: _buildPage(_currentIndex, isWide),
          bottomNavigationBar: items.length >= 2
              ? NavigationBarTheme(
                  data: NavigationBarThemeData(
                    height: 64,
                    labelTextStyle: WidgetStateProperty.resolveWith((states) {
                      final isSelected = states.contains(WidgetState.selected);
                      return TextStyle(
                        fontSize: 10,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? QuantisColors.royalBlue : QuantisColors.textSecondary,
                      );
                    }),
                    iconTheme: WidgetStateProperty.resolveWith((states) {
                      final isSelected = states.contains(WidgetState.selected);
                      return IconThemeData(
                        size: 21,
                        color: isSelected ? QuantisColors.royalBlue : QuantisColors.textSecondary,
                      );
                    }),
                    indicatorColor: QuantisColors.royalBlue.withValues(alpha: 0.12),
                  ),
                  child: NavigationBar(
                    selectedIndex: _currentIndex,
                    onDestinationSelected: (i) => setState(() => _currentIndex = i),
                    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                    destinations: items.map((item) => NavigationDestination(
                      icon: Icon(item.icon),
                      selectedIcon: Icon(item.selectedIcon),
                      label: item.label,
                    )).toList(),
                  ),
                )
              : null,
        ),
      );
    }

    return content;
  }

  Widget _buildMobileDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [QuantisColors.royalBlue, QuantisColors.blueDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: ClipOval(
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Image.asset(
                          'assets/images/quantis_emblem_circle.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Text('Q', style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: QuantisColors.royalBlue,
                              fontSize: 20,
                            )),
                          ),
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
                          ApiClient.entrepriseNom,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${ApiClient.userName ?? "Utilisateur"} • ${ApiClient.userRole ?? "ADMIN"}',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (final item in _desktopItems)
                    ListTile(
                      leading: Icon(item.icon, color: QuantisColors.royalBlue),
                      title: Text(item.label, style: const TextStyle(fontWeight: FontWeight.w500)),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => item.page),
                        );
                      },
                    ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.lock_reset, color: QuantisColors.royalBlue),
                    title: const Text('Modifier mot de passe'),
                    onTap: () {
                      Navigator.pop(context);
                      showDialog(
                        context: context,
                        builder: (_) => const ChangePasswordDialog(),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout, color: QuantisColors.error),
                    title: const Text('Déconnexion', style: TextStyle(color: QuantisColors.error, fontWeight: FontWeight.bold)),
                    onTap: () {
                      Navigator.pop(context);
                      _logout();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Widget page;
  const _NavItem(this.icon, this.selectedIcon, this.label, this.page);
}
