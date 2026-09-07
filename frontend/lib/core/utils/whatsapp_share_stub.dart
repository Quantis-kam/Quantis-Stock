import 'package:url_launcher/url_launcher.dart';

Future<bool> openWhatsAppDirect({String? phone, required String message}) async {
  final cleanPhone = (phone ?? '').replaceAll(RegExp(r'[^\d]'), '');
  final encodedMessage = Uri.encodeComponent(message);
  final url = cleanPhone.isNotEmpty
      ? 'https://wa.me/$cleanPhone?text=$encodedMessage'
      : 'https://api.whatsapp.com/send?text=$encodedMessage';
  final uri = Uri.parse(url);
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

Future<void> openExternalUrl(String url) async {
  final uri = Uri.parse(url);
  try {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  } catch (_) {}
}
