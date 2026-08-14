import 'package:flutter/material.dart';
import '../../../core/theme/quantis_theme.dart';
import '../data/stock_service.dart';

/// Écran mouvements de stock — historique + alertes.
class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final StockApiService _service = StockApiService();

  List<MouvementModel> _mouvements = [];
  List<StockCourantModel> _alertes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() { if (!_tabCtrl.indexIsChanging) _load(); });
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      if (_tabCtrl.index == 0) {
        _mouvements = await _service.getMouvements();
      } else {
        _alertes = await _service.getAlertes();
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Color _typeColor(String type) => switch (type) {
        'ENTREE' => QuantisColors.success,
        'SORTIE' => QuantisColors.error,
        'TRANSFERT' => QuantisColors.info,
        'AJUSTEMENT' => QuantisColors.warning,
        _ => QuantisColors.textMuted,
      };

  IconData _typeIcon(String type) => switch (type) {
        'ENTREE' => Icons.arrow_downward,
        'SORTIE' => Icons.arrow_upward,
        'TRANSFERT' => Icons.swap_horiz,
        'AJUSTEMENT' => Icons.tune,
        _ => Icons.help,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion de Stock'),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: QuantisColors.royalBlue,
          unselectedLabelColor: QuantisColors.textMuted,
          indicatorColor: QuantisColors.luxuryGold,
          tabs: const [
            Tab(icon: Icon(Icons.history, size: 18), text: 'Mouvements'),
            Tab(icon: Icon(Icons.warning_amber, size: 18), text: 'Alertes'),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tabCtrl.index == 0
              ? _buildMouvements()
              : _buildAlertes(),
    );
  }

  Widget _buildMouvements() {
    if (_mouvements.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swap_horiz, size: 64, color: QuantisColors.textMuted),
            SizedBox(height: 8),
            Text('Aucun mouvement', style: TextStyle(color: QuantisColors.textMuted)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _mouvements.length,
        itemBuilder: (_, i) {
          final m = _mouvements[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _typeColor(m.type).withValues(alpha: 0.12),
                child: Icon(_typeIcon(m.type), color: _typeColor(m.type), size: 20),
              ),
              title: Text(m.produitNom ?? 'Produit', style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${m.typeLabel} — ${m.motifLabel}', style: const TextStyle(fontSize: 12)),
              trailing: Text(
                '${m.type == "SORTIE" ? "-" : "+"}${m.quantite.toStringAsFixed(0)}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: _typeColor(m.type),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAlertes() {
    if (_alertes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 64, color: QuantisColors.success.withValues(alpha: 0.5)),
            const SizedBox(height: 8),
            const Text('Aucune alerte de stock', style: TextStyle(color: QuantisColors.textMuted)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _alertes.length,
        itemBuilder: (_, i) {
          final a = _alertes[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: a.isRupture
                ? QuantisColors.error.withValues(alpha: 0.05)
                : QuantisColors.warning.withValues(alpha: 0.05),
            child: ListTile(
              leading: Icon(
                a.isRupture ? Icons.error : Icons.warning_amber,
                color: a.isRupture ? QuantisColors.error : QuantisColors.warning,
              ),
              title: Text(a.produitNom ?? '?', style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(a.depotNom ?? '', style: const TextStyle(fontSize: 12)),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${a.quantite.toStringAsFixed(0)} unités',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: a.isRupture ? QuantisColors.error : QuantisColors.warning,
                    ),
                  ),
                  Text('Seuil: ${a.seuilAlerte}', style: const TextStyle(fontSize: 11, color: QuantisColors.textMuted)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
