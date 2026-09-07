import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

/// Lancement optimisé et direct de WhatsApp sur Android et iOS
Future<bool> openWhatsAppDirect({String? phone, required String message}) async {
  final cleanPhone = (phone ?? '').replaceAll(RegExp(r'[^\d]'), '');
  final encodedMessage = Uri.encodeComponent(message);

  // 1. Tenter d'abord le schéma natif WhatsApp (whatsapp://send) sur Android / iOS
  if (Platform.isAndroid || Platform.isIOS) {
    final String nativeScheme = cleanPhone.isNotEmpty
        ? 'whatsapp://send?phone=$cleanPhone&text=$encodedMessage'
        : 'whatsapp://send?text=$encodedMessage';
    final nativeUri = Uri.parse(nativeScheme);

    try {
      final launched = await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
      if (launched) return true;
    } catch (_) {}
  }

  // 2. Tenter via le lien universel https://wa.me/
  final String waMeUrl = cleanPhone.isNotEmpty
      ? 'https://wa.me/$cleanPhone?text=$encodedMessage'
      : 'https://api.whatsapp.com/send?text=$encodedMessage';
  final waMeUri = Uri.parse(waMeUrl);

  try {
    final launched = await launchUrl(waMeUri, mode: LaunchMode.externalApplication);
    if (launched) return true;
  } catch (_) {}

  // 3. Fallback plateforme standard (navigateur ou application par défaut)
  try {
    return await launchUrl(waMeUri, mode: LaunchMode.platformDefault);
  } catch (_) {
    return false;
  }
}

/// Ouvre une URL externe avec support et repli sécurisé sur Android
Future<void> openExternalUrl(String url) async {
  final uri = Uri.parse(url);
  try {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  } catch (_) {
    try {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (_) {}
  }
}
