import 'package:flutter/material.dart';
import '../../../core/theme/quantis_theme.dart';
import '../data/tiers_models.dart';
import '../data/tiers_service.dart';
import 'tiers_form_screen.dart';

/// Écran liste des clients avec recherche et CRUD.
class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final TiersService _service = TiersService();
  final TextEditingController _searchController = TextEditingController();

  List<ClientModel> _clients = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    setState(() { _loading = true; _error = null; });
    try {
      _clients = await _service.getClients();
      setState(() => _loading = false);
    } catch (e) {
      setState(() { _loading = false; _error = 'Erreur de chargement: $e'; });
    }
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      _loadClients();
      return;
    }
    setState(() => _loading = true);
    try {
      _clients = await _service.searchClients(query);
      setState(() => _loading = false);
    } catch (e) {
      setState(() { _loading = false; _error = 'Erreur de recherche'; });
    }
  }

  void _openForm({ClientModel? client}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TiersFormScreen(
          isClient: true,
          client: client,
        ),
      ),
    );
    if (result == true) _loadClients();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadClients,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.person_add),
        label: const Text('Nouveau client'),
        backgroundColor: QuantisColors.royalBlue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _search,
              decoration: InputDecoration(
                hintText: 'Rechercher par nom ou téléphone...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _loadClients();
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Liste
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline, size: 48, color: QuantisColors.error),
                            const SizedBox(height: 8),
                            Text(_error!, style: TextStyle(color: QuantisColors.error)),
                            const SizedBox(height: 16),
                            ElevatedButton(onPressed: _loadClients, child: const Text('Réessayer')),
                          ],
                        ),
                      )
                    : _clients.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.people_outline, size: 64, color: QuantisColors.textMuted),
                                SizedBox(height: 8),
                                Text('Aucun client trouvé', style: TextStyle(color: QuantisColors.textMuted)),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadClients,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _clients.length,
                              itemBuilder: (_, i) => _ClientTile(
                                client: _clients[i],
                                onTap: () => _openForm(client: _clients[i]),
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _ClientTile extends StatelessWidget {
  final ClientModel client;
  final VoidCallback onTap;

  const _ClientTile({required this.client, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasDebt = client.soldeCredit > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: QuantisColors.royalBlue.withValues(alpha: 0.1),
          child: Text(
            client.nom.isNotEmpty ? client.nom[0].toUpperCase() : '?',
            style: const TextStyle(
              color: QuantisColors.royalBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        title: Text(client.nom, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          [
            if (client.telephone != null) client.telephone!,
            if (client.email != null) client.email!,
          ].join(' • '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13),
        ),
        trailing: hasDebt
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: QuantisColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${client.soldeCredit.toStringAsFixed(0)} FCFA',
                  style: const TextStyle(
                    color: QuantisColors.warning,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              )
            : const Icon(Icons.chevron_right, color: QuantisColors.textMuted),
      ),
    );
  }
}
