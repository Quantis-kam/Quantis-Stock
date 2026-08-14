import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// File d'attente locale pour les actions hors-ligne.
/// Stocke les actions en JSON sur le disque, survit aux redémarrages.
class SyncQueue {
  static const _fileName = 'sync_queue.json';
  static final _uuid = Uuid();

  /// Ajouter une action à la file.
  static Future<void> enqueue({
    required String type,
    required Map<String, dynamic> data,
  }) async {
    final actions = await getAll();
    actions.add({
      'uuid': _uuid.v4(),
      'type': type,
      'data': data,
      'clientTimestamp': DateTime.now().toIso8601String(),
      'status': 'PENDING',
    });
    await _save(actions);
  }

  /// Récupérer toutes les actions en attente.
  static Future<List<Map<String, dynamic>>> getPending() async {
    final all = await getAll();
    return all.where((a) => a['status'] == 'PENDING').toList();
  }

  /// Récupérer toutes les actions.
  static Future<List<Map<String, dynamic>>> getAll() async {
    final file = await _getFile();
    if (!await file.exists()) return [];
    final content = await file.readAsString();
    if (content.isEmpty) return [];
    final list = jsonDecode(content) as List;
    return list.cast<Map<String, dynamic>>();
  }

  /// Marquer des actions comme synchronisées et les retirer.
  static Future<void> markSynced(List<String> uuids) async {
    final actions = await getAll();
    actions.removeWhere((a) => uuids.contains(a['uuid']));
    await _save(actions);
  }

  /// Nombre d'actions en attente.
  static Future<int> pendingCount() async {
    return (await getPending()).length;
  }

  /// Vider la file.
  static Future<void> clear() async {
    await _save([]);
  }

  static Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  static Future<void> _save(List<Map<String, dynamic>> actions) async {
    final file = await _getFile();
    await file.writeAsString(jsonEncode(actions));
  }
}
