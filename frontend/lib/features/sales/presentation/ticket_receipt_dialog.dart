import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/theme/quantis_theme.dart';
import '../../../core/network/api_client.dart';
import '../../documents/data/document_models.dart';
import '../../documents/presentation/invoice_pdf_generator.dart';

/// Modal d'aperçu et d'impression de reçu thermique (80mm) et facture A4
class TicketReceiptDialog extends StatefulWidget {
  final Map<String, dynamic> saleData;

  const TicketReceiptDialog({
    super.key,
    required this.saleData,
  });

  @override
  State<TicketReceiptDialog> createState() => _TicketReceiptDialogState();
}

class _TicketReceiptDialogState extends State<TicketReceiptDialog> {
  int _selectedFormat = 0; // 0: Ticket 80mm, 1: Facture A4
  bool _isProcessing = false;

  DocumentModel _getDocumentModel() {
    final docMap = widget.saleData['document'] as Map<String, dynamic>? ?? {};
    try {
      return DocumentModel.fromJson(docMap);
    } catch (_) {
      final lignesRaw = (docMap['lignes'] as List<dynamic>?) ?? [];
      final montantPaye = (widget.saleData['montantPaye'] ?? docMap['montantPaye'] ?? 0).toDouble();
      return DocumentModel(
        id: docMap['id'] ?? 0,
        numero: docMap['numero'] ?? widget.saleData['numero'] ?? 'FAC-001',
        type: docMap['type'] ?? 'FACTURE',
        statut: docMap['statut'] ?? 'VALIDE',
        totalHt: (docMap['totalHt'] ?? 0).toDouble(),
        totalTva: (docMap['totalTva'] ?? 0).toDouble(),
        totalTtc: (widget.saleData['montantTotal'] ?? docMap['totalTtc'] ?? 0).toDouble(),
        dateDocument: docMap['dateDocument'] ?? widget.saleData['date'] ?? DateTime.now().toString().substring(0, 10),
        clientNom: widget.saleData['clientNom'] ?? docMap['clientNom'],
        clientTelephone: widget.saleData['clientTelephone'] ?? docMap['clientTelephone'],
        lignes: lignesRaw.map((l) {
          if (l is LigneDocumentModel) return l;
          final m = l as Map<String, dynamic>;
          return LigneDocumentModel(
            id: m['id'] ?? 0,
            designation: m['designation'] ?? m['produit']?['nom'] ?? 'Article',
            quantite: (m['quantite'] ?? 1).toDouble(),
            prixUnitaire: (m['prixUnitaire'] ?? 0).toDouble(),
            tauxTva: (m['tauxTva'] ?? 0).toDouble(),
            montantTtc: (m['totalTtc'] ?? m['montantTtc'] ?? 0).toDouble(),
          );
        }).toList(),
        paiements: [
          if (montantPaye > 0)
            PaiementModel(
              montant: montantPaye,
              moyen: 'ESPECES',
              datePaiement: DateTime.now().toString().substring(0, 10),
            ),
        ],
      );
    }
  }

  Map<String, dynamic> _getEntrepriseMap() {
    return {
      'nom': widget.saleData['entrepriseNom'] ?? ApiClient.entrepriseNom,
      'nif': widget.saleData['entrepriseNif'] ?? ApiClient.entrepriseNif,
      'rccm': widget.saleData['entrepriseRccm'],
      'telephone': widget.saleData['entrepriseTelephone'],
      'adresse': widget.saleData['entrepriseAdresse'],
      'monnaie': widget.saleData['entrepriseMonnaie'] ?? ApiClient.entrepriseMonnaie,
    };
  }

  Future<void> _imprimer() async {
    setState(() => _isProcessing = true);
    try {
      if (_selectedFormat == 0) {
        await InvoicePdfGenerator.printThermalTicket(widget.saleData);
      } else {
        final docModel = _getDocumentModel();
        await InvoicePdfGenerator.printDocument(docModel, entreprise: _getEntrepriseMap());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur impression: $e'), backgroundColor: QuantisColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _partagerWhatsApp() async {
    setState(() => _isProcessing = true);
    try {
      if (_selectedFormat == 0) {
        await InvoicePdfGenerator.shareThermalTicket(widget.saleData);
      } else {
        final docModel = _getDocumentModel();
        await InvoicePdfGenerator.sharePdf(docModel, entreprise: _getEntrepriseMap());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur partage: $e'), backgroundColor: QuantisColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _telecharger() async {
    setState(() => _isProcessing = true);
    try {
      if (_selectedFormat == 0) {
        await InvoicePdfGenerator.downloadThermalTicket(widget.saleData);
      } else {
        final docModel = _getDocumentModel();
        await InvoicePdfGenerator.downloadPdf(docModel, entreprise: _getEntrepriseMap());
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document PDF téléchargé avec succès !'),
            backgroundColor: QuantisColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur téléchargement: $e'), backgroundColor: QuantisColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Widget _buildLogo(String? logoUrl) {
    if (logoUrl == null || logoUrl.isEmpty) {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: QuantisColors.royalBlue.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Icon(Icons.store, size: 32, color: QuantisColors.royalBlue),
        ),
      );
    }

    if (logoUrl.startsWith('data:image')) {
      try {
        final commaIndex = logoUrl.indexOf(',');
        final base64Str = commaIndex != -1 ? logoUrl.substring(commaIndex + 1) : logoUrl;
        final Uint8List bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
          height: 60,
          fit: BoxFit.contain,
        );
      } catch (_) {
        return const Icon(Icons.receipt_long, size: 40, color: QuantisColors.royalBlue);
      }
    }

    return Image.network(
      logoUrl,
      height: 60,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const Icon(Icons.receipt_long, size: 40, color: QuantisColors.royalBlue),
    );
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.saleData['document'] as Map<String, dynamic>? ?? {};
    final lignes = (doc['lignes'] as List<dynamic>?) ?? [];
    final paiement = widget.saleData['paiement'] as Map<String, dynamic>?;

    final String entrepriseNom = widget.saleData['entrepriseNom'] ?? 'Quantis SARL';
    final String? logoUrl = widget.saleData['entrepriseLogoUrl'];
    final String nif = widget.saleData['entrepriseNif'] ?? '';
    final String rccm = widget.saleData['entrepriseRccm'] ?? '';
    final String telephone = widget.saleData['entrepriseTelephone'] ?? '';
    final String adresse = widget.saleData['entrepriseAdresse'] ?? '';
    final String monnaie = widget.saleData['entrepriseMonnaie'] ?? 'FCFA';

    final String numeroFacture = doc['numero'] ?? 'FAC-XXXXX';
    final String dateDoc = doc['dateDocument'] ?? DateTime.now().toString().substring(0, 10);
    final String caissier = widget.saleData['caissierNom'] ?? 'Caissier';
    final String client = widget.saleData['clientNom'] ?? 'Client Divers';

    final num totalTtc = widget.saleData['montantTotal'] ?? doc['totalTtc'] ?? 0;
    final num montantPaye = widget.saleData['montantPaye'] ?? 0;
    final num montantRecu = widget.saleData['montantRecu'] ?? montantPaye;
    final num monnaieRendue = widget.saleData['monnaieRendue'] ?? 0;
    final num soldeRestant = widget.saleData['soldeRestant'] ?? 0;
    final String moyenPaiement = paiement?['moyen'] ?? 'ESPECES';

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 40, vertical: 16),
      child: Container(
        width: isMobile ? screenWidth * 0.95 : (_selectedFormat == 0 ? 460 : 680),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        padding: EdgeInsets.all(isMobile ? 14 : 20),
        child: Column(
          children: [
            // Header Dialog avec switch format
            Row(
              children: [
                const Icon(Icons.check_circle, color: QuantisColors.success, size: 24),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Vente Validée',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('Ticket', style: TextStyle(fontSize: 12)), icon: Icon(Icons.receipt, size: 14)),
                    ButtonSegment(value: 1, label: Text('A4', style: TextStyle(fontSize: 12)), icon: Icon(Icons.description, size: 14)),
                  ],
                  selected: {_selectedFormat},
                  onSelectionChanged: (set) => setState(() => _selectedFormat = set.first),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Contenu du Reçu scrollable
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Logo de l'entreprise
                      _buildLogo(logoUrl),
                      const SizedBox(height: 8),

                      // En-tête Entreprise
                      Text(
                        entrepriseNom.toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5),
                        textAlign: TextAlign.center,
                      ),
                      if (adresse.isNotEmpty)
                        Text(adresse, style: TextStyle(fontSize: 11, color: Colors.grey.shade700), textAlign: TextAlign.center),
                      if (telephone.isNotEmpty)
                        Text('Tél: $telephone', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                      if (nif.isNotEmpty || rccm.isNotEmpty)
                        Text('NIF: $nif | RCCM: $rccm', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),

                      const Divider(thickness: 1, height: 20),

                      // Détails Vente
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Facture: $numeroFacture', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          Text('Date: $dateDoc', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Client: $client', style: const TextStyle(fontSize: 12)),
                          Text('Caissier: $caissier', style: const TextStyle(fontSize: 12)),
                        ],
                      ),

                      const Divider(thickness: 1, height: 20),

                      // Tableau des articles
                      Row(
                        children: const [
                          Expanded(flex: 4, child: Text('Article', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          Expanded(flex: 2, child: Text('Qté', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          Expanded(flex: 2, child: Text('P.U.', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          Expanded(flex: 3, child: Text('Total', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        ],
                      ),
                      const SizedBox(height: 6),

                      ...lignes.map((l) {
                        final desig = l['designation'] ?? l['produit']?['nom'] ?? 'Article';
                        final qte = l['quantite'] ?? 1;
                        final pu = l['prixUnitaire'] ?? 0;
                        final tot = l['totalTtc'] ?? (qte * pu);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Expanded(flex: 4, child: Text(desig, style: const TextStyle(fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis)),
                              Expanded(flex: 2, child: Text('$qte', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11))),
                              Expanded(flex: 2, child: Text('$pu', textAlign: TextAlign.right, style: const TextStyle(fontSize: 11))),
                              Expanded(flex: 3, child: Text('$tot', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                            ],
                          ),
                        );
                      }),

                      const Divider(thickness: 1, height: 20),

                      // Totaux
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('TOTAL TTC', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                          Text(
                            '$totalTtc $monnaie',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: QuantisColors.royalBlue),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Règlement ($moyenPaiement)', style: const TextStyle(fontSize: 12)),
                          Text('$montantPaye $monnaie', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                      if (montantRecu > montantPaye) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Montant Reçu', style: TextStyle(fontSize: 12)),
                            Text('$montantRecu $monnaie', style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Monnaie Rendue', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: QuantisColors.success)),
                            Text('$monnaieRendue $monnaie', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: QuantisColors.success)),
                          ],
                        ),
                      ],
                      if (soldeRestant > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Reste à payer (Crédit)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: QuantisColors.error)),
                            Text('$soldeRestant $monnaie', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: QuantisColors.error)),
                          ],
                        ),
                      ],

                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: QrImageView(
                          data: 'QUANTIS|${widget.saleData['numero'] ?? ''}|TTC:${totalTtc.toStringAsFixed(0)} $monnaie|DATE:${widget.saleData['date'] ?? ''}|NIF:${ApiClient.entrepriseNif}',
                          version: QrVersions.auto,
                          size: 55,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Vérification Fiscale', style: TextStyle(fontSize: 8, color: Colors.grey.shade500)),
                      const SizedBox(height: 12),
                      const Divider(thickness: 1),
                      const SizedBox(height: 4),
                      Text(
                        'Merci pour votre confiance !',
                        style: TextStyle(fontStyle: FontStyle.italic, fontSize: 11, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Quantis Stock • Logiciel de Gestion Commerciale',
                        style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Actions d'impression, partage et téléchargement
            if (isMobile)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isProcessing ? null : _imprimer,
                          icon: const Icon(Icons.print, size: 18),
                          label: Text(_selectedFormat == 0 ? 'Imprimer' : 'Imprimer A4'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: QuantisColors.royalBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isProcessing ? null : _partagerWhatsApp,
                          icon: const Icon(Icons.chat_outlined, size: 18),
                          label: const Text('WhatsApp'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isProcessing ? null : _telecharger,
                          icon: const Icon(Icons.download, size: 18),
                          label: const Text('Télécharger PDF'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Fermer'),
                      ),
                    ],
                  ),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Fermer'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _isProcessing ? null : _telecharger,
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Télécharger PDF'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _partagerWhatsApp,
                    icon: const Icon(Icons.chat_outlined, size: 18),
                    label: const Text('WhatsApp'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _imprimer,
                    icon: const Icon(Icons.print, size: 18),
                    label: Text(_selectedFormat == 0 ? 'Imprimer Ticket' : 'Imprimer A4'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: QuantisColors.royalBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
