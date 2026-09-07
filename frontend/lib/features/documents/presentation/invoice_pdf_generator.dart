import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/file_download_helper.dart';
import '../data/document_models.dart';

/// Générateur professionnel de factures et devis au format PDF haute résolution
class InvoicePdfGenerator {
  InvoicePdfGenerator._();

  static Future<Uint8List> generatePdfBytes(
    DocumentModel doc, {
    Map<String, dynamic>? entreprise,
    PdfColor primaryColor = const PdfColor.fromInt(0xFF1E3A8A),
    PdfColor accentColor = const PdfColor.fromInt(0xFFD4AF37),
  }) async {
    pw.Font fontBold;
    pw.Font fontRegular;
    try {
      fontBold = await PdfGoogleFonts.interBold();
      fontRegular = await PdfGoogleFonts.interRegular();
    } catch (_) {
      fontBold = pw.Font.helveticaBold();
      fontRegular = pw.Font.helvetica();
    }

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
    );

    final currency = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: ApiClient.entrepriseMonnaie,
      decimalDigits: 0,
    );

    final entNom = entreprise?['nom'] ?? ApiClient.entrepriseNom;
    final entNif = entreprise?['nif'] ?? ApiClient.entrepriseNif;
    final entRccm = entreprise?['rccm'] ?? 'RC-2026-B-001';
    final entTel = entreprise?['telephone'] ?? '+226 70 00 00 00';
    final entAdresse = entreprise?['adresse'] ?? 'Ouagadougou, Burkina Faso';

    final qrData =
        'QUANTIS|ENT:$entNom|NIF:$entNif|NUM:${doc.numero}|DATE:${doc.dateDocument ?? ""}|TTC:${doc.totalTtc.toStringAsFixed(0)} ${ApiClient.entrepriseMonnaie}';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // =================== EN-TÊTE ===================
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Entreprise
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        entNom,
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 20,
                          color: primaryColor,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('NIF : $entNif • RCCM : $entRccm',
                          style: pw.TextStyle(font: fontRegular, fontSize: 9, color: PdfColors.grey700)),
                      pw.Text('Tél : $entTel',
                          style: pw.TextStyle(font: fontRegular, fontSize: 9, color: PdfColors.grey700)),
                      pw.Text('Adresse : $entAdresse',
                          style: pw.TextStyle(font: fontRegular, fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
                  // Titre Document & Numéro
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: pw.BoxDecoration(
                      color: primaryColor,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          doc.typeLabel.toUpperCase(),
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 16,
                            color: PdfColors.white,
                            letterSpacing: 1,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'N° ${doc.numero}',
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 12,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 20),
              pw.Divider(color: PdfColors.grey300, thickness: 1),
              pw.SizedBox(height: 12),

              // =================== INFOS CLIENT & FACTURATION ===================
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // Cadre Client
                  pw.Container(
                    width: 250,
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      border: pw.Border.all(color: PdfColors.grey300),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('FACTURÉ À :',
                            style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.grey700)),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          doc.clientNom ?? 'Client Comptoir',
                          style: pw.TextStyle(font: fontBold, fontSize: 12, color: primaryColor),
                        ),
                        if (doc.clientTelephone != null) ...[
                          pw.SizedBox(height: 2),
                          pw.Text('Tél : ${doc.clientTelephone!}',
                              style: pw.TextStyle(font: fontRegular, fontSize: 9, color: PdfColors.grey800)),
                        ],
                      ],
                    ),
                  ),

                  // Dates & Statut
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      _rowInfoPdf('Date d\'émission :', doc.dateDocument ?? '', fontBold, fontRegular),
                      if (doc.dateEcheance != null)
                        _rowInfoPdf('Date d\'échéance :', doc.dateEcheance!, fontBold, fontRegular),
                      _rowInfoPdf('Statut :', doc.statutLabel, fontBold, fontRegular,
                          color: doc.statut == 'VALIDE' ? PdfColors.green700 : PdfColors.orange700),
                      _rowInfoPdf('Règlement :', doc.isPayeIntegral ? 'Soldé' : 'En attente', fontBold, fontRegular,
                          color: doc.isPayeIntegral ? PdfColors.green700 : PdfColors.red700),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 20),

              // =================== TABLEAU DES ARTICLES ===================
              pw.Table(
                border: pw.TableBorder(
                  horizontalInside: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                  bottom: pw.BorderSide(color: primaryColor, width: 1.5),
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(4),
                  1: const pw.FlexColumnWidth(1.2),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(2),
                },
                children: [
                  // En-tête tableau
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: primaryColor),
                    children: [
                      _headerCell('DÉSIGNATION', fontBold, align: pw.TextAlign.left),
                      _headerCell('QTÉ', fontBold, align: pw.TextAlign.center),
                      _headerCell('PRIX UNITAIRE', fontBold, align: pw.TextAlign.right),
                      _headerCell('TOTAL TTC', fontBold, align: pw.TextAlign.right),
                    ],
                  ),
                  // Lignes d'articles
                  ...doc.lignes.map(
                    (l) => pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.white),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                          child: pw.Text(l.designation,
                              style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.black)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                          child: pw.Text(l.quantite.toStringAsFixed(0),
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(font: fontRegular, fontSize: 10)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                          child: pw.Text(currency.format(l.prixUnitaire),
                              textAlign: pw.TextAlign.right,
                              style: pw.TextStyle(font: fontRegular, fontSize: 10)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                          child: pw.Text(currency.format(l.montantTtc),
                              textAlign: pw.TextAlign.right,
                              style: pw.TextStyle(font: fontBold, fontSize: 10, color: primaryColor)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 16),

              // =================== TOTAUX & QR CODE FISCAL ===================
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // QR Code Fiscal & Authenticité
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      border: pw.Border.all(color: PdfColors.grey300),
                    ),
                    child: pw.Row(
                      children: [
                        pw.BarcodeWidget(
                          barcode: pw.Barcode.qrCode(),
                          data: qrData,
                          width: 55,
                          height: 55,
                        ),
                        pw.SizedBox(width: 10),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('AUTHENTICITÉ FISCALE',
                                style: pw.TextStyle(font: fontBold, fontSize: 8, color: primaryColor)),
                            pw.Text('Scannable pour vérification',
                                style: pw.TextStyle(font: fontRegular, fontSize: 7, color: PdfColors.grey700)),
                            pw.Text('NIF : $entNif',
                                style: pw.TextStyle(font: fontRegular, fontSize: 7, color: PdfColors.grey700)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Bloc Financier Totaux
                  pw.Container(
                    width: 240,
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey50,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                      border: pw.Border.all(color: PdfColors.grey300),
                    ),
                    child: pw.Column(
                      children: [
                        _totalRowPdf('Total HT :', currency.format(doc.totalHt), fontRegular),
                        pw.SizedBox(height: 4),
                        _totalRowPdf('TVA (18%) :', currency.format(doc.totalTva), fontRegular),
                        pw.Divider(color: PdfColors.grey300, thickness: 0.5),
                        _totalRowPdf('Total TTC :', currency.format(doc.totalTtc), fontBold,
                            fontSize: 13, color: primaryColor),
                        if (doc.montantPaye > 0) ...[
                          pw.SizedBox(height: 4),
                          _totalRowPdf('Montant Réglé :', currency.format(doc.montantPaye), fontRegular,
                              color: PdfColors.green700),
                        ],
                        if (doc.soldeRestant > 0) ...[
                          pw.SizedBox(height: 4),
                          _totalRowPdf('Reste à Payer :', currency.format(doc.soldeRestant), fontBold,
                              color: PdfColors.red700),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              pw.Spacer(),

              // =================== PIED DE PAGE ===================
              pw.Divider(color: PdfColors.grey300, thickness: 0.5),
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text(
                  'Merci pour votre confiance ! • Document généré électroniquement par Quantis Stock',
                  style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey600),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _headerCell(String title, pw.Font font, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      child: pw.Text(
        title,
        textAlign: align,
        style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.white),
      ),
    );
  }

  static pw.Widget _rowInfoPdf(String label, String val, pw.Font fontBold, pw.Font fontRegular, {PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(label, style: pw.TextStyle(font: fontRegular, fontSize: 9, color: PdfColors.grey700)),
          pw.SizedBox(width: 4),
          pw.Text(val, style: pw.TextStyle(font: fontBold, fontSize: 9, color: color ?? PdfColors.black)),
        ],
      ),
    );
  }

  static pw.Widget _totalRowPdf(String label, String val, pw.Font font,
      {double fontSize = 10, PdfColor? color}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(font: font, fontSize: fontSize, color: color ?? PdfColors.black)),
        pw.Text(val, style: pw.TextStyle(font: font, fontSize: fontSize, color: color ?? PdfColors.black)),
      ],
    );
  }

  /// Imprimer le document avec la boîte d'impression native
  static Future<void> printDocument(
    DocumentModel doc, {
    Map<String, dynamic>? entreprise,
  }) async {
    final pdfBytes = await generatePdfBytes(doc, entreprise: entreprise);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: '${doc.typeLabel}_${doc.numero}.pdf',
    );
  }

  /// Télécharger directement le fichier PDF sur l'ordinateur / mobile
  static Future<void> downloadPdf(
    DocumentModel doc, {
    Map<String, dynamic>? entreprise,
  }) async {
    final pdfBytes = await generatePdfBytes(doc, entreprise: entreprise);
    final filename = '${doc.typeLabel}_${doc.numero}.pdf';
    await FileDownloadHelper.download(pdfBytes, filename, mimeType: 'application/pdf');
  }

  /// Partager le document PDF via la feuille de partage native (WhatsApp, Email, etc.)
  static Future<void> sharePdf(
    DocumentModel doc, {
    Map<String, dynamic>? entreprise,
  }) async {
    final pdfBytes = await generatePdfBytes(doc, entreprise: entreprise);
    final filename = '${doc.typeLabel}_${doc.numero}.pdf';
    await Printing.sharePdf(bytes: pdfBytes, filename: filename);
  }

  /// Générer les octets d'un ticket de caisse thermique 80mm
  static Future<Uint8List> generateThermalTicketBytes(
    Map<String, dynamic> saleData,
  ) async {
    pw.Font fontBold;
    pw.Font fontRegular;
    try {
      fontBold = await PdfGoogleFonts.interBold();
      fontRegular = await PdfGoogleFonts.interRegular();
    } catch (_) {
      fontBold = pw.Font.helveticaBold();
      fontRegular = pw.Font.helvetica();
    }

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
    );

    final doc = saleData['document'] as Map<String, dynamic>? ?? {};
    final lignes = (doc['lignes'] as List<dynamic>?) ?? [];
    final paiement = saleData['paiement'] as Map<String, dynamic>?;

    final String entNom = saleData['entrepriseNom'] ?? ApiClient.entrepriseNom;
    final String entNif = saleData['entrepriseNif'] ?? '';
    final String entRccm = saleData['entrepriseRccm'] ?? '';
    final String entTel = saleData['entrepriseTelephone'] ?? '';
    final String entAdresse = saleData['entrepriseAdresse'] ?? '';
    final String monnaie = saleData['entrepriseMonnaie'] ?? ApiClient.entrepriseMonnaie;

    final String numeroTicket = doc['numero'] ?? 'REC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final String dateDoc = doc['dateDocument'] ?? DateTime.now().toString().substring(0, 10);
    final String caissier = saleData['caissierNom'] ?? 'Caissier';
    final String client = saleData['clientNom'] ?? 'Client Comptoir';

    final num totalTtc = saleData['montantTotal'] ?? doc['totalTtc'] ?? 0;
    final num montantPaye = saleData['montantPaye'] ?? 0;
    final num monnaieRendue = saleData['monnaieRendue'] ?? 0;
    final num soldeRestant = saleData['soldeRestant'] ?? 0;
    final String moyenPaiement = paiement?['moyen'] ?? 'ESPECES';

    final currency = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: monnaie,
      decimalDigits: 0,
    );

    final qrData = 'QUANTIS|TICKET:$numeroTicket|ENT:$entNom|DATE:$dateDoc|TOTAL:${totalTtc.toStringAsFixed(0)} $monnaie';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              // Nom entreprise
              pw.Text(
                entNom.toUpperCase(),
                style: pw.TextStyle(font: fontBold, fontSize: 13),
                textAlign: pw.TextAlign.center,
              ),
              if (entAdresse.isNotEmpty)
                pw.Text(entAdresse, style: pw.TextStyle(font: fontRegular, fontSize: 8), textAlign: pw.TextAlign.center),
              if (entTel.isNotEmpty)
                pw.Text('Tél: $entTel', style: pw.TextStyle(font: fontRegular, fontSize: 8)),
              if (entNif.isNotEmpty || entRccm.isNotEmpty)
                pw.Text('NIF: $entNif | RCCM: $entRccm', style: pw.TextStyle(font: fontRegular, fontSize: 7)),

              pw.SizedBox(height: 6),
              pw.Divider(thickness: 0.8, color: PdfColors.grey600),
              pw.SizedBox(height: 4),

              // Info Ticket & Date
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Ticket: $numeroTicket', style: pw.TextStyle(font: fontBold, fontSize: 8)),
                  pw.Text(dateDoc, style: pw.TextStyle(font: fontRegular, fontSize: 8)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Client: $client', style: pw.TextStyle(font: fontRegular, fontSize: 8)),
                  pw.Text('Caisse: $caissier', style: pw.TextStyle(font: fontRegular, fontSize: 8)),
                ],
              ),

              pw.SizedBox(height: 6),
              pw.Divider(thickness: 0.8, color: PdfColors.grey600),
              pw.SizedBox(height: 4),

              // Tableau Articles
              pw.Column(
                children: lignes.map((l) {
                  final desig = l['designation'] ?? 'Article';
                  final num qte = l['quantite'] ?? 1;
                  final num pu = l['prixUnitaire'] ?? 0;
                  final num tot = l['totalTtc'] ?? (qte * pu);

                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 4),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(desig, style: pw.TextStyle(font: fontBold, fontSize: 8)),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('  ${qte.toStringAsFixed(0)} x ${currency.format(pu)}',
                                style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey800)),
                            pw.Text(currency.format(tot), style: pw.TextStyle(font: fontBold, fontSize: 8)),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),

              pw.SizedBox(height: 4),
              pw.Divider(thickness: 0.8, color: PdfColors.grey600),
              pw.SizedBox(height: 4),

              // Totaux
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL TTC', style: pw.TextStyle(font: fontBold, fontSize: 11)),
                  pw.Text(currency.format(totalTtc), style: pw.TextStyle(font: fontBold, fontSize: 12)),
                ],
              ),
              if (montantPaye > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Montant Payé ($moyenPaiement)', style: pw.TextStyle(font: fontRegular, fontSize: 8)),
                    pw.Text(currency.format(montantPaye), style: pw.TextStyle(font: fontRegular, fontSize: 8)),
                  ],
                ),
              if (monnaieRendue > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Monnaie Rendue', style: pw.TextStyle(font: fontRegular, fontSize: 8)),
                    pw.Text(currency.format(monnaieRendue), style: pw.TextStyle(font: fontRegular, fontSize: 8)),
                  ],
                ),
              if (soldeRestant > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Reste à Payer', style: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColors.red700)),
                    pw.Text(currency.format(soldeRestant), style: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColors.red700)),
                  ],
                ),

              pw.SizedBox(height: 8),
              pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: qrData,
                width: 50,
                height: 50,
              ),
              pw.SizedBox(height: 4),
              pw.Text('Merci pour votre confiance !', style: pw.TextStyle(font: fontRegular, fontSize: 8, fontStyle: pw.FontStyle.italic)),
              pw.Text('Quantis Stock', style: pw.TextStyle(font: fontRegular, fontSize: 6, color: PdfColors.grey600)),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Imprimer le ticket de caisse thermique 80mm
  static Future<void> printThermalTicket(Map<String, dynamic> saleData) async {
    final pdfBytes = await generateThermalTicketBytes(saleData);
    final doc = saleData['document'] as Map<String, dynamic>? ?? {};
    final String numeroTicket = doc['numero'] ?? 'ticket';
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Ticket_$numeroTicket.pdf',
      format: PdfPageFormat.roll80,
    );
  }

  /// Partager le ticket de caisse thermique via WhatsApp / système
  static Future<void> shareThermalTicket(Map<String, dynamic> saleData) async {
    final pdfBytes = await generateThermalTicketBytes(saleData);
    final doc = saleData['document'] as Map<String, dynamic>? ?? {};
    final String numeroTicket = doc['numero'] ?? 'ticket';
    await Printing.sharePdf(bytes: pdfBytes, filename: 'Ticket_$numeroTicket.pdf');
  }

  /// Télécharger le ticket thermique sur l'appareil
  static Future<void> downloadThermalTicket(Map<String, dynamic> saleData) async {
    final pdfBytes = await generateThermalTicketBytes(saleData);
    final doc = saleData['document'] as Map<String, dynamic>? ?? {};
    final String numeroTicket = doc['numero'] ?? 'ticket';
    await FileDownloadHelper.download(pdfBytes, 'Ticket_$numeroTicket.pdf', mimeType: 'application/pdf');
  }
}
