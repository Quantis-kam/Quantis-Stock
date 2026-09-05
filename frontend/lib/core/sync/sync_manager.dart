import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../network/api_client.dart';
import 'sync_queue.dart';

/// Service de synchronisation — surveille la connectivité et envoie
/// les actions en attente dès que le réseau revient.
class SyncManager extends ChangeNotifier {
  static final SyncManager instance = SyncManager._();
  SyncManager._();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription? _subscription;

  bool _isOnline = true;
  bool _isSyncing = false;
  int _pendingCount = 0;

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  int get pendingCount => _pendingCount;

  String get statusLabel {
    if (_isSyncing) return 'Synchronisation...';
    if (!_isOnline) return 'Hors-ligne';
    if (_pendingCount > 0) return '$_pendingCount en attente';
    return 'Synchronisé';
  }

  /// Démarrer l'écoute de connectivité.
  void start() {
    try {
      _subscription = _connectivity.onConnectivityChanged.listen((results) {
        final online = results.any((r) => r != ConnectivityResult.none);
        if (online != _isOnline) {
          _isOnline = online;
          notifyListeners();
          if (online) syncNow();
        }
      });
      _refreshPendingCount();
    } catch (e) {
      debugPrint('SyncManager start notice: $e');
    }
  }

  /// Arrêter l'écoute.
  void stop() {
    _subscription?.cancel();
  }

  /// Forcer une synchronisation maintenant.
  Future<void> syncNow() async {
    if (_isSyncing || !_isOnline || !ApiClient.isAuthenticated) return;

    final pending = await SyncQueue.getPending();
    if (pending.isEmpty) {
      _pendingCount = 0;
      notifyListeners();
      return;
    }

    _isSyncing = true;
    notifyListeners();

    try {
      final response = await ApiClient.instance.post('/sync', data: {
        'actions': pending,
      });

      final results = (response.data['data']['results'] as List?) ?? [];
      final syncedUuids = <String>[];

      for (final r in results) {
        final status = r['status'] as String?;
        if (status == 'OK' || status == 'SKIPPED') {
          syncedUuids.add(r['uuid'] as String);
        }
      }

      await SyncQueue.markSynced(syncedUuids);
    } on DioException catch (_) {
      // Réseau perdu pendant la sync — on réessaiera
    } finally {
      _isSyncing = false;
      await _refreshPendingCount();
      notifyListeners();
    }
  }

  Future<void> _refreshPendingCount() async {
    _pendingCount = await SyncQueue.pendingCount();
    notifyListeners();
  }
}
