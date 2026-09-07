import 'package:intl/intl.dart';
import 'whatsapp_share_stub.dart'
    if (dart.library.io) 'whatsapp_share_io.dart'
    if (dart.library.html) 'whatsapp_share_web.dart' as platform;
import '../network/api_client.dart';
import '../../features/documents/data/document_models.dart';
import '../../features/documents/presentation/invoice_pdf_generator.dart';

/// Helper pour formater et partager des factures, devis et reçus via WhatsApp / SMS
class WhatsappShareHelper {
  WhatsappShareHelper._();

  static String generateMessage(DocumentModel doc) {
    final currency = NumberFormat.currency(locale: 'fr_FR', symbol: ApiClient.entrepriseMonnaie, decimalDigits: 0);
    final entreprise = ApiClient.entrepriseNom;
    final typeDoc = doc.typeLabel;

    final clientNom = doc.clientNom != null && doc.clientNom!.isNotEmpty
        ? doc.clientNom!
        : 'Cher(e) Client(e)';

    final totalTtc = currency.format(doc.totalTtc);
    final totalPaye = currency.format(doc.montantPaye);
    final soldeRestant = currency.format(doc.soldeRestant);

    final sb = StringBuffer();
    sb.writeln('Bonjour *$clientNom*,');
    sb.writeln();
    sb.writeln('Voici les détails de votre *$typeDoc N° ${doc.numero}* émis par *$entreprise* :');
    sb.writeln('📅 *Date :* ${doc.dateDocument ?? ""}');
    sb.writeln('💰 *Montant Total TTC :* $totalTtc');
    if (doc.montantPaye > 0) {
      sb.writeln('✅ *Montant Réglé :* $totalPaye');
    }
    if (doc.soldeRestant > 0) {
      sb.writeln('⏳ *Reste à Payer :* $soldeRestant');
    } else {
      sb.writeln('🎉 *Statut :* Entièrement payé');
    }

    if (doc.lignes.isNotEmpty) {
      sb.writeln();
      sb.writeln('📝 *Articles :*');
      for (final l in doc.lignes) {
        sb.writeln('• ${l.quantite.toStringAsFixed(0)}x ${l.designation} (${currency.format(l.montantTtc)})');
      }
    }

    sb.writeln();
    sb.writeln('Nous vous remercions pour votre confiance !');
    sb.writeln('_$entreprise' '_');

    return sb.toString();
  }

  /// Ouvre directement WhatsApp avec le message commercial pré-rempli
  static Future<bool> shareViaWhatsApp(DocumentModel doc, {String? customPhone}) async {
    final message = generateMessage(doc);

    String phone = customPhone ?? doc.clientTelephone ?? '';
    // Nettoyer les espaces, tirets et caractères non numériques (sauf +)
    phone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (phone.startsWith('00')) {
      phone = '+${phone.substring(2)}';
    }

    return await platform.openWhatsAppDirect(phone: phone, message: message);
  }

  /// Partage direct du fichier PDF généré vers WhatsApp / feuille de partage système
  static Future<void> sharePdfDocument(DocumentModel doc, {Map<String, dynamic>? entreprise}) async {
    await InvoicePdfGenerator.sharePdf(doc, entreprise: entreprise);
  }
}
