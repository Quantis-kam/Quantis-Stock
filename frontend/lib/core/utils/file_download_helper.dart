import 'file_download_stub.dart'
    if (dart.library.io) 'file_download_io.dart'
    if (dart.library.html) 'file_download_web.dart' as platform;

class FileDownloadHelper {
  static Future<String?> download(List<int> bytes, String filename, {String mimeType = 'text/csv;charset=utf-8'}) async {
    return await platform.downloadFile(bytes, filename, mimeType);
  }
}
