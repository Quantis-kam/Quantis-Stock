import 'package:flutter/material.dart';
import 'core/theme/quantis_theme.dart';
import 'core/network/api_client.dart';
import 'core/widgets/sync_indicator.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/tiers/presentation/clients_screen.dart';
import 'features/tiers/presentation/fournisseurs_screen.dart';
import 'features/achats/presentation/achats_screen.dart';
import 'features/documents/presentation/documents_screen.dart';
import 'features/comptabilite/presentation/comptabilite_screen.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';
import 'features/produits/presentation/produits_screen.dart';
import 'features/stock/presentation/stock_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const QuantisStockApp());
}

class QuantisStockApp extends StatefulWidget {
  const QuantisStockApp({super.key});

  @override
  State<QuantisStockApp> createState() => _QuantisStockAppState();
}

class _QuantisStockAppState extends State<QuantisStockApp> {
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    // Auto-logout quand le refresh token expire
    ApiClient.onSessionExpired = () {
      if (mounted) setState(() => _isLoggedIn = false);
    };
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quantis Stock',
      debugShowCheckedModeBanner: false,
      theme: QuantisTheme.lightTheme,
      darkTheme: QuantisTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: _isLoggedIn
          ? const MainShell()
          : LoginScreen(onLoginSuccess: () => setState(() => _isLoggedIn = true)),
    );
  }
}

/// Shell principal avec navigation latérale (desktop) ou bottom bar (mobile).
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<_NavItem> _items = [
    _NavItem(Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
    _NavItem(Icons.inventory_2_outlined, Icons.inventory_2, 'Produits'),
    _NavItem(Icons.swap_horiz_outlined, Icons.swap_horiz, 'Stock'),
    _NavItem(Icons.people_outline, Icons.people, 'Clients'),
    _NavItem(Icons.business_outlined, Icons.business, 'Fournisseurs'),
    _NavItem(Icons.shopping_cart_outlined, Icons.shopping_cart, 'Achats'),
    _NavItem(Icons.receipt_long_outlined, Icons.receipt_long, 'Documents'),
    _NavItem(Icons.account_balance_outlined, Icons.account_balance, 'Compta'),
  ];

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return const DashboardScreen();
      case 1:
        return const ProduitsScreen();
      case 2:
        return const StockScreen();
      case 3:
        return const ClientsScreen();
      case 4:
        return const FournisseursScreen();
      case 5:
        return const AchatsScreen();
      case 6:
        return const DocumentsScreen();
      case 7:
        return const ComptabiliteScreen();
      default:
        return const DashboardScreen();
    }
  }

  void _logout() {
    ApiClient.clearToken();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LoginScreen(
        onLoginSuccess: () {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MainShell()),
            (_) => false,
          );
        },
      )),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _currentIndex,
              onDestinationSelected: (i) => setState(() => _currentIndex = i),
              labelType: NavigationRailLabelType.all,
              backgroundColor: QuantisColors.royalBlue,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text('Q',
                      style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: QuantisColors.luxuryGold,
                      ),
                    ),
                  ),
                ),
              ),
              trailing: Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white70),
                      onPressed: _logout,
                      tooltip: 'Déconnexion',
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              destinations: _items.map((item) => NavigationRailDestination(
                icon: Icon(item.icon, color: Colors.white70),
                selectedIcon: Icon(item.selectedIcon, color: QuantisColors.luxuryGold),
                label: Text(item.label),
              )).toList(),
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(
              child: Column(
                children: [
                  // Status bar avec sync indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: const BoxDecoration(
                      color: QuantisColors.white,
                      border: Border(bottom: BorderSide(color: QuantisColors.border)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [SyncIndicator()],
                    ),
                  ),
                  Expanded(child: _buildPage(_currentIndex)),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      return Scaffold(
        body: _buildPage(_currentIndex),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (i) => setState(() => _currentIndex = i),
          destinations: _items.map((item) => NavigationDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.selectedIcon),
            label: item.label,
          )).toList(),
        ),
      );
    }
  }
}

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const _NavItem(this.icon, this.selectedIcon, this.label);
}
