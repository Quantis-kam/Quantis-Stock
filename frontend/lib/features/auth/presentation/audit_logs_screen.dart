import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/quantis_theme.dart';
import '../data/user_service.dart';

class AuditLogsScreen extends StatefulWidget {
  final bool embedded;
  final int? entrepriseId;
  const AuditLogsScreen({super.key, this.embedded = false, this.entrepriseId});

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
      final logsList = await _userService.getAuditLogs(entrepriseId: widget.entrepriseId);
      setState(() {
        _logs = logsList;
      });
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 403) {
        setState(() { _error = 'Accès refusé : vous ne disposez pas des permissions requises pour consulter les logs d\'audit.'; });
      } else {
        setState(() { _error = 'Impossible de charger les logs d\'audit : $e'; });
      }
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
    final isMobile = MediaQuery.of(context).size.width < 700;

    final content = _loading && _logs.isEmpty
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
                    padding: EdgeInsets.all(isMobile ? 12.0 : 24.0),
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
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 12 : 24,
                              vertical: isMobile ? 8 : 12,
                            ),
                            leading: Container(
                              width: isMobile ? 65 : 80,
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
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
                                    fontSize: isMobile ? 11 : 12,
                                  ),
                                ),
                              ),
                            ),
                            title: isMobile
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${logItem.entite} #${logItem.entiteId ?? "N/A"}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _formatDate(logItem.createdAt),
                                        style: TextStyle(color: QuantisColors.textMuted, fontSize: 11),
                                      ),
                                    ],
                                  )
                                : Row(
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
                                      style: TextStyle(
                                        color: Colors.grey.shade800,
                                        fontSize: isMobile ? 11 : 13,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                  ],
                                  if (logItem.userEmail != null)
                                    Text(
                                      'Par : ${logItem.userEmail}',
                                      style: TextStyle(
                                        color: QuantisColors.textMuted,
                                        fontSize: isMobile ? 11 : 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );

    if (widget.embedded) {
      return content;
    }

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
      body: content,
    );
  }
}
