import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

/// Implémentation native (Android / iOS / Desktop) de sauvegarde et téléchargement de fichiers
Future<String?> downloadFile(List<int> bytes, String filename, String mimeType) async {
  try {
    Directory? targetDir;

    if (Platform.isAndroid) {
      // 1. Sur Android, tenter d'abord le dossier public "Download"
      final publicDownload = Directory('/storage/emulated/0/Download');
      if (await publicDownload.exists()) {
        targetDir = publicDownload;
      } else {
        // 2. Fallback sur le stockage externe d'application
        targetDir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
      }
    } else if (Platform.isIOS) {
      targetDir = await getApplicationDocumentsDirectory();
    } else {
      // Desktop (Linux, macOS, Windows)
      targetDir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    }

    final filePath = '${targetDir.path}/$filename';
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);

    // Si c'est un PDF sur mobile, on propose le dialogue natif de partage/visualisation
    if (Platform.isAndroid || Platform.isIOS) {
      if (mimeType.contains('pdf') || filename.toLowerCase().endsWith('.pdf')) {
        await Printing.sharePdf(
          bytes: Uint8List.fromList(bytes),
          filename: filename,
        );
      }
    }

    return filePath;
  } catch (e) {
    // Si l'accès au dossier public échoue (Android scoped storage), utiliser le fallback Printing
    if (mimeType.contains('pdf') || filename.toLowerCase().endsWith('.pdf')) {
      await Printing.sharePdf(
        bytes: Uint8List.fromList(bytes),
        filename: filename,
      );
    }
    return null;
  }
}
