import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/quantis_theme.dart';

/// Command Palette — Recherche universelle rapide.
class CommandPaletteDialog extends StatefulWidget {
  const CommandPaletteDialog({super.key});

  @override
  State<CommandPaletteDialog> createState() => _CommandPaletteDialogState();
}

class _CommandPaletteDialogState extends State<CommandPaletteDialog> {
  final _controller = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().length < 2) {
      setState(() { _results = []; _loading = false; });
      return;
    }

    setState(() { _loading = true; });

    try {
      final dio = ApiClient.instance;
      final queryLower = query.toLowerCase().trim();
      final items = <Map<String, dynamic>>[];

      // Recherche produits
      final prodRes = await dio.get('/produits', queryParameters: {'search': queryLower, 'size': 5});
      if (prodRes.data['data'] != null && prodRes.data['data']['content'] != null) {
        for (var p in prodRes.data['data']['content']) {
          items.add({
            'type': 'Produit',
            'icon': Icons.inventory_2_outlined,
            'color': QuantisColors.royalBlue,
            'title': p['nom'],
            'subtitle': 'SKU: ${p['sku'] ?? "-"} | Prix: ${p['prixVente']} FCFA',
          });
        }
      }

      // Recherche clients
      final clientRes = await dio.get('/clients', queryParameters: {'search': queryLower, 'size': 5});
      if (clientRes.data['data'] != null && clientRes.data['data']['content'] != null) {
        for (var c in clientRes.data['data']['content']) {
          items.add({
            'type': 'Client',
            'icon': Icons.person_outline,
            'color': Colors.purple,
            'title': c['nom'],
            'subtitle': 'Tél: ${c['telephone'] ?? "-"} | Créance: ${c['soldeCredit'] ?? 0} FCFA',
          });
        }
      }

      setState(() {
        _results = items;
        _loading = false;
      });
    } catch (_) {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.only(top: 80, left: 16, right: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _search,
                decoration: InputDecoration(
                  hintText: 'Rechercher un produit, client, facture (ex: Riz, Amadou)...',
                  prefixIcon: const Icon(Icons.search, color: QuantisColors.royalBlue),
                  suffixIcon: _loading
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              if (_results.isNotEmpty)
                Expanded(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _results[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: (item['color'] as Color).withValues(alpha: 0.15),
                          foregroundColor: item['color'] as Color,
                          child: Icon(item['icon'] as IconData, size: 20),
                        ),
                        title: Text(item['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text(item['subtitle'] as String, style: const TextStyle(fontSize: 12, color: QuantisColors.textMuted)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: (item['color'] as Color).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(item['type'] as String, style: TextStyle(fontSize: 10, color: item['color'] as Color, fontWeight: FontWeight.bold)),
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  ),
                )
              else if (_controller.text.trim().length >= 2 && !_loading)
                const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text('Aucun résultat trouvé.', style: TextStyle(color: QuantisColors.textMuted)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
