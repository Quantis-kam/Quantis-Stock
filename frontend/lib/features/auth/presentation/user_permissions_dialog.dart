import 'package:flutter/material.dart';
import '../../../core/theme/quantis_theme.dart';
import '../../stock/data/stock_service.dart';
import '../data/user_service.dart';

/// Dialog de gestion des permissions granulaires d'un utilisateur.
class UserPermissionsDialog extends StatefulWidget {
  final int userId;
  final String userName;
  final String userRole;

  const UserPermissionsDialog({
    super.key,
    required this.userId,
    required this.userName,
    required this.userRole,
  });

  @override
  State<UserPermissionsDialog> createState() => _UserPermissionsDialogState();
}

class _UserPermissionsDialogState extends State<UserPermissionsDialog> {
  final _userService = UserService();
  final _stockService = StockApiService();

  bool _loading = true;
  bool _saving = false;
  String? _error;

  // État
  bool _permissionsCustom = false;
  Set<String> _permissionsRole = {};
  Set<String> _selectedPermissions = {};
  List<Map<String, dynamic>> _permissionGroups = [];
  List<DepotModel> _allDepots = [];
  Set<int> _selectedDepots = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _userService.getUserPermissions(widget.userId),
        _userService.getPermissionsCatalog(),
        _stockService.getDepots(),
      ]);

      final permData = results[0] as Map<String, dynamic>;
      final catalog = results[1] as List<dynamic>;
      final depots = results[2] as List<DepotModel>;

      setState(() {
        _permissionsCustom = permData['permissionsCustom'] as bool? ?? false;
        _permissionsRole = Set<String>.from(permData['permissionsRole'] as List? ?? []);

        // Si custom → charger les permissions personnalisées, sinon pré-remplir avec celles du rôle
        final permsToLoad = _permissionsCustom
            ? (permData['permissionsPersonnalisees'] as List? ?? [])
            : (permData['permissionsRole'] as List? ?? []);
        _selectedPermissions = Set<String>.from(permsToLoad);

        _permissionGroups = (catalog).map((g) => g as Map<String, dynamic>).toList();
        _allDepots = depots;

        final depotsAuth = permData['depotsAutorises'] as List? ?? [];
        _selectedDepots = depotsAuth.map((d) => (d as Map<String, dynamic>)['id'] as int).toSet();

        _loading = false;
      });
    } catch (e) {
      setState(() { _error = 'Erreur: $e'; _loading = false; });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _userService.updateUserPermissions(widget.userId, {
        'permissionsCustom': _permissionsCustom,
        'permissions': _selectedPermissions.toList(),
        'depotsAutorises': _selectedDepots.toList(),
      });
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permissions mises à jour avec succès !'),
            backgroundColor: QuantisColors.success,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: QuantisColors.error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _togglePermission(String code, bool? value) {
    setState(() {
      if (value == true) {
        _selectedPermissions.add(code);
      } else {
        _selectedPermissions.remove(code);
      }
    });
  }

  void _selectAllInGroup(List<dynamic> perms) {
    setState(() {
      for (var p in perms) {
        _selectedPermissions.add(p['code'] as String);
      }
    });
  }

  void _deselectAllInGroup(List<dynamic> perms) {
    setState(() {
      for (var p in perms) {
        _selectedPermissions.remove(p['code'] as String);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 750),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [QuantisColors.royalBlue, Color(0xFF1A3A6E)],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.security, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Gestion des Droits',
                            style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white, fontWeight: FontWeight.bold)),
                        Text('${widget.userName} — ${widget.userRole}',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white70)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!, style: const TextStyle(color: QuantisColors.error)))
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Switch Custom
                              Card(
                                color: _permissionsCustom
                                    ? QuantisColors.luxuryGold.withValues(alpha: 0.08)
                                    : null,
                                child: SwitchListTile(
                                  value: _permissionsCustom,
                                  onChanged: (v) {
                                    setState(() {
                                      _permissionsCustom = v;
                                      if (!v) {
                                        // Revenir aux permissions du rôle
                                        _selectedPermissions = Set.from(_permissionsRole);
                                      }
                                    });
                                  },
                                  title: const Text('Permissions personnalisées',
                                      style: TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text(
                                    _permissionsCustom
                                        ? 'Les permissions ci-dessous remplacent celles du rôle'
                                        : 'Utilise les permissions par défaut du rôle ${widget.userRole}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  activeColor: QuantisColors.luxuryGold,
                                  secondary: Icon(
                                    _permissionsCustom ? Icons.tune : Icons.group,
                                    color: _permissionsCustom
                                        ? QuantisColors.luxuryGold
                                        : QuantisColors.textMuted,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Permission Groups
                              ..._permissionGroups.map((group) => _buildPermissionGroup(group)),

                              const Divider(height: 32),

                              // Dépôts autorisés
                              _buildDepotsSection(),
                            ],
                          ),
                        ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_selectedPermissions.length} permissions sélectionnées',
                    style: theme.textTheme.bodySmall?.copyWith(color: QuantisColors.textMuted),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Annuler'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save, size: 18),
                        label: const Text('Enregistrer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: QuantisColors.royalBlue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionGroup(Map<String, dynamic> group) {
    final label = group['label'] as String;
    final icon = group['icon'] as String;
    final perms = group['permissions'] as List<dynamic>;
    final allSelected = perms.every((p) => _selectedPermissions.contains(p['code']));
    final someSelected = perms.any((p) => _selectedPermissions.contains(p['code']));

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: Text(icon, style: const TextStyle(fontSize: 20)),
        title: Row(
          children: [
            Expanded(
              child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: allSelected
                    ? QuantisColors.success.withValues(alpha: 0.1)
                    : someSelected
                        ? QuantisColors.luxuryGold.withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${perms.where((p) => _selectedPermissions.contains(p['code'])).length}/${perms.length}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: allSelected ? QuantisColors.success : QuantisColors.textMuted,
                ),
              ),
            ),
          ],
        ),
        children: [
          // Tout sélectionner / désélectionner
          if (_permissionsCustom)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () => _selectAllInGroup(perms),
                    icon: const Icon(Icons.select_all, size: 16),
                    label: const Text('Tout', style: TextStyle(fontSize: 11)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _deselectAllInGroup(perms),
                    icon: const Icon(Icons.deselect, size: 16),
                    label: const Text('Aucun', style: TextStyle(fontSize: 11)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                    ),
                  ),
                ],
              ),
            ),
          ...perms.map((p) {
            final code = p['code'] as String;
            final permLabel = p['label'] as String;
            final isFromRole = _permissionsRole.contains(code);
            return CheckboxListTile(
              value: _selectedPermissions.contains(code),
              onChanged: _permissionsCustom ? (v) => _togglePermission(code, v) : null,
              title: Text(permLabel, style: const TextStyle(fontSize: 13)),
              subtitle: !_permissionsCustom && isFromRole
                  ? const Text('Via le rôle', style: TextStyle(fontSize: 10, color: QuantisColors.textMuted))
                  : null,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: QuantisColors.royalBlue,
            );
          }),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildDepotsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.warehouse, color: QuantisColors.royalBlue, size: 20),
            const SizedBox(width: 8),
            const Text('Dépôts autorisés',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _selectedDepots.isEmpty
                    ? QuantisColors.success.withValues(alpha: 0.1)
                    : QuantisColors.luxuryGold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _selectedDepots.isEmpty ? 'Tous' : '${_selectedDepots.length} dépôt(s)',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Aucun dépôt sélectionné = accès à tous les dépôts',
          style: TextStyle(fontSize: 11, color: QuantisColors.textMuted),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: _allDepots.map((depot) {
              return CheckboxListTile(
                value: _selectedDepots.contains(depot.id),
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _selectedDepots.add(depot.id);
                    } else {
                      _selectedDepots.remove(depot.id);
                    }
                  });
                },
                title: Text(depot.nom, style: const TextStyle(fontSize: 13)),
                subtitle: depot.adresse != null
                    ? Text(depot.adresse!, style: const TextStyle(fontSize: 10))
                    : null,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: QuantisColors.royalBlue,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
