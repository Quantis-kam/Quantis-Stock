import 'dart:convert';
import 'dart:typed_data';
import 'file_download_stub.dart'
    if (dart.library.io) 'file_download_io.dart'
    if (dart.library.html) 'file_download_web.dart' as platform;

class FileDownloadHelper {
  /// Télécharge un fichier sous toutes les plateformes (Web, Mobile, Desktop).
  /// Accepte dynamiquement `List<int>`, `Uint8List` ou `String` (ex: CSV texte).
  static Future<String?> download(dynamic data, String filename, {String mimeType = 'text/csv;charset=utf-8'}) async {
    List<int> bytes;
    if (data is Uint8List) {
      bytes = data;
    } else if (data is List<int>) {
      bytes = data;
    } else if (data is String) {
      bytes = utf8.encode(data);
    } else if (data != null) {
      bytes = utf8.encode(data.toString());
    } else {
      bytes = [];
    }
    return await platform.downloadFile(bytes, filename, mimeType);
  }
}
