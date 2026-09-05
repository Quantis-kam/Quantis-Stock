import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/quantis_theme.dart';
import '../data/document_models.dart';
import '../data/document_service.dart';
import 'paiement_facture_dialog.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../sales/presentation/ticket_receipt_dialog.dart';
import 'whatsapp_share_dialog.dart';
import 'invoice_pdf_generator.dart';

/// Thèmes de couleurs pour personnalisation de la facture
class InvoiceColorTheme {
  final String name;
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color lightBg;

  const InvoiceColorTheme({
    required this.name,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.lightBg,
  });
}

final List<InvoiceColorTheme> kInvoiceThemes = [
  const InvoiceColorTheme(
    name: 'Bleu Marine & Or',
    primary: Color(0xFF1E3A8A),
    secondary: Color(0xFF3B82F6),
    accent: Color(0xFFD97706),
    lightBg: Color(0xFFEFF6FF),
  ),
  const InvoiceColorTheme(
    name: 'Émeraude Moderne',
    primary: Color(0xFF065F46),
    secondary: Color(0xFF10B981),
    accent: Color(0xFF047857),
    lightBg: Color(0xFFECFDF5),
  ),
  const InvoiceColorTheme(
    name: 'Anthracite & Ardoise',
    primary: Color(0xFF1E293B),
    secondary: Color(0xFF475569),
    accent: Color(0xFF2563EB),
    lightBg: Color(0xFFF8FAFC),
  ),
  const InvoiceColorTheme(
    name: 'Bordeaux Prestige',
    primary: Color(0xFF831843),
    secondary: Color(0xFFBE185D),
    accent: Color(0xFFF59E0B),
    lightBg: Color(0xFFFDF2F8),
  ),
  const InvoiceColorTheme(
    name: 'Violet Tech',
    primary: Color(0xFF4C1D95),
    secondary: Color(0xFF7C3AED),
    accent: Color(0xFF10B981),
    lightBg: Color(0xFFF5F3FF),
  ),
];

/// Gabarits de mise en page pour la facture
enum InvoiceLayoutTemplate {
  corporate('Corporate Premium', Icons.business, 'Format équilibré classique et moderne avec encarts structurés'),
  bandeau('Bandeau Moderne', Icons.view_headline, 'En-tête plein format avec cartes flottantes et design contemporain'),
  minimaliste('Minimaliste Épuré', Icons.crop_portrait, 'Style éditorial suisse haute précision, typographie sobre et lignes fines'),
  commercial('Bordereau Commercial Pro', Icons.table_chart, 'Format ERP dense avec ventilation détaillée de TVA et cadre de signature');

  final String label;
  final IconData icon;
  final String description;
  const InvoiceLayoutTemplate(this.label, this.icon, this.description);
}

/// Écran détail et prévisualisation moderne de facture avec choix de gabarits & thèmes
class DocumentDetailScreen extends StatefulWidget {
  final int documentId;
  const DocumentDetailScreen({super.key, required this.documentId});

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  final DocumentService _service = DocumentService();
  final ApiClient _api = ApiClient();

  DocumentModel? _doc;
  Map<String, dynamic>? _entreprise;
  bool _loading = true;

  int _selectedThemeIndex = 0;
  InvoiceLayoutTemplate _selectedTemplate = InvoiceLayoutTemplate.corporate;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final docFuture = _service.getDocument(widget.documentId);
      final entFuture = _api.get('/entreprise');

      final results = await Future.wait([docFuture, entFuture]);
      _doc = results[0] as DocumentModel;
      _entreprise = (results[1] as dynamic).data['data'] as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('Erreur chargement facture: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _valider() async {
    try {
      await _service.valider(widget.documentId);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document validé avec succès'), backgroundColor: QuantisColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: QuantisColors.error),
        );
      }
    }
  }

  Future<void> _ouvrirPaiement() async {
    if (_doc == null) return;
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => PaiementFactureDialog(document: _doc!),
    );
    if (res == true) {
      _load();
    }
  }

  Future<void> _convertir(String targetType) async {
    try {
      final res = await _api.post('/documents/${widget.documentId}/convert?targetType=$targetType');
      final newDoc = res.data['data'] as Map<String, dynamic>;
      final newId = newDoc['id'] as int;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Document converti en ${newDoc['numero']} avec succès !'),
            backgroundColor: QuantisColors.success,
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => DocumentDetailScreen(documentId: newId)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur conversion: $e'), backgroundColor: QuantisColors.error),
        );
      }
    }
  }

  void _ouvrirTicketReceipt() {
    if (_doc == null) return;
    final saleData = {
      'document': {
        'numero': _doc!.numero,
        'dateDocument': _doc!.dateDocument,
        'totalTtc': _doc!.totalTtc,
        'lignes': _doc!.lignes.map((l) => {
          'designation': l.designation,
          'quantite': l.quantite,
          'prixUnitaire': l.prixUnitaire,
          'totalTtc': l.montantTtc,
        }).toList(),
      },
      'montantTotal': _doc!.totalTtc,
      'montantPaye': _doc!.montantPaye,
      'montantRecu': _doc!.montantPaye,
      'monnaieRendue': 0.0,
      'soldeRestant': _doc!.soldeRestant,
      'clientNom': _doc!.clientNom ?? 'Client',
      'entrepriseNom': _entreprise?['nom'] ?? ApiClient.entrepriseNom,
      'entrepriseNif': _entreprise?['nif'],
      'entrepriseRccm': _entreprise?['rccm'],
      'entrepriseTelephone': _entreprise?['telephone'],
      'entrepriseAdresse': _entreprise?['adresse'],
      'entrepriseLogoUrl': _entreprise?['logoUrl'] ?? ApiClient.logoUrl,
      'entrepriseMonnaie': _entreprise?['monnaie'] ?? ApiClient.entrepriseMonnaie,
    };

    showDialog(
      context: context,
      builder: (_) => TicketReceiptDialog(saleData: saleData),
    );
  }

  Widget _buildLogo(String? logoUrl, {double size = 80, bool inHeaderBanner = false}) {
    if (logoUrl == null || logoUrl.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: inHeaderBanner ? Colors.white : kInvoiceThemes[_selectedThemeIndex].lightBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: inHeaderBanner ? Colors.white30 : kInvoiceThemes[_selectedThemeIndex].primary.withValues(alpha: 0.3),
          ),
        ),
        child: Center(
          child: Icon(
            Icons.store,
            size: size * 0.5,
            color: inHeaderBanner ? kInvoiceThemes[_selectedThemeIndex].primary : kInvoiceThemes[_selectedThemeIndex].primary,
          ),
        ),
      );
    }

    Widget imageWidget;
    if (logoUrl.startsWith('data:image')) {
      try {
        final commaIndex = logoUrl.indexOf(',');
        final base64Str = commaIndex != -1 ? logoUrl.substring(commaIndex + 1) : logoUrl;
        final Uint8List bytes = base64Decode(base64Str);
        imageWidget = Image.memory(bytes, height: size, fit: BoxFit.contain);
      } catch (_) {
        imageWidget = Icon(Icons.receipt_long, size: size * 0.6, color: QuantisColors.royalBlue);
      }
    } else {
      imageWidget = Image.network(
        logoUrl,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(Icons.receipt_long, size: size * 0.6, color: QuantisColors.royalBlue),
      );
    }

    if (inHeaderBanner) {
      return Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
        ),
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_doc == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Facture')),
        body: const Center(child: Text('Document introuvable')),
      );
    }

    final doc = _doc!;
    final theme = kInvoiceThemes[_selectedThemeIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text('${doc.typeLabel} ${doc.numero}', style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          // Bouton Impression A4
          ElevatedButton.icon(
            onPressed: () => InvoicePdfGenerator.printDocument(doc, entreprise: _entreprise),
            icon: const Icon(Icons.print, size: 18),
            label: const Text('Imprimer A4'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primary,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 8),

          // Bouton Télécharger PDF
          OutlinedButton.icon(
            onPressed: () => InvoicePdfGenerator.downloadPdf(doc, entreprise: _entreprise),
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Télécharger PDF'),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.primary,
            ),
          ),
          const SizedBox(width: 8),

          // Bouton Ticket 80mm
          OutlinedButton.icon(
            onPressed: _ouvrirTicketReceipt,
            icon: const Icon(Icons.receipt, size: 18),
            label: const Text('Ticket 80mm'),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.primary,
            ),
          ),
          const SizedBox(width: 8),

          // Bouton Partager WhatsApp
          ElevatedButton.icon(
            onPressed: () => WhatsappShareDialog.show(context, doc, entreprise: _entreprise),
            icon: const Icon(Icons.chat_outlined, size: 18),
            label: const Text('Partager WhatsApp'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 8),

          if (doc.canValidate)
            ElevatedButton.icon(
              onPressed: _valider,
              icon: const Icon(Icons.check_circle, size: 18),
              label: const Text('Valider'),
              style: ElevatedButton.styleFrom(backgroundColor: QuantisColors.success, foregroundColor: Colors.white),
            ),
          if (doc.canValidate) const SizedBox(width: 8),

          // Boutons de conversion si validé
          if (doc.statut == 'VALIDE' && doc.type == 'DEVIS') ...[
            ElevatedButton.icon(
              onPressed: () => _convertir('COMMANDE_CLIENT'),
              icon: const Icon(Icons.shopping_bag_outlined, size: 16),
              label: const Text('Créer Commande'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => _convertir('FACTURE'),
              icon: const Icon(Icons.receipt_long, size: 16),
              label: const Text('Facturer'),
              style: ElevatedButton.styleFrom(backgroundColor: QuantisColors.royalBlue, foregroundColor: Colors.white),
            ),
            const SizedBox(width: 8),
          ],

          if (doc.statut == 'VALIDE' && doc.type == 'COMMANDE_CLIENT') ...[
            ElevatedButton.icon(
              onPressed: () => _convertir('FACTURE'),
              icon: const Icon(Icons.receipt_long, size: 16),
              label: const Text('Facturer la Commande'),
              style: ElevatedButton.styleFrom(backgroundColor: QuantisColors.royalBlue, foregroundColor: Colors.white),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _convertir('BON_LIVRAISON'),
              icon: const Icon(Icons.local_shipping, size: 16),
              label: const Text('Bon de Livraison'),
            ),
            const SizedBox(width: 8),
          ],

          if (doc.canPay)
            ElevatedButton.icon(
              onPressed: _ouvrirPaiement,
              icon: const Icon(Icons.payments, size: 18),
              label: const Text('Encaisser'),
              style: ElevatedButton.styleFrom(backgroundColor: QuantisColors.luxuryGold, foregroundColor: Colors.black87),
            ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          children: [
            // BARRE DE CONFIGURATION DU FORMAT ET DES COULEURS
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Choix du Gabarit / Format
                  Row(
                    children: [
                      const Icon(Icons.dashboard_customize_outlined, size: 20, color: QuantisColors.royalBlue),
                      const SizedBox(width: 8),
                      const Text(
                        'Format & Gabarit de Facture :',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: InvoiceLayoutTemplate.values.map((tmpl) {
                      final isSelected = _selectedTemplate == tmpl;
                      return ChoiceChip(
                        avatar: Icon(
                          tmpl.icon,
                          size: 16,
                          color: isSelected ? Colors.white : theme.primary,
                        ),
                        label: Text(tmpl.label),
                        selected: isSelected,
                        selectedColor: theme.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        onSelected: (sel) {
                          if (sel) setState(() => _selectedTemplate = tmpl);
                        },
                      );
                    }).toList(),
                  ),
                  const Divider(height: 24),

                  // 2. Choix de la Palette de Couleurs
                  Row(
                    children: [
                      const Icon(Icons.palette_outlined, size: 20, color: Colors.grey),
                      const SizedBox(width: 8),
                      const Text('Palette de Couleurs :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: List.generate(kInvoiceThemes.length, (i) {
                            final t = kInvoiceThemes[i];
                            final isSelected = _selectedThemeIndex == i;
                            return ChoiceChip(
                              avatar: CircleAvatar(backgroundColor: t.primary, radius: 8),
                              label: Text(t.name),
                              selected: isSelected,
                              selectedColor: t.lightBg,
                              labelStyle: TextStyle(
                                color: isSelected ? t.primary : Colors.black87,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 12,
                              ),
                              onSelected: (sel) {
                                if (sel) setState(() => _selectedThemeIndex = i);
                              },
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // FEUILLE DE FACTURE A4 DYNAMIQUE SELON LE GABARIT CHOISI
            Center(
              child: Container(
                width: 900,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 24,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: _buildSelectedLayout(doc, theme),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedLayout(DocumentModel doc, InvoiceColorTheme theme) {
    return switch (_selectedTemplate) {
      InvoiceLayoutTemplate.corporate => _buildLayoutCorporate(doc, theme),
      InvoiceLayoutTemplate.bandeau => _buildLayoutBandeau(doc, theme),
      InvoiceLayoutTemplate.minimaliste => _buildLayoutMinimaliste(doc, theme),
      InvoiceLayoutTemplate.commercial => _buildLayoutCommercial(doc, theme),
    };
  }

  // =========================================================================
  // GABARIT 1 : CORPORATE PREMIUM (Classique Moderne Équilibré)
  // =========================================================================
  Widget _buildLayoutCorporate(DocumentModel doc, InvoiceColorTheme theme) {
    final String entNom = _entreprise?['nom'] ?? ApiClient.entrepriseNom;
    final String? logoUrl = _entreprise?['logoUrl'] ?? ApiClient.logoUrl;
    final String nif = _entreprise?['nif'] ?? '';
    final String rccm = _entreprise?['rccm'] ?? '';
    final String tel = _entreprise?['telephone'] ?? '';
    final String email = _entreprise?['email'] ?? '';
    final String adr = _entreprise?['adresse'] ?? '';
    final String monnaie = _entreprise?['monnaie'] ?? ApiClient.entrepriseMonnaie;
    final bool isPayee = doc.statut == 'VALIDE' && doc.isPayeIntegral;

    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLogo(logoUrl),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entNom.toUpperCase(),
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: theme.primary, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 4),
                          if (adr.isNotEmpty) Text(adr, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                          if (tel.isNotEmpty) Text('Tél : $tel', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                          if (email.isNotEmpty) Text('Email : $email', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                          const SizedBox(height: 4),
                          if (nif.isNotEmpty || rccm.isNotEmpty)
                            Text('NIF : $nif • RCCM : $rccm', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      doc.typeLabel.toUpperCase(),
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: theme.primary, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 4),
                    Text(doc.numero, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    _buildStatutBadge(doc, isPayee),
                  ],
                ),
              ),
            ],
          ),

          // Ligne Décorative
          Container(
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [theme.primary, theme.secondary, theme.accent]),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Client & Dates
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.lightBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.primary.withValues(alpha: 0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('FACTURÉ À :', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.primary)),
                      const SizedBox(height: 6),
                      Text(doc.clientNom ?? 'Client Divers / Comptoir', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('Client commercial • Vente comptoir', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      _rowInfo('Date d\'émission :', doc.dateDocument ?? '—'),
                      const SizedBox(height: 6),
                      _rowInfo('Date d\'échéance :', doc.dateEcheance ?? 'À réception'),
                      const SizedBox(height: 6),
                      _rowInfo('Devise :', monnaie),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Tableau Standard
          _buildStandardTable(doc, theme, monnaie),
          const SizedBox(height: 24),

          // Totaux & Règlements
          _buildTotalsSection(doc, theme, monnaie),
          const SizedBox(height: 40),
          _buildFooterNote(doc, monnaie),
        ],
      ),
    );
  }

  // =========================================================================
  // GABARIT 2 : BANDEAU MODERNE (Design Stripe / Header Plein Format)
  // =========================================================================
  Widget _buildLayoutBandeau(DocumentModel doc, InvoiceColorTheme theme) {
    final String entNom = _entreprise?['nom'] ?? ApiClient.entrepriseNom;
    final String? logoUrl = _entreprise?['logoUrl'] ?? ApiClient.logoUrl;
    final String nif = _entreprise?['nif'] ?? '';
    final String rccm = _entreprise?['rccm'] ?? '';
    final String tel = _entreprise?['telephone'] ?? '';
    final String adr = _entreprise?['adresse'] ?? '';
    final String monnaie = _entreprise?['monnaie'] ?? ApiClient.entrepriseMonnaie;
    final bool isPayee = doc.statut == 'VALIDE' && doc.isPayeIntegral;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Grand Bandeau Supérieur Coloré
        Container(
          padding: const EdgeInsets.all(36),
          decoration: BoxDecoration(
            color: theme.primary,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Row(
            children: [
              _buildLogo(logoUrl, size: 70, inHeaderBanner: true),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entNom.toUpperCase(),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$adr  •  Tél: $tel',
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                    if (nif.isNotEmpty)
                      Text('NIF : $nif | RCCM : $rccm', style: const TextStyle(fontSize: 11, color: Colors.white60)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    doc.typeLabel.toUpperCase(),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5),
                  ),
                  Text(doc.numero, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 6),
                  _buildStatutBadge(doc, isPayee, whiteBg: true),
                ],
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cartes Bi-colonnes
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('DESTINATAIRE / CLIENT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.secondary)),
                          const SizedBox(height: 6),
                          Text(doc.clientNom ?? 'Client Comptoir', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text('Vente au comptoir • Paiement direct', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.lightBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: theme.primary.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        children: [
                          _rowInfo('Date Document :', doc.dateDocument ?? '—'),
                          const SizedBox(height: 6),
                          _rowInfo('Date Échéance :', doc.dateEcheance ?? 'Immédiat'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Tableau Stylé Moderne
              _buildStandardTable(doc, theme, monnaie),
              const SizedBox(height: 24),

              _buildTotalsSection(doc, theme, monnaie),
              const SizedBox(height: 40),
              _buildFooterNote(doc, monnaie),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // GABARIT 3 : MINIMALISTE ÉPURÉ (Style Éditorial Suisse Haute Précision)
  // =========================================================================
  Widget _buildLayoutMinimaliste(DocumentModel doc, InvoiceColorTheme theme) {
    final String entNom = _entreprise?['nom'] ?? ApiClient.entrepriseNom;
    final String? logoUrl = _entreprise?['logoUrl'] ?? ApiClient.logoUrl;
    final String nif = _entreprise?['nif'] ?? '';
    final String rccm = _entreprise?['rccm'] ?? '';
    final String tel = _entreprise?['telephone'] ?? '';
    final String email = _entreprise?['email'] ?? '';
    final String adr = _entreprise?['adresse'] ?? '';
    final String monnaie = _entreprise?['monnaie'] ?? ApiClient.entrepriseMonnaie;
    final bool isPayee = doc.statut == 'VALIDE' && doc.isPayeIntegral;

    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header minimaliste
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLogo(logoUrl, size: 60),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entNom, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black87)),
                    Text('$adr  •  Tél: $tel  •  $email', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    if (nif.isNotEmpty) Text('NIF: $nif | RCCM: $rccm', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(doc.typeLabel, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w300, color: theme.primary)),
                  Text(doc.numero, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  Text('Date : ${doc.dateDocument ?? "—"}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ],
          ),

          const SizedBox(height: 30),
          const Divider(thickness: 0.8),
          const SizedBox(height: 16),

          // Client
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Facturé à', style: TextStyle(fontSize: 11, color: Colors.grey.shade500, letterSpacing: 0.5)),
                  Text(doc.clientNom ?? 'Client Divers', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ],
              ),
              _buildStatutBadge(doc, isPayee),
            ],
          ),
          const SizedBox(height: 24),

          // Table épurée sans gros fonds colorés
          Table(
            columnWidths: const {
              0: FlexColumnWidth(1),
              1: FlexColumnWidth(6),
              2: FlexColumnWidth(2),
              3: FlexColumnWidth(3),
              4: FlexColumnWidth(2),
              5: FlexColumnWidth(3),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.primary, width: 2))),
                children: [
                  _th('#'),
                  _th('ARTICLE / DESCRIPTION'),
                  _th('QTÉ', align: TextAlign.center),
                  _th('P.U. HT', align: TextAlign.right),
                  _th('TVA', align: TextAlign.center),
                  _th('TOTAL TTC', align: TextAlign.right),
                ],
              ),
              ...List.generate(doc.lignes.length, (i) {
                final l = doc.lignes[i];
                return TableRow(
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
                  children: [
                    _td('${i + 1}'),
                    _td(l.designation, bold: true),
                    _td('${l.quantite.toStringAsFixed(0)}', align: TextAlign.center),
                    _td('${l.prixUnitaire.toStringAsFixed(0)} $monnaie', align: TextAlign.right),
                    _td('${l.tauxTva.toStringAsFixed(0)}%', align: TextAlign.center),
                    _td('${l.montantTtc.toStringAsFixed(0)} $monnaie', align: TextAlign.right, bold: true, color: theme.primary),
                  ],
                );
              }),
            ],
          ),
          const SizedBox(height: 24),

          _buildTotalsSection(doc, theme, monnaie),
          const SizedBox(height: 40),
          _buildFooterNote(doc, monnaie),
        ],
      ),
    );
  }

  // =========================================================================
  // GABARIT 4 : BORDEREAU COMMERCIAL PRO (Format ERP dense & exhaustif)
  // =========================================================================
  Widget _buildLayoutCommercial(DocumentModel doc, InvoiceColorTheme theme) {
    final String entNom = _entreprise?['nom'] ?? ApiClient.entrepriseNom;
    final String? logoUrl = _entreprise?['logoUrl'] ?? ApiClient.logoUrl;
    final String nif = _entreprise?['nif'] ?? '';
    final String rccm = _entreprise?['rccm'] ?? '';
    final String tel = _entreprise?['telephone'] ?? '';
    final String adr = _entreprise?['adresse'] ?? '';
    final String monnaie = _entreprise?['monnaie'] ?? ApiClient.entrepriseMonnaie;
    final bool isPayee = doc.statut == 'VALIDE' && doc.isPayeIntegral;

    return Padding(
      padding: const EdgeInsets.all(36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cadre double en-tête ERP
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black87, width: 1.5),
            ),
            child: Row(
              children: [
                _buildLogo(logoUrl, size: 75),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entNom.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                      Text(adr, style: const TextStyle(fontSize: 11)),
                      Text('Tél : $tel', style: const TextStyle(fontSize: 11)),
                      Text('NIF : $nif  •  RCCM : $rccm', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    children: [
                      Text(doc.typeLabel.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(doc.numero, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Cadres Bi-colonne Client et Détails
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('CLIENT :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      const SizedBox(height: 4),
                      Text(doc.clientNom ?? 'Client Divers', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400)),
                  child: Column(
                    children: [
                      _rowInfo('Date Document :', doc.dateDocument ?? '—'),
                      _rowInfo('Échéance :', doc.dateEcheance ?? 'Comptant'),
                      _rowInfo('Statut :', isPayee ? 'PAYÉE' : doc.statutLabel),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildStandardTable(doc, theme, monnaie),
          const SizedBox(height: 20),

          _buildTotalsSection(doc, theme, monnaie),
          const SizedBox(height: 30),

          // Double cadre d'émargement Bon pour Accord & Cachet
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 90,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Mention « Bon pour Accord » & Signature Client :', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  height: 90,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Cachet & Signature Société :', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Document officiel émis par Quantis Stock • Conservez cette facture pour toute réclamation.',
              style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // ÉLÉMENTS COMMUNS & COMPOSANTS REUTILISABLES
  // =========================================================================

  Widget _buildStandardTable(DocumentModel doc, InvoiceColorTheme theme, String monnaie) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Column(
          children: [
            Container(
              color: theme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: const [
                  Expanded(flex: 1, child: Text('#', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(flex: 6, child: Text('DÉSIGNATION / ARTICLE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(flex: 2, child: Text('QTÉ', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(flex: 3, child: Text('PRIX UNIT. HT', textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(flex: 2, child: Text('TVA', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(flex: 3, child: Text('TOTAL TTC', textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                ],
              ),
            ),
            ...List.generate(doc.lignes.length, (i) {
              final l = doc.lignes[i];
              final isEven = i % 2 == 0;
              return Container(
                color: isEven ? Colors.white : Colors.grey.shade50,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(flex: 1, child: Text('${i + 1}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
                    Expanded(flex: 6, child: Text(l.designation, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                    Expanded(flex: 2, child: Text('${l.quantite.toStringAsFixed(0)}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
                    Expanded(flex: 3, child: Text('${l.prixUnitaire.toStringAsFixed(0)} $monnaie', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12))),
                    Expanded(flex: 2, child: Text('${l.tauxTva.toStringAsFixed(0)}%', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey.shade700))),
                    Expanded(
                      flex: 3,
                      child: Text(
                        '${l.montantTtc.toStringAsFixed(0)} $monnaie',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: theme.primary),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalsSection(DocumentModel doc, InvoiceColorTheme theme, String monnaie) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Règlements
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (doc.paiements.isNotEmpty) ...[
                Text('RÈGLEMENTS ENREGISTRÉS :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: theme.primary)),
                const SizedBox(height: 8),
                ...doc.paiements.map((p) => Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: QuantisColors.success.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: QuantisColors.success.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, size: 16, color: QuantisColors.success),
                      const SizedBox(width: 8),
                      Text('${p.montant.toStringAsFixed(0)} $monnaie (${p.moyenLabel})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      const Spacer(),
                      if (p.datePaiement != null)
                        Text(p.datePaiement!, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                    ],
                  ),
                )),
              ],
              const SizedBox(height: 10),
              if (doc.notes != null && doc.notes!.isNotEmpty) ...[
                Text('NOTES :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey.shade700)),
                const SizedBox(height: 4),
                Text(doc.notes!, style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
              ],
            ],
          ),
        ),
        const SizedBox(width: 40),

        // Total Box
        Expanded(
          flex: 4,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: [
                _rowInfo('Total Brut HT :', '${doc.totalHt.toStringAsFixed(0)} $monnaie'),
                const SizedBox(height: 8),
                _rowInfo('Total TVA (18%) :', '${doc.totalTva.toStringAsFixed(0)} $monnaie'),
                const Divider(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: theme.primary, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('TOTAL TTC :', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(
                        '${doc.totalTtc.toStringAsFixed(0)} $monnaie',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _rowInfo('Montant Payé :', '${doc.montantPaye.toStringAsFixed(0)} $monnaie', bold: true, color: QuantisColors.success),
                const SizedBox(height: 6),
                _rowInfo('Solde Restant :', '${doc.soldeRestant.toStringAsFixed(0)} $monnaie',
                    bold: true, color: doc.soldeRestant > 0 ? QuantisColors.error : QuantisColors.success),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatutBadge(DocumentModel doc, bool isPayee, {bool whiteBg = false}) {
    final color = isPayee ? QuantisColors.success : (doc.statut == 'VALIDE' ? QuantisColors.warning : QuantisColors.textMuted);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: whiteBg ? Colors.white : color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Text(
        isPayee ? 'PAYÉE' : doc.statutLabel.toUpperCase(),
        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: color),
      ),
    );
  }

  Widget _buildFooterNote(DocumentModel doc, String monnaie) {
    return Column(
      children: [
        const Divider(thickness: 1),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Arrêtée la présente facture à la somme de ${doc.totalTtc.toStringAsFixed(0)} $monnaie TTC.',
                    style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  _buildQrVerification(doc, size: 56),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Cachet & Signature :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey.shade700)),
                const SizedBox(height: 40),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'Merci pour votre confiance ! • Document officiel vérifiable par QR Code • Quantis Stock',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
          ),
        ),
      ],
    );
  }

  Widget _buildQrVerification(DocumentModel doc, {double size = 64}) {
    final qrData = 'QUANTIS|ENT:${ApiClient.entrepriseNom}|NIF:${ApiClient.entrepriseNif}|NUM:${doc.numero}|DATE:${doc.dateDocument}|TTC:${doc.totalTtc.toStringAsFixed(0)} ${ApiClient.entrepriseMonnaie}';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: QrImageView(
            data: qrData,
            version: QrVersions.auto,
            size: size,
            padding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('AUTHENTICITÉ FISCALE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9, letterSpacing: 0.5)),
            Text('Scanner pour vérifier le document', style: TextStyle(fontSize: 8, color: Colors.grey.shade600)),
            Text('NIF: ${ApiClient.entrepriseNif}', style: TextStyle(fontSize: 8, color: Colors.grey.shade600)),
          ],
        ),
      ],
    );
  }

  Widget _rowInfo(String label, String value, {bool bold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.bold : FontWeight.w600, color: color)),
      ],
    );
  }

  Widget _th(String text, {TextAlign align = TextAlign.left}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text, textAlign: align, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }

  Widget _td(String text, {TextAlign align = TextAlign.left, bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color),
      ),
    );
  }
}
