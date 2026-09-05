import 'package:flutter/material.dart';
import 'dart:convert';
import '../../../core/theme/quantis_theme.dart';
import '../data/produit_service.dart';

class CsvImportDialog extends StatefulWidget {
  const CsvImportDialog({super.key});

  @override
  State<CsvImportDialog> createState() => _CsvImportDialogState();
}

class _CsvImportDialogState extends State<CsvImportDialog> {
  final _produitService = ProduitService();
  final _csvTextCtrl = TextEditingController();
  bool _importing = false;

  Future<void> _importRawText() async {
    final text = _csvTextCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez saisir du texte CSV'), backgroundColor: QuantisColors.error),
      );
      return;
    }

    setState(() => _importing = true);
    try {
      final bytes = utf8.encode(text);
      final count = await _produitService.importProductsCsv(bytes, 'import.csv');
      
      if (mounted) {
        Navigator.pop(context, count);
      }
    } catch (e) {
      setState(() => _importing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'importation: $e'), backgroundColor: QuantisColors.error),
      );
    }
  }

  @override
  void dispose() {
    _csvTextCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Importation de Produits (CSV)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: QuantisColors.royalBlue),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const Divider(height: 24),
              
              const Text(
                'Instructions de formatage',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: QuantisColors.textSecondary),
              ),
              const SizedBox(height: 8),
              const Text(
                'Saisissez ou collez vos données CSV. Utilisez la virgule (,) ou le point-virgule (;) comme séparateur. La première ligne doit contenir les en-têtes exactement comme suit :',
                style: TextStyle(fontSize: 12, color: QuantisColors.textMuted),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const SelectableText(
                  'sku,nom,description,prixAchat,prixVente,seuilAlerte,tauxTva,codeBarres,categorieNom,uniteNom',
                  style: TextStyle(fontFamily: 'Courier', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Exemple :',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: QuantisColors.textSecondary),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const SelectableText(
                  'PROD-001,Coca-Cola 33cl,Canette de soda,350,500,20,18,5449000000996,Boissons,Pièce\nPROD-002,Farine 1kg,Farine de blé de qualité supérieure,450,600,10,18,,Alimentation,Kilogramme',
                  style: TextStyle(fontFamily: 'Courier', fontSize: 11, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 20),
              
              const Text(
                'Données CSV à importer :',
                style: TextStyle(fontWeight: FontWeight.bold, color: QuantisColors.textSecondary),
              ),
              const SizedBox(height: 8),
              
              TextField(
                controller: _csvTextCtrl,
                maxLines: 8,
                style: const TextStyle(fontFamily: 'Courier', fontSize: 12),
                decoration: const InputDecoration(
                  hintText: 'Collez le contenu de votre fichier CSV ici...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 24),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _importing ? null : () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.file_upload_outlined, color: Colors.white),
                    label: const Text('Lancer l\'importation'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: QuantisColors.royalBlue,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _importing ? null : _importRawText,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
