import 'package:flutter/material.dart';
import '../../../core/theme/quantis_theme.dart';
import '../data/user_service.dart';

class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  final _userService = UserService();

  List<AuditLogModel> _logs = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() { _loading = true; _error = null; });
    try {
      final logsList = await _userService.getAuditLogs();
      setState(() {
        _logs = logsList;
      });
    } catch (e) {
      setState(() { _error = 'Impossible de charger les logs d\'audit : $e'; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  Color _getActionColor(String action) {
    switch (action.toUpperCase()) {
      case 'CREATE':
        return Colors.green.shade700;
      case 'UPDATE':
        return Colors.blue.shade700;
      case 'DELETE':
        return Colors.red.shade700;
      case 'LOGIN':
        return Colors.purple.shade700;
      case 'LOGOUT':
        return Colors.amber.shade800;
      default:
        return QuantisColors.textMuted;
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal d\'Audit', style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
            tooltip: 'Actualiser',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading && _logs.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: const TextStyle(color: QuantisColors.error)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadLogs, child: const Text('Réessayer')),
                    ],
                  ),
                )
              : _logs.isEmpty
                  ? const Center(child: Text('Aucun log d\'audit trouvé.'))
                  : Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: QuantisColors.border),
                        ),
                        child: ListView.separated(
                          itemCount: _logs.length,
                          separatorBuilder: (context, index) => const Divider(height: 1, color: QuantisColors.border),
                          itemBuilder: (context, index) {
                            final logItem = _logs[index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              leading: Container(
                                width: 80,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _getActionColor(logItem.action).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    logItem.action,
                                    style: TextStyle(
                                      color: _getActionColor(logItem.action),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    '${logItem.entite} #${logItem.entiteId ?? "N/A"}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _formatDate(logItem.createdAt),
                                    style: TextStyle(color: QuantisColors.textMuted, fontSize: 12),
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (logItem.details != null && logItem.details!.isNotEmpty) ...[
                                      Text(
                                        'Détails : ${logItem.details}',
                                        style: TextStyle(color: Colors.grey.shade800, fontSize: 13, fontFamily: 'monospace'),
                                      ),
                                      const SizedBox(height: 4),
                                    ],
                                    Text(
                                      'Par : ${logItem.userEmail}  |  IP : ${logItem.ipAddress ?? "Locale"}',
                                      style: TextStyle(color: QuantisColors.textMuted, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
    );
  }
}
