import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/quantis_theme.dart';
import '../../../core/utils/whatsapp_share_helper.dart';
import 'super_admin_screen.dart';

/// Onglet Super-Admin : suivi des demandes de création d'entreprise envoyées depuis
/// la page d'accueil vitrine, avec création pré-remplie en 1 clic et réponse WhatsApp.
class DemandesEntreprisesScreen extends StatefulWidget {
  const DemandesEntreprisesScreen({super.key});

  @override
  State<DemandesEntreprisesScreen> createState() => _DemandesEntreprisesScreenState();
}

class _DemandesEntreprisesScreenState extends State<DemandesEntreprisesScreen> {
  List<dynamic> _demandes = [];
  bool _loading = true;
  String? _error;
  String _filter = 'EN_ATTENTE'; // EN_ATTENTE, TRAITEE, REJETEE, ALL

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiClient.instance.get('/platform/demandes');
      final list = (res.data is Map && res.data['data'] is List) ? res.data['data'] as List : [];
      if (mounted) {
        setState(() {
          _demandes = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = ApiClient.formatErrorMessage(e, fallback: 'Erreur chargement des demandes.');
          _loading = false;
        });
      }
    }
  }

  List<dynamic> get _filtered {
    if (_filter == 'ALL') return _demandes;
    return _demandes.where((d) => (d['statut'] ?? 'EN_ATTENTE') == _filter).toList();
  }

  int _countBy(String statut) =>
      _demandes.where((d) => (d['statut'] ?? 'EN_ATTENTE') == statut).length;

  Future<void> _updateStatus(dynamic demande, String statut, {int? entrepriseId, String? note}) async {
    try {
      await ApiClient.instance.patch('/platform/demandes/${demande['id']}/status', data: {
        'statut': statut,
        if (entrepriseId != null) 'entrepriseCreeeId': entrepriseId,
        if (note != null) 'noteAdmin': note,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Demande "${demande['nomEntreprise']}" marquée $statut.'),
            backgroundColor: statut == 'TRAITEE' ? QuantisColors.success : Colors.blueGrey,
          ),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiClient.formatErrorMessage(e, fallback: 'Impossible de mettre à jour la demande.')),
            backgroundColor: QuantisColors.error,
          ),
        );
      }
    }
  }

  void _createFromLead(dynamic demande) {
    final map = Map<String, dynamic>.from(demande as Map);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CreateEntrepriseDialog(
        initialLead: map,
        onCreated: (entrepriseId) {
          _updateStatus(
            demande,
            'TRAITEE',
            entrepriseId: entrepriseId,
            note: 'Entreprise créée depuis le portail Super-Admin',
          );
        },
        onSuccess: _load,
      ),
    );
  }

  Future<void> _contactWhatsApp(dynamic demande) async {
    final phone = (demande['telephone'] ?? '').toString();
    final nomEnt = (demande['nomEntreprise'] ?? 'votre entreprise').toString();
    final resp = (demande['nomResponsable'] ?? '').toString();
    final msg =
        'Bonjour $resp, nous avons bien reçu votre demande de création d\'espace Quantis-Stock pour *$nomEnt*. Nous sommes prêts à activer votre compte !';
    await WhatsappShareHelper.sendDirectMessage(phone: phone, message: msg);
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '—';
    final dt = DateTime.tryParse(raw.toString());
    if (dt == null) return raw.toString();
    return DateFormat('dd/MM/yyyy HH:mm').format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;
    final pendingCount = _countBy('EN_ATTENTE');
    final treatedCount = _countBy('TRAITEE');
    final filtered = _filtered;

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(isMobile ? 14 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête + Compteurs
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Demandes de Création d\'Entreprise',
                        style: TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          color: QuantisColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Prospects reçus depuis la page d\'accueil • Créez leur espace en 1 clic.',
                        style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: QuantisColors.royalBlue),
                  tooltip: 'Actualiser',
                  onPressed: _load,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Filtres rapides avec compteurs
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _filterChip('EN_ATTENTE', 'En attente ($pendingCount)', Colors.orange.shade800),
                _filterChip('TRAITEE', 'Traitées ($treatedCount)', QuantisColors.success),
                _filterChip('REJETEE', 'Refusées (${_countBy('REJETEE')})', Colors.grey.shade700),
                _filterChip('ALL', 'Toutes (${_demandes.length})', QuantisColors.royalBlue),
              ],
            ),
            const SizedBox(height: 16),

            if (_error != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red))),
                    TextButton(onPressed: _load, child: const Text('Réessayer')),
                  ],
                ),
              )
            else if (_loading)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (filtered.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 10),
                    Text(
                      _filter == 'EN_ATTENTE'
                          ? 'Aucune demande en attente pour le moment.'
                          : 'Aucune demande dans cette catégorie.',
                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, idx) => _buildLeadCard(filtered[idx], isMobile: isMobile),
              ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String code, String label, Color color) {
    final selected = _filter == code;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: color,
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.black87,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      onSelected: (_) => setState(() => _filter = code),
    );
  }

  Widget _buildLeadCard(dynamic d, {required bool isMobile}) {
    final statut = (d['statut'] ?? 'EN_ATTENTE').toString();
    final canal = (d['canalContact'] ?? 'WHATSAPP').toString();
    final isPending = statut == 'EN_ATTENTE';
    final isTreated = statut == 'TRAITEE';

    final statusColor = isTreated
        ? QuantisColors.success
        : (isPending ? Colors.orange.shade800 : Colors.grey.shade600);
    final statusLabel = isTreated
        ? 'TRAITÉE'
        : (isPending ? 'EN ATTENTE' : 'REFUSÉE');

    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPending ? Colors.orange.shade300 : Colors.grey.shade200,
          width: isPending ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: QuantisColors.royalBlue.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.storefront_rounded, color: QuantisColors.royalBlue, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (d['nomEntreprise'] ?? 'Entreprise').toString(),
                      style: const TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _pill(statusLabel, statusColor),
                        _pill(
                          canal == 'WHATSAPP' ? 'WhatsApp' : (canal == 'EMAIL' ? 'Email' : 'Formulaire'),
                          canal == 'WHATSAPP' ? const Color(0xFF16A34A) : QuantisColors.royalBlue,
                        ),
                        if (d['secteurActivite'] != null && d['secteurActivite'].toString().isNotEmpty)
                          _pill(d['secteurActivite'].toString(), Colors.blueGrey),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                _formatDate(d['createdAt']),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Coordonnées
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _infoItem(Icons.person_outline, (d['nomResponsable'] ?? '—').toString()),
              _infoItem(Icons.phone_outlined, (d['telephone'] ?? '—').toString()),
              _infoItem(Icons.email_outlined, (d['email'] ?? '—').toString()),
              if (d['ville'] != null && d['ville'].toString().isNotEmpty)
                _infoItem(Icons.location_on_outlined, d['ville'].toString()),
            ],
          ),

          if (d['message'] != null && d['message'].toString().trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                d['message'].toString(),
                style: const TextStyle(fontSize: 12.5, color: QuantisColors.textPrimary),
              ),
            ),
          ],

          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!isTreated)
                ElevatedButton.icon(
                  onPressed: () => _createFromLead(d),
                  icon: const Icon(Icons.add_business_rounded, size: 16),
                  label: const Text('Créer l\'entreprise', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: QuantisColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: () => _contactWhatsApp(d),
                icon: const Icon(Icons.chat_rounded, size: 15, color: Color(0xFF16A34A)),
                label: const Text('WhatsApp', style: TextStyle(fontSize: 12, color: Color(0xFF16A34A))),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF16A34A)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
              if (isPending) ...[
                OutlinedButton.icon(
                  onPressed: () => _updateStatus(d, 'TRAITEE'),
                  icon: const Icon(Icons.check, size: 15),
                  label: const Text('Marquer traitée', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                ),
                TextButton.icon(
                  onPressed: () => _updateStatus(d, 'REJETEE'),
                  icon: const Icon(Icons.close, size: 15, color: Colors.red),
                  label: const Text('Refuser', style: TextStyle(fontSize: 12, color: Colors.red)),
                ),
              ] else ...[
                TextButton.icon(
                  onPressed: () => _updateStatus(d, 'EN_ATTENTE'),
                  icon: const Icon(Icons.undo, size: 15),
                  label: const Text('Remettre en attente', style: TextStyle(fontSize: 12)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _infoItem(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 5),
        Flexible(
          child: Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}

