// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

bool _isDummyPhone(String digits) {
  if (digits.isEmpty) return true;
  if (digits == '22670000000' ||
      digits == '70000000' ||
      digits == '00000000' ||
      digits == '22600000000' ||
      digits == '12345678' ||
      digits == '22612345678') {
    return true;
  }
  if (RegExp(r'^(\d)\1+$').hasMatch(digits)) return true;
  return false;
}

Future<bool> openWhatsAppDirect({String? phone, required String message}) async {
  var cleanPhone = (phone ?? '').replaceAll(RegExp(r'[^\d]'), '');
  if (_isDummyPhone(cleanPhone)) {
    cleanPhone = '';
  }
  final encodedMessage = Uri.encodeComponent(message);
  final url = cleanPhone.isNotEmpty
      ? 'https://api.whatsapp.com/send?phone=$cleanPhone&text=$encodedMessage'
      : 'https://api.whatsapp.com/send?text=$encodedMessage';

  try {
    html.window.open(url, '_blank');
    return true;
  } catch (_) {
    try {
      final anchor = html.AnchorElement(href: url)
        ..target = '_blank'
        ..rel = 'noopener noreferrer'
        ..style.display = 'none';

      html.document.body?.children.add(anchor);
      anchor.click();
      anchor.remove();
      return true;
    } catch (_) {
      return false;
    }
  }
}

void openExternalUrl(String url) {
  try {
    html.window.open(url, '_blank');
  } catch (_) {
    final anchor = html.AnchorElement(href: url)
      ..target = '_blank'
      ..rel = 'noopener noreferrer'
      ..style.display = 'none';
    html.document.body?.children.add(anchor);
    anchor.click();
    anchor.remove();
  }
}

