import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/quantis_theme.dart';

/// Dialogue d'ouverture ou de fermeture de session de caisse.
class SessionCaisseDialog extends StatefulWidget {
  final Map<String, dynamic>? activeSession;
  final VoidCallback onSessionChanged;

  const SessionCaisseDialog({
    super.key,
    this.activeSession,
    required this.onSessionChanged,
  });

  @override
  State<SessionCaisseDialog> createState() => _SessionCaisseDialogState();
}

class _SessionCaisseDialogState extends State<SessionCaisseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  bool _loading = false;
  String? _error;

  bool get _isOpen => widget.activeSession != null;

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      final dio = ApiClient.instance;
      final amount = double.tryParse(_amountController.text.replaceAll(' ', '')) ?? 0;

      if (_isOpen) {
        // Fermeture de caisse
        await dio.post('/caisses/fermer', data: {
          'soldeCompte': amount,
          'notes': _notesController.text.trim(),
        });
      } else {
        // Ouverture de caisse
        await dio.post('/caisses/ouvrir', data: {
          'fondCaisseOuverture': amount,
          'notes': _notesController.text.trim(),
        });
      }

      if (mounted) {
        Navigator.of(context).pop();
        widget.onSessionChanged();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isOpen ? 'Session de caisse fermée avec succès !' : 'Caisse ouverte avec succès !'),
            backgroundColor: QuantisColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() { _error = 'Erreur : $e'; });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = widget.activeSession;
    final soldeTheorique = active != null ? (active['soldeTheorique'] as num? ?? 0).toDouble() : 0.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: (_isOpen ? QuantisColors.warning : QuantisColors.success).withValues(alpha: 0.15),
                      child: Icon(
                        _isOpen ? Icons.lock_clock : Icons.point_of_sale,
                        color: _isOpen ? QuantisColors.warning : QuantisColors.success,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _isOpen ? 'Clôture de Caisse' : 'Ouverture de Caisse',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (_isOpen) ...[
                  Card(
                    color: QuantisColors.royalBlue.withValues(alpha: 0.05),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Solde Théorique attendu :', style: TextStyle(fontSize: 12, color: QuantisColors.textMuted)),
                          const SizedBox(height: 4),
                          Text(
                            '${soldeTheorique.toStringAsFixed(0)} FCFA',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: QuantisColors.royalBlue,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Ouverte depuis : ${active!['dateOuverture'] != null ? active['dateOuverture'].toString().substring(0, 16).replaceAll('T', ' ') : '-'}',
                            style: const TextStyle(fontSize: 11, color: QuantisColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: _isOpen ? 'Solde Reel Compte (FCFA)' : 'Fond de Caisse d\'ouverture (FCFA)',
                    hintText: _isOpen ? 'Ex: 150000' : 'Ex: 50000',
                    prefixIcon: const Icon(Icons.payments_outlined),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Veuillez saisir un montant';
                    }
                    if (double.tryParse(val.replaceAll(' ', '')) == null) {
                      return 'Montant invalide';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes / Observations',
                    hintText: 'Ex: Billets de 10000 x 10, Pièces x 50...',
                    prefixIcon: Icon(Icons.note_alt_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Text(_error!, style: const TextStyle(color: QuantisColors.error, fontSize: 12)),
                  ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Annuler'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _loading ? null : _submit,
                      icon: _loading
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Icon(_isOpen ? Icons.lock : Icons.check_circle_outline, size: 18),
                      label: Text(_isOpen ? 'Fermer la Caisse' : 'Ouvrir la Caisse'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isOpen ? QuantisColors.warning : QuantisColors.royalBlue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

