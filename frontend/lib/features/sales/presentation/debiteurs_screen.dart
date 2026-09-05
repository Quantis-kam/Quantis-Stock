import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/quantis_theme.dart';

/// Écran dédié à la gestion des débiteurs & créances clients.
class DebiteursScreen extends StatefulWidget {
  const DebiteursScreen({super.key});

  @override
  State<DebiteursScreen> createState() => _DebiteursScreenState();
}

class _DebiteursScreenState extends State<DebiteursScreen> {
  List<dynamic> _debiteurs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDebiteurs();
  }

  Future<void> _loadDebiteurs() async {
    setState(() { _loading = true; _error = null; });
    try {
      final dio = ApiClient.instance;
      final response = await dio.get('/clients', queryParameters: {'size': 100});
      final data = response.data['data']['content'] as List;

      // Filtrer uniquement les clients ayant des créances (soldeCredit > 0)
      final debiteurs = data.where((c) {
        final solde = (c['soldeCredit'] as num? ?? 0).toDouble();
        return solde > 0;
      }).toList();

      if (mounted) {
        setState(() {
          _debiteurs = debiteurs;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erreur lors du chargement : $e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalCreances = _debiteurs.fold<double>(
      0.0,
      (sum, c) => sum + ((c['soldeCredit'] as num? ?? 0).toDouble()),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des Débiteurs', style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadDebiteurs),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: QuantisColors.error)))
              : Column(
                  children: [
                    // Summary Header Card
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Card(
                        color: Colors.amber.shade900,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Row(
                            children: [
                              const CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.white24,
                                child: Icon(Icons.account_balance_wallet, color: Colors.white, size: 28),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('TOTAL CRÉANCES CLIENTS À RECOUVRER', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${totalCreances.toStringAsFixed(0)} FCFA',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${_debiteurs.length} clients débiteurs',
                                  style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // List of Debtors
                    Expanded(
                      child: _debiteurs.isEmpty
                          ? const Center(child: Text('Aucun client débiteur enregistré ! 🎉', style: TextStyle(color: QuantisColors.textMuted)))
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _debiteurs.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final d = _debiteurs[index];
                                final solde = (d['soldeCredit'] as num? ?? 0).toDouble();

                                return Card(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.amber.withValues(alpha: 0.15),
                                      foregroundColor: Colors.amber.shade900,
                                      child: Text(d['nom'] != null && d['nom'].toString().isNotEmpty ? d['nom'].toString()[0].toUpperCase() : 'C'),
                                    ),
                                    title: Text(d['nom'] ?? 'Client', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text('Tél : ${d['telephone'] ?? "Non renseigné"}'),
                                    trailing: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${solde.toStringAsFixed(0)} FCFA',
                                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900, fontSize: 15),
                                        ),
                                        const Text('Créance due', style: TextStyle(fontSize: 10, color: QuantisColors.textMuted)),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}
