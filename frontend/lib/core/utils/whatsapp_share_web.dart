// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<bool> openWhatsAppDirect({String? phone, required String message}) async {
  final cleanPhone = (phone ?? '').replaceAll(RegExp(r'[^\d]'), '');
  final encodedMessage = Uri.encodeComponent(message);
  final url = cleanPhone.isNotEmpty
      ? 'https://wa.me/$cleanPhone?text=$encodedMessage'
      : 'https://api.whatsapp.com/send?text=$encodedMessage';
  html.window.open(url, '_blank');
  return true;
}

void openExternalUrl(String url) {
  html.window.open(url, '_blank');
}
