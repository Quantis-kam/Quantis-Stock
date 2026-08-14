import 'package:flutter/material.dart';
import '../sync/sync_manager.dart';
import '../theme/quantis_theme.dart';

/// Indicateur visuel de synchronisation — affiche l'état en temps réel.
class SyncIndicator extends StatelessWidget {
  const SyncIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SyncManager.instance,
      builder: (context, _) {
        final mgr = SyncManager.instance;

        Color color;
        IconData icon;
        if (mgr.isSyncing) {
          color = QuantisColors.info;
          icon = Icons.sync;
        } else if (!mgr.isOnline) {
          color = QuantisColors.warning;
          icon = Icons.cloud_off;
        } else if (mgr.pendingCount > 0) {
          color = QuantisColors.warning;
          icon = Icons.cloud_upload;
        } else {
          color = QuantisColors.success;
          icon = Icons.cloud_done;
        }

        return Tooltip(
          message: mgr.statusLabel,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                mgr.isSyncing
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: color),
                      )
                    : Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Text(
                  mgr.statusLabel,
                  style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
