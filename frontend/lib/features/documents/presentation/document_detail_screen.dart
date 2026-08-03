import 'package:flutter/material.dart';
import '../../../core/theme/quantis_theme.dart';
import '../data/document_models.dart';
import '../data/document_service.dart';

/// Écran détail d'un document avec lignes, totaux, paiements, et actions.
class DocumentDetailScreen extends StatefulWidget {
  final int documentId;
  const DocumentDetailScreen({super.key, required this.documentId});

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  final DocumentService _service = DocumentService();
  DocumentModel? _doc;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _doc = await _service.getDocument(widget.documentId);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _valider() async {
    try {
      await _service.valider(widget.documentId);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document validé'), backgroundColor: QuantisColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: QuantisColors.error),
        );
      }
    }
  }

  Future<void> _enregistrerPaiement() async {
    if (_doc == null) return;
    final montantController = TextEditingController(text: _doc!.soldeRestant.toStringAsFixed(0));
    String moyen = 'ESPECES';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Enregistrer un paiement'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: montantController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Montant (FCFA)',
                  prefixIcon: Icon(Icons.payments),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: moyen,
                decoration: const InputDecoration(
                  labelText: 'Moyen de paiement',
                  prefixIcon: Icon(Icons.payment),
                ),
                items: const [
                  DropdownMenuItem(value: 'ESPECES', child: Text('Espèces')),
                  DropdownMenuItem(value: 'MOBILE_MONEY', child: Text('Mobile Money')),
                  DropdownMenuItem(value: 'VIREMENT', child: Text('Virement')),
                  DropdownMenuItem(value: 'CHEQUE', child: Text('Chèque')),
                  DropdownMenuItem(value: 'CARTE', child: Text('Carte')),
                ],
                onChanged: (v) => setDialogState(() => moyen = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );

    if (result == true && mounted) {
      try {
        await _service.enregistrerPaiement({
          'documentId': widget.documentId,
          'montant': double.tryParse(montantController.text) ?? 0,
          'moyen': moyen,
        });
        _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Paiement enregistré'), backgroundColor: QuantisColors.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: QuantisColors.error),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Document')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_doc == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Document')),
        body: const Center(child: Text('Document introuvable')),
      );
    }

    final doc = _doc!;
    return Scaffold(
      appBar: AppBar(
        title: Text('${doc.typeLabel} ${doc.numero}'),
        actions: [
          if (doc.canValidate)
            TextButton.icon(
              icon: const Icon(Icons.check_circle, color: QuantisColors.success),
              label: const Text('Valider', style: TextStyle(color: QuantisColors.success)),
              onPressed: _valider,
            ),
          if (doc.canPay)
            TextButton.icon(
              icon: const Icon(Icons.payments, color: QuantisColors.luxuryGold),
              label: const Text('Payer', style: TextStyle(color: QuantisColors.luxuryGold)),
              onPressed: _enregistrerPaiement,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(doc.numero, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: (doc.statut == 'VALIDE' ? QuantisColors.success : QuantisColors.textMuted)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(doc.statutLabel, style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: doc.statut == 'VALIDE' ? QuantisColors.success : QuantisColors.textMuted,
                          )),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (doc.clientNom != null) Text('Client: ${doc.clientNom}'),
                    if (doc.dateDocument != null) Text('Date: ${doc.dateDocument}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Lignes
            const Text('Lignes', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            ...doc.lignes.map((l) => Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                dense: true,
                title: Text(l.designation, style: const TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text('${l.quantite.toStringAsFixed(0)} × ${l.prixUnitaire.toStringAsFixed(0)} FCFA'),
                trailing: Text('${l.montantTtc.toStringAsFixed(0)} FCFA',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            )),
            const SizedBox(height: 16),

            // Totaux
            Card(
              color: QuantisColors.royalBlue.withValues(alpha: 0.03),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _TotalRow('Total HT', doc.totalHt),
                    _TotalRow('TVA (18%)', doc.totalTva),
                    const Divider(),
                    _TotalRow('Total TTC', doc.totalTtc, bold: true, size: 18),
                    if (doc.type == 'FACTURE' && doc.statut == 'VALIDE') ...[
                      const Divider(),
                      _TotalRow('Payé', doc.montantPaye, color: QuantisColors.success),
                      _TotalRow('Reste', doc.soldeRestant,
                          color: doc.isPayeIntegral ? QuantisColors.success : QuantisColors.warning, bold: true),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Paiements
            if (doc.paiements.isNotEmpty) ...[
              const Text('Paiements', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 8),
              ...doc.paiements.map((p) => Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.payments, color: QuantisColors.success),
                  title: Text('${p.montant.toStringAsFixed(0)} FCFA'),
                  subtitle: Text('${p.moyenLabel}${p.datePaiement != null ? ' — ${p.datePaiement}' : ''}'),
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final double value;
  final bool bold;
  final double size;
  final Color? color;

  const _TotalRow(this.label, this.value, {this.bold = false, this.size = 14, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(
            fontSize: size,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            color: color,
          )),
          Text('${value.toStringAsFixed(0)} FCFA', style: TextStyle(
            fontSize: size,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: color,
          )),
        ],
      ),
    );
  }
}
