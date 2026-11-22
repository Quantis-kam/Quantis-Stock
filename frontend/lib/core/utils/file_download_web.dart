// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

Future<String?> downloadFile(List<int> bytes, String filename, String mimeType) async {
  try {
    final uint8Bytes = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    final blob = html.Blob([uint8Bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);

    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..style.display = 'none';

    html.document.body?.children.add(anchor);
    anchor.click();
    anchor.remove();

    // Révocation différée pour laisser le temps à Chrome d'enregistrer le fichier
    Future.delayed(const Duration(seconds: 30), () {
      try {
        html.Url.revokeObjectUrl(url);
      } catch (_) {}
    });

    return filename;
  } catch (e) {
    return null;
  }
}
