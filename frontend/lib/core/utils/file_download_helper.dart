import 'file_download_stub.dart'
    if (dart.library.html) 'file_download_web.dart' as platform;

class FileDownloadHelper {
  static void download(List<int> bytes, String filename, {String mimeType = 'text/csv;charset=utf-8'}) {
    platform.downloadFile(bytes, filename, mimeType);
  }
}
