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
    final initialPhone = WhatsappShareHelper.isDummyPhone(widget.document.clientTelephone)
        ? ''
        : (widget.document.clientTelephone ?? '');
    _phoneCtrl = TextEditingController(text: initialPhone);
    _phoneCtrl.addListener(() {
      if (mounted) setState(() {});
    });
    _messageCtrl = TextEditingController(text: WhatsappShareHelper.generateMessage(widget.document));
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendWhatsApp() async {
    final phone = _phoneCtrl.text.trim();
    final isSpecificPhone = phone.isNotEmpty && !WhatsappShareHelper.isDummyPhone(phone);
    await WhatsappShareHelper.shareViaWhatsApp(
      widget.document,
      customPhone: isSpecificPhone ? phone : null,
    );
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isSpecificPhone
                      ? 'Ouverture de WhatsApp avec $phone...'
                      : 'WhatsApp ouvert ! Choisissez le contact ou la discussion à qui envoyer.',
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF25D366),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _sharePdfDirect() async {
    setState(() => _isGeneratingPdf = true);
    try {
      await InvoicePdfGenerator.sharePdf(widget.document, entreprise: widget.entreprise);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Partage de la facture PDF lancé !'),
            backgroundColor: Color(0xFF25D366),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur partage PDF: $e'), backgroundColor: QuantisColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  Future<void> _telechargerPdf() async {
    setState(() => _isGeneratingPdf = true);
    try {
      await InvoicePdfGenerator.downloadPdf(widget.document, entreprise: widget.entreprise);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Facture PDF enregistrée avec succès sur l\'appareil !'),
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
      if (mounted) setState(() => _isGeneratingPdf = false);
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
    final isMobile = MediaQuery.of(context).size.width < 600;
    final screenWidth = MediaQuery.of(context).size.width;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 40,
        vertical: 16,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isMobile ? screenWidth * 0.95 : 680),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
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
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 15 : 16),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Envoyez le message et la facture PDF sur WhatsApp',
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

              // Boîte d'astuce WhatsApp & Choix du contact
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.mark_chat_unread_outlined, color: Color(0xFF25D366), size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Laissez le champ numéro vide pour ouvrir WhatsApp et choisir le contact ou le groupe directement dans l\'application.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF1B5E20), height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Champ Téléphone avec bouton Effacer
              TextField(
                controller: _phoneCtrl,
                decoration: InputDecoration(
                  labelText: 'Numéro WhatsApp du destinataire (Optionnel)',
                  hintText: 'Ex: +226 70 12 34 56',
                  prefixIcon: const Icon(Icons.phone_outlined, color: Color(0xFF25D366)),
                  suffixIcon: _phoneCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          tooltip: 'Effacer le numéro pour choisir dans WhatsApp',
                          onPressed: () => _phoneCtrl.clear(),
                        )
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  helperText: 'Laissez vide pour choisir le contact directement dans WhatsApp',
                  helperMaxLines: 2,
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

              // Actions (Totalement responsive avec Wrap pour éliminer tout débordement)
              if (isMobile)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _sendWhatsApp,
                      icon: const Icon(Icons.chat, size: 18),
                      label: const Text('Partager sur WhatsApp'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _isGeneratingPdf ? null : _sharePdfDirect,
                      icon: _isGeneratingPdf
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.share, size: 18),
                      label: const Text('Partager le fichier PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: QuantisColors.royalBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isGeneratingPdf ? null : _telechargerPdf,
                            icon: const Icon(Icons.download, size: 16),
                            label: const Text('Télécharger PDF'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _copy,
                            icon: const Icon(Icons.copy, size: 16),
                            label: const Text('Copier'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              else
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _copy,
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copier le texte'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _isGeneratingPdf ? null : _telechargerPdf,
                          icon: _isGeneratingPdf
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.download, size: 16),
                          label: const Text('Télécharger PDF'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _sendWhatsApp,
                          icon: const Icon(Icons.chat, size: 18),
                          label: const Text('Partager sur WhatsApp'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

