import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/quantis_theme.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/file_download_helper.dart';

class ExportsScreen extends StatefulWidget {
  const ExportsScreen({super.key});

  @override
  State<ExportsScreen> createState() => _ExportsScreenState();
}

class _ExportsScreenState extends State<ExportsScreen> {
  DateTime? _dateDebut;
  DateTime? _dateFin;
  String _selectedPreset = 'month'; // 'today', 'month', 'year', 'all', 'custom'

  final Map<String, bool> _exporting = {
    'ventes': false,
    'caisse': false,
    'debiteurs': false,
    'stock': false,
  };

  @override
  void initState() {
    super.initState();
    _applyPreset('month');
  }

  void _applyPreset(String preset) {
    final now = DateTime.now();
    setState(() {
      _selectedPreset = preset;
      switch (preset) {
        case 'today':
          _dateDebut = DateTime(now.year, now.month, now.day);
          _dateFin = DateTime(now.year, now.month, now.day);
          break;
        case 'month':
          _dateDebut = DateTime(now.year, now.month, 1);
          _dateFin = DateTime(now.year, now.month + 1, 0);
          break;
        case 'year':
          _dateDebut = DateTime(now.year, 1, 1);
          _dateFin = DateTime(now.year, 12, 31);
          break;
        case 'all':
          _dateDebut = null;
          _dateFin = null;
          break;
        case 'custom':
          break;
      }
    });
  }

  Future<void> _export(String type, String endpoint, String defaultFilename) async {
    setState(() => _exporting[type] = true);
    try {
      final Map<String, dynamic> params = {};
      if (_dateDebut != null) {
        params['debut'] = DateFormat('yyyy-MM-dd').format(_dateDebut!);
      }
      if (_dateFin != null) {
        params['fin'] = DateFormat('yyyy-MM-dd').format(_dateFin!);
      }

      final response = await ApiClient.instance.get(
        endpoint,
        queryParameters: params,
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = response.data as List<int>;
      final dateSuffix = DateFormat('yyyyMMdd').format(DateTime.now());
      final filename = '${defaultFilename}_$dateSuffix.csv';

      FileDownloadHelper.download(bytes, filename);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 10),
                Text('Export $filename téléchargé avec succès !'),
              ],
            ),
            backgroundColor: QuantisColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'export: $e'),
            backgroundColor: QuantisColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _exporting[type] = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Exports Comptables & Fiscaux', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bandeau de présentation
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [QuantisColors.blueDark, QuantisColors.royalBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: QuantisColors.royalBlue.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.table_view_rounded, color: Colors.white, size: 36),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Exportation des Données Comptables',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Générez des fichiers CSV compatibles Microsoft Excel, Google Sheets et logiciels de comptabilité avec encodage UTF-8 universel.',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Filtres de Période
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Période d\'Exportation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildPresetChip('today', 'Aujourd\'hui'),
                      _buildPresetChip('month', 'Ce Mois-ci'),
                      _buildPresetChip('year', 'Cette Année'),
                      _buildPresetChip('all', 'Tout l\'Historique'),
                      _buildPresetChip('custom', 'Personnalisée'),
                    ],
                  ),
                  if (_selectedPreset == 'custom') ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: _dateDebut ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (d != null) setState(() => _dateDebut = d);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Date de Début',
                                border: OutlineInputBorder(),
                                suffixIcon: Icon(Icons.calendar_today, size: 18),
                              ),
                              child: Text(_dateDebut != null ? dateFormat.format(_dateDebut!) : 'Choisir'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: _dateFin ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (d != null) setState(() => _dateFin = d);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Date de Fin',
                                border: OutlineInputBorder(),
                                suffixIcon: Icon(Icons.calendar_today, size: 18),
                              ),
                              child: Text(_dateFin != null ? dateFormat.format(_dateFin!) : 'Choisir'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Grille des 4 modules d'export
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;
                return GridView.count(
                  crossAxisCount: isWide ? 2 : 1,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: isWide ? 1.8 : 1.5,
                  children: [
                    _buildExportCard(
                      type: 'ventes',
                      title: 'Journal des Ventes & Factures',
                      desc: 'Toutes les factures, devis, commandes et avoirs avec détail HT, TVA, TTC, règlements et soldes.',
                      icon: Icons.receipt_long_rounded,
                      color: QuantisColors.royalBlue,
                      endpoint: '/exports/ventes',
                      defaultFilename: 'journal_ventes',
                    ),
                    _buildExportCard(
                      type: 'caisse',
                      title: 'Journal de Caisse & Règlements',
                      desc: 'Historique exhaustif de tous les encaissements, décaissements, motifs et utilisateurs de caisse.',
                      icon: Icons.point_of_sale_rounded,
                      color: QuantisColors.success,
                      endpoint: '/exports/caisse',
                      defaultFilename: 'journal_caisse',
                    ),
                    _buildExportCard(
                      type: 'debiteurs',
                      title: 'Grand Livre des Débiteurs',
                      desc: 'Liste des clients ayant un solde débiteur (crédit) avec coordonnées et montant dû à recouvrer.',
                      icon: Icons.people_alt_rounded,
                      color: QuantisColors.warning,
                      endpoint: '/exports/debiteurs',
                      defaultFilename: 'grand_livre_debiteurs',
                    ),
                    _buildExportCard(
                      type: 'stock',
                      title: 'État de Valorisation du Stock',
                      desc: 'Inventaire complet par article et dépôt avec valorisation financière au prix d\'achat.',
                      icon: Icons.inventory_2_rounded,
                      color: const Color(0xFF7C3AED),
                      endpoint: '/exports/stock',
                      defaultFilename: 'valorisation_stock',
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(String key, String label) {
    final isSelected = _selectedPreset == key;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      selectedColor: QuantisColors.royalBlue,
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.grey.shade800),
      onSelected: (val) {
        if (val) _applyPreset(key);
      },
    );
  }

  Widget _buildExportCard({
    required String type,
    required String title,
    required String desc,
    required IconData icon,
    required Color color,
    required String endpoint,
    required String defaultFilename,
  }) {
    final isLoading = _exporting[type] ?? false;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Text(
              desc,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : () => _export(type, endpoint, defaultFilename),
              icon: isLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.download_rounded, size: 18),
              label: Text(isLoading ? 'Génération...' : 'Télécharger CSV Excel'),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
