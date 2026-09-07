import 'package:flutter/material.dart';
import '../../../core/theme/quantis_theme.dart';
import '../../../core/network/api_client.dart';
import '../../auth/presentation/audit_logs_screen.dart';
import '../../auth/presentation/change_password_dialog.dart';
import 'super_admin_screen.dart';

/// Portail exclusif et autonome du Super-Administrateur Plateforme Quantis SaaS.
/// Totalement séparé de l'espace métier des entreprises clientes (pas de caisse, pas de stock magasin).
class PlatformAdminPortal extends StatefulWidget {
  const PlatformAdminPortal({super.key});

  @override
  State<PlatformAdminPortal> createState() => _PlatformAdminPortalState();
}

class _PlatformAdminPortalState extends State<PlatformAdminPortal> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;

  final List<_AdminSection> _sections = [
    const _AdminSection(
      icon: Icons.domain_rounded,
      title: 'Gestion des Entreprises',
      subtitle: 'Parc multi-tenants, licences & souscriptions',
      body: SuperAdminScreen(),
    ),
    const _AdminSection(
      icon: Icons.history_edu_rounded,
      title: 'Audit & Sécurité Globale',
      subtitle: 'Traçabilité des opérations de la plateforme',
      body: AuditLogsScreen(embedded: true),
    ),
  ];

  Future<void> _logout() async {
    try {
      await ApiClient.instance.post('/auth/logout');
    } catch (_) {}
    ApiClient.clearToken();
  }

  Widget _buildSidebar({required bool isDrawer}) {
    return Container(
      width: isDrawer ? null : 260,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A), // Slate 900
        border: Border(right: BorderSide(color: Color(0xFF1E293B))),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Logo
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: QuantisColors.luxuryGold, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 6,
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
                        const Text(
                          'Quantis-Stock',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            fontFamily: 'SpaceGrotesk',
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: QuantisColors.luxuryGold.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: QuantisColors.luxuryGold, width: 0.8),
                          ),
                          child: const Text(
                            'SUPER ADMIN',
                            style: TextStyle(
                              color: QuantisColors.luxuryGold,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isDrawer)
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF1E293B), height: 1),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Text(
                'PORTAIL CENTRAL',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            // Navigation items
            Expanded(
              child: ListView.builder(
                itemCount: _sections.length,
                itemBuilder: (context, idx) {
                  final s = _sections[idx];
                  final isSelected = _selectedIndex == idx;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? QuantisColors.royalBlue : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      dense: true,
                      leading: Icon(
                        s.icon,
                        color: isSelected ? QuantisColors.luxuryGold : const Color(0xFF94A3B8),
                        size: 20,
                      ),
                      title: Text(
                        s.title,
                        style: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      onTap: () {
                        setState(() => _selectedIndex = idx);
                        if (isDrawer) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                  );
                },
              ),
            ),
            // Profil & Déconnexion
            const Divider(color: Color(0xFF1E293B), height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0xFF1E293B),
                    child: Icon(Icons.shield, color: QuantisColors.luxuryGold, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Super-Admin',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Plateforme SaaS',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.vpn_key_outlined, color: Colors.white70, size: 18),
                    tooltip: 'Modifier mot de passe',
                    onPressed: () {
                      if (isDrawer) Navigator.of(context).pop();
                      showDialog(
                        context: context,
                        builder: (_) => const ChangePasswordDialog(),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 20),
                    tooltip: 'Déconnexion',
                    onPressed: _logout,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;

    if (isMobile) {
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          leading: IconButton(
            icon: const Icon(Icons.menu_rounded, color: Color(0xFF0F172A)),
            tooltip: 'Menu',
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _sections[_selectedIndex].title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                _sections[_selectedIndex].subtitle,
                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 20),
              tooltip: 'Déconnexion',
              onPressed: _logout,
            ),
          ],
        ),
        drawer: Drawer(
          backgroundColor: const Color(0xFF0F172A),
          child: _buildSidebar(isDrawer: true),
        ),
        body: _sections[_selectedIndex].body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.domain_outlined),
              selectedIcon: Icon(Icons.domain_rounded, color: QuantisColors.royalBlue),
              label: 'Entreprises',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_edu_outlined),
              selectedIcon: Icon(Icons.history_edu_rounded, color: QuantisColors.royalBlue),
              label: 'Audit & Logs',
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          // Sidebar dédié Super-Admin (Desktop)
          _buildSidebar(isDrawer: false),

          // Zone de contenu principale
          Expanded(
            child: Column(
              children: [
                // Topbar minimaliste
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _sections[_selectedIndex].title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            _sections[_selectedIndex].subtitle,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.lock_outline, size: 14, color: Color(0xFF475569)),
                            SizedBox(width: 6),
                            Text(
                              'Espace Réservé Super-Admin',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Contenu
                Expanded(child: _sections[_selectedIndex].body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminSection {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget body;

  const _AdminSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.body,
  });
}
