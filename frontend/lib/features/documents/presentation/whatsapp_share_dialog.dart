import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/quantis_theme.dart';
import '../../../core/utils/whatsapp_share_helper.dart';
import '../data/document_models.dart';
import 'invoice_pdf_generator.dart';

/// Modal de confirmation, personnalisation et envoi PDF / WhatsApp
class WhatsappShareDialog extends StatefulWidget {
  final DocumentModel document;
  final Map<String, dynamic>? entreprise;

  const WhatsappShareDialog({super.key, required this.document, this.entreprise});

  static Future<void> show(BuildContext context, DocumentModel document, {Map<String, dynamic>? entreprise}) {
    return showDialog(
      context: context,
      builder: (_) => WhatsappShareDialog(document: document, entreprise: entreprise),
    );
  }

  @override
  State<WhatsappShareDialog> createState() => _WhatsappShareDialogState();
}

class _WhatsappShareDialogState extends State<WhatsappShareDialog> {
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _messageCtrl;
  bool _isGeneratingPdf = false;

  @override
  void initState() {
    super.initState();
    _phoneCtrl = TextEditingController(text: widget.document.clientTelephone ?? '');
    _messageCtrl = TextEditingController(text: WhatsappShareHelper.generateMessage(widget.document));
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  void _sendTextOnly() {
    final phone = _phoneCtrl.text.trim();
    WhatsappShareHelper.shareViaWhatsApp(widget.document, customPhone: phone.isNotEmpty ? phone : null);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ouverture de WhatsApp en cours...'),
        backgroundColor: Color(0xFF25D366),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _downloadPdfAndOpenWhatsApp() async {
    setState(() => _isGeneratingPdf = true);
    try {
      // 1. Télécharger le PDF de la facture sur la machine / téléphone
      await InvoicePdfGenerator.downloadPdf(widget.document, entreprise: widget.entreprise);

      // 2. Ouvrir WhatsApp avec la conversation du client
      final phone = _phoneCtrl.text.trim();
      WhatsappShareHelper.shareViaWhatsApp(widget.document, customPhone: phone.isNotEmpty ? phone : null);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.picture_as_pdf, color: Colors.white),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Facture PDF téléchargée ! Glissez-la dans la fenêtre WhatsApp pour l\'envoyer au client.',
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF25D366),
            duration: const Duration(seconds: 6),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur génération PDF: $e'), backgroundColor: QuantisColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
      }
    }
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: _messageCtrl.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Message copié dans le presse-papiers !'),
        backgroundColor: QuantisColors.royalBlue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.chat_outlined, color: Color(0xFF25D366), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Partager ${widget.document.typeLabel} N° ${widget.document.numero}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Envoyez le message et la facture PDF sur WhatsApp au client',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  tooltip: 'Fermer',
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            // Boîte d'astuce PDF
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: QuantisColors.royalBlue, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pour envoyer la facture en PDF : cliquez sur « Télécharger PDF & WhatsApp », le fichier PDF est prêt et il vous suffit de le glisser dans WhatsApp.',
                      style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Champ Téléphone
            TextField(
              controller: _phoneCtrl,
              decoration: InputDecoration(
                labelText: 'Numéro WhatsApp du destinataire',
                hintText: 'Ex: +22670000000 ou 70000000',
                prefixIcon: const Icon(Icons.phone_outlined, color: Color(0xFF25D366)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                helperText: 'Laissez vide pour choisir le contact directement dans WhatsApp',
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 14),

            // Aperçu du message
            const Text('Aperçu du texte commercial :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(maxHeight: 140),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFEAE2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SingleChildScrollView(
                child: Text(
                  _messageCtrl.text,
                  style: const TextStyle(fontSize: 12, height: 1.4, color: Colors.black87),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  onPressed: _copy,
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copier'),
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _sendTextOnly,
                      icon: const Icon(Icons.send_outlined, size: 16, color: Color(0xFF25D366)),
                      label: const Text('Texte Seul'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: _isGeneratingPdf ? null : _downloadPdfAndOpenWhatsApp,
                      icon: _isGeneratingPdf
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.picture_as_pdf, size: 16),
                      label: const Text('Télécharger PDF & WhatsApp'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
