import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/quantis_theme.dart';
import '../../../core/utils/permission_helper.dart';
import '../../stock/data/stock_service.dart';
import '../data/user_service.dart';
import 'user_permissions_dialog.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _userService = UserService();
  final _stockService = StockApiService();

  List<UserModel> _users = [];
  List<DepotModel> _depots = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final usersList = await _userService.getUsers();
      final depotsList = await _stockService.getDepots();
      setState(() {
        _users = usersList;
        _depots = depotsList;
      });
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 403) {
        setState(() { _error = 'Accès refusé : vous ne disposez pas des permissions requises pour gérer les utilisateurs.'; });
      } else {
        setState(() { _error = 'Impossible de charger les utilisateurs : $e'; });
      }
    } finally {
      setState(() { _loading = false; });
    }
  }

  void _showUserForm([UserModel? user]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _UserFormDialog(
        user: user,
        depots: _depots,
        onSave: () {
          _loadData();
        },
      ),
    );
  }

  Future<void> _toggleUserStatus(UserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(user.actif ? 'Désactiver l\'utilisateur ?' : 'Activer l\'utilisateur ?'),
        content: Text('Voulez-vous vraiment changer le statut de ${user.prenom} ${user.nom} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: user.actif ? QuantisColors.error : QuantisColors.success,
              foregroundColor: Colors.white,
            ),
            child: Text(user.actif ? 'Désactiver' : 'Activer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() { _loading = true; });
      try {
        if (user.actif) {
          await _userService.deleteUser(user.id);
        } else {
          // Si on l'active, on appelle update avec actif = true
          final updated = UserModel(
            id: user.id,
            nom: user.nom,
            prenom: user.prenom,
            email: user.email,
            role: user.role,
            depotId: user.depotId,
            actif: true,
          );
          await _userService.updateUser(user.id, updated);
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Statut mis à jour'), backgroundColor: QuantisColors.success),
        );
        _loadData();
      } catch (e) {
        setState(() { _error = 'Erreur : $e'; });
      } finally {
        setState(() { _loading = false; });
      }
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'ADMIN':
        return Colors.purple.shade700;
      case 'GERANT':
        return QuantisColors.royalBlue;
      case 'MAGASINIER':
        return Colors.orange.shade700;
      case 'CAISSIER':
        return Colors.teal.shade700;
      case 'COMPTABLE':
        return Colors.blueGrey.shade700;
      default:
        return QuantisColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 650;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isMobile ? 'Utilisateurs' : 'Gestion des Utilisateurs',
          style: const TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Actualiser',
          ),
          if (PermissionHelper.hasPermission('CRUD_UTILISATEURS'))
            isMobile
                ? IconButton(
                    icon: const Icon(Icons.person_add_alt_1, color: QuantisColors.royalBlue),
                    tooltip: 'Nouvel Utilisateur',
                    onPressed: () => _showUserForm(),
                  )
                : Padding(
                    padding: const EdgeInsets.only(right: 16.0, left: 8.0),
                    child: ElevatedButton.icon(
                      onPressed: () => _showUserForm(),
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text('Nouvel Utilisateur'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: QuantisColors.royalBlue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
        ],
      ),
      body: _loading && _users.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: const TextStyle(color: QuantisColors.error)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadData, child: const Text('Réessayer')),
                    ],
                  ),
                )
              : _users.isEmpty
                  ? const Center(child: Text('Aucun utilisateur enregistré.'))
                  : Padding(
                      padding: EdgeInsets.all(isMobile ? 10.0 : 24.0),
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: QuantisColors.border),
                        ),
                        child: ListView.separated(
                          itemCount: _users.length,
                          separatorBuilder: (context, index) => const Divider(height: 1, color: QuantisColors.border),
                          itemBuilder: (context, index) {
                            final user = _users[index];
                            final roleBadge = Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getRoleColor(user.role).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                user.role,
                                style: TextStyle(
                                  color: _getRoleColor(user.role),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );

                            final actifBadge = Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: user.actif
                                    ? QuantisColors.success.withValues(alpha: 0.15)
                                    : QuantisColors.error.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                user.actif ? 'Actif' : 'Inactif',
                                style: TextStyle(
                                  color: user.actif ? QuantisColors.success : QuantisColors.error,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );

                            return ListTile(
                              contentPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24, vertical: 6),
                              leading: CircleAvatar(
                                backgroundColor: _getRoleColor(user.role).withValues(alpha: 0.1),
                                foregroundColor: _getRoleColor(user.role),
                                child: Text(user.prenom.isNotEmpty ? user.prenom[0].toUpperCase() : 'U'),
                              ),
                              title: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    '${user.prenom} ${user.nom}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  roleBadge,
                                  actifBadge,
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  'Email : ${user.email}  |  Dépôt : ${user.depotName ?? "Tous les dépôts"}',
                                  style: const TextStyle(color: QuantisColors.textMuted, fontSize: 12),
                                ),
                              ),
                              trailing: PermissionHelper.hasPermission('CRUD_UTILISATEURS')
                                  ? (isMobile
                                      ? PopupMenuButton<String>(
                                          icon: const Icon(Icons.more_vert),
                                          onSelected: (action) {
                                            if (action == 'permissions') {
                                              showDialog(
                                                context: context,
                                                builder: (ctx) => UserPermissionsDialog(
                                                  userId: user.id,
                                                  userName: '${user.prenom} ${user.nom}',
                                                  userRole: user.role,
                                                ),
                                              );
                                            } else if (action == 'edit') {
                                              _showUserForm(user);
                                            } else if (action == 'toggle') {
                                              _toggleUserStatus(user);
                                            }
                                          },
                                          itemBuilder: (ctx) => [
                                            const PopupMenuItem(
                                              value: 'permissions',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.security, size: 18, color: QuantisColors.luxuryGold),
                                                  SizedBox(width: 8),
                                                  Text('Gérer les droits'),
                                                ],
                                              ),
                                            ),
                                            const PopupMenuItem(
                                              value: 'edit',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                                                  SizedBox(width: 8),
                                                  Text('Modifier'),
                                                ],
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: 'toggle',
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    user.actif ? Icons.block_outlined : Icons.check_circle_outline,
                                                    size: 18,
                                                    color: user.actif ? Colors.red : Colors.green,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text(user.actif ? 'Désactiver' : 'Activer'),
                                                ],
                                              ),
                                            ),
                                          ],
                                        )
                                      : Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.security, color: QuantisColors.luxuryGold),
                                              onPressed: () {
                                                showDialog(
                                                  context: context,
                                                  builder: (ctx) => UserPermissionsDialog(
                                                    userId: user.id,
                                                    userName: '${user.prenom} ${user.nom}',
                                                    userRole: user.role,
                                                  ),
                                                );
                                              },
                                              tooltip: 'Gérer les droits',
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                                              onPressed: () => _showUserForm(user),
                                              tooltip: 'Modifier',
                                            ),
                                            IconButton(
                                              icon: Icon(
                                                user.actif ? Icons.block_outlined : Icons.check_circle_outline,
                                                color: user.actif ? Colors.red : Colors.green,
                                              ),
                                              onPressed: () => _toggleUserStatus(user),
                                              tooltip: user.actif ? 'Désactiver' : 'Activer',
                                            ),
                                          ],
                                        ))
                                  : null,
                            );
                          },
                        ),
                      ),
                    ),
    );
  }
}

class _UserFormDialog extends StatefulWidget {
  final UserModel? user;
  final List<DepotModel> depots;
  final VoidCallback onSave;

  const _UserFormDialog({
    this.user,
    required this.depots,
    required this.onSave,
  });

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _userService = UserService();

  final _nomCtrl = TextEditingController();
  final _prenomCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  String _selectedRole = 'GERANT';
  int? _selectedDepotId;
  bool _actif = true;

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.user != null) {
      _nomCtrl.text = widget.user!.nom;
      _prenomCtrl.text = widget.user!.prenom;
      _emailCtrl.text = widget.user!.email;
      _selectedRole = widget.user!.role;
      _selectedDepotId = widget.user!.depotId;
      _actif = widget.user!.actif;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      if (widget.user == null) {
        // Création
        await _userService.createUser({
          'nom': _nomCtrl.text.trim(),
          'prenom': _prenomCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'motDePasse': _passwordCtrl.text,
          'role': _selectedRole,
          'depotId': _selectedDepotId,
        });
      } else {
        // Modification
        final updated = UserModel(
          id: widget.user!.id,
          nom: _nomCtrl.text.trim(),
          prenom: _prenomCtrl.text.trim(),
          email: widget.user!.email,
          role: _selectedRole,
          depotId: _selectedDepotId,
          actif: _actif,
        );
        await _userService.updateUser(widget.user!.id, updated);
      }

      widget.onSave();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() { _error = 'Erreur lors de l\'enregistrement : $e'; });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.user != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEdit ? 'Modifier l\'utilisateur' : 'Créer un utilisateur',
                      style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: QuantisColors.royalBlue,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: QuantisColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: QuantisColors.error, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error!, style: const TextStyle(color: QuantisColors.error, fontSize: 13))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _prenomCtrl,
                        decoration: const InputDecoration(labelText: 'Prénom'),
                        validator: (v) => v == null || v.isEmpty ? 'Champs requis' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _nomCtrl,
                        decoration: const InputDecoration(labelText: 'Nom'),
                        validator: (v) => v == null || v.isEmpty ? 'Champs requis' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  enabled: !isEdit,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => v == null || v.isEmpty ? 'Champs requis' : null,
                ),
                const SizedBox(height: 16),

                if (!isEdit) ...[
                  TextFormField(
                    controller: _passwordCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Mot de passe initial',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    obscureText: true,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Champs requis';
                      if (v.length < 8) return 'Minimum 8 caractères';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Rôle',
                    prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'ADMIN', child: Text('Administrateur')),
                    DropdownMenuItem(value: 'GERANT', child: Text('Gérant')),
                    DropdownMenuItem(value: 'MAGASINIER', child: Text('Magasinier')),
                    DropdownMenuItem(value: 'CAISSIER', child: Text('Caissier')),
                    DropdownMenuItem(value: 'COMPTABLE', child: Text('Comptable')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedRole = val);
                  },
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<int?>(
                  value: _selectedDepotId,
                  decoration: const InputDecoration(
                    labelText: 'Dépôt rattaché',
                    prefixIcon: Icon(Icons.storefront_outlined),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Tous les dépôts / Aucun')),
                    ...widget.depots.map((d) => DropdownMenuItem<int?>(
                          value: d.id,
                          child: Text(d.nom),
                        )),
                  ],
                  onChanged: (val) {
                    setState(() => _selectedDepotId = val);
                  },
                ),
                const SizedBox(height: 16),

                if (isEdit) ...[
                  SwitchListTile(
                    title: const Text('Compte actif'),
                    value: _actif,
                    activeColor: QuantisColors.success,
                    onChanged: (val) => setState(() => _actif = val),
                  ),
                  const SizedBox(height: 16),
                ],

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _loading ? null : () => Navigator.of(context).pop(),
                      child: const Text('Annuler'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: QuantisColors.royalBlue,
                        foregroundColor: Colors.white,
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Enregistrer'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
