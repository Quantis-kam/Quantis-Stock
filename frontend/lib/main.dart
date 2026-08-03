import 'package:flutter/material.dart';
import 'core/theme/quantis_theme.dart';
import 'features/tiers/presentation/clients_screen.dart';
import 'features/tiers/presentation/fournisseurs_screen.dart';
import 'features/achats/presentation/achats_screen.dart';
import 'features/documents/presentation/documents_screen.dart';
import 'features/comptabilite/presentation/comptabilite_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const QuantisStockApp());
}

class QuantisStockApp extends StatelessWidget {
  const QuantisStockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quantis Stock',
      debugShowCheckedModeBanner: false,
      theme: QuantisTheme.lightTheme,
      darkTheme: QuantisTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: const MainShell(),
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
        return const _PlaceholderPage(title: 'Dashboard', icon: Icons.dashboard);
      case 1:
        return const _PlaceholderPage(title: 'Produits', icon: Icons.inventory_2);
      case 2:
        return const _PlaceholderPage(title: 'Mouvements Stock', icon: Icons.swap_horiz);
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
        return const _PlaceholderPage(title: 'Dashboard', icon: Icons.dashboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;

    if (isWide) {
      // Desktop: NavigationRail + contenu
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
              destinations: _items.map((item) => NavigationRailDestination(
                icon: Icon(item.icon, color: Colors.white70),
                selectedIcon: Icon(item.selectedIcon, color: QuantisColors.luxuryGold),
                label: Text(item.label),
              )).toList(),
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: _buildPage(_currentIndex)),
          ],
        ),
      );
    } else {
      // Mobile: BottomNavigationBar
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

/// Page placeholder pour les écrans non encore implémentés.
class _PlaceholderPage extends StatelessWidget {
  final String title;
  final IconData icon;

  const _PlaceholderPage({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: QuantisColors.royalBlue.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: QuantisColors.royalBlue,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Disponible prochainement',
              style: TextStyle(color: QuantisColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
