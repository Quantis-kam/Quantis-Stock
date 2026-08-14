import 'package:flutter_test/flutter_test.dart';
import 'package:quantis_stock/features/documents/data/document_models.dart';

void main() {
  group('DocumentModel', () {
    test('fromJson parse correctement', () {
      final json = {
        'id': 1,
        'type': 'FACTURE',
        'numero': 'FAC-2026-00001',
        'statut': 'VALIDE',
        'totalHt': 10000,
        'totalTva': 1800,
        'totalTtc': 11800,
        'client': {'id': 1, 'nom': 'Client Test'},
        'lignes': [
          {
            'id': 1,
            'designation': 'Produit A',
            'quantite': 5,
            'prixUnitaire': 2000,
            'tauxTva': 18,
            'montantHt': 10000,
            'montantTva': 1800,
            'montantTtc': 11800,
          }
        ],
        'paiements': [
          {'id': 1, 'montant': 5000, 'moyen': 'ESPECES'}
        ],
      };

      final doc = DocumentModel.fromJson(json);

      expect(doc.numero, 'FAC-2026-00001');
      expect(doc.type, 'FACTURE');
      expect(doc.typeLabel, 'Facture');
      expect(doc.statutLabel, 'Validé');
      expect(doc.totalTtc, 11800);
      expect(doc.clientNom, 'Client Test');
      expect(doc.lignes.length, 1);
      expect(doc.paiements.length, 1);
    });

    test('Calcul solde restant', () {
      final doc = DocumentModel(
        type: 'FACTURE',
        statut: 'VALIDE',
        totalTtc: 10000,
        paiements: [
          PaiementModel(montant: 3000, moyen: 'ESPECES'),
          PaiementModel(montant: 2000, moyen: 'MOBILE_MONEY'),
        ],
      );

      expect(doc.montantPaye, 5000);
      expect(doc.soldeRestant, 5000);
      expect(doc.isPayeIntegral, false);
    });

    test('Facture intégralement payée', () {
      final doc = DocumentModel(
        type: 'FACTURE',
        statut: 'VALIDE',
        totalTtc: 10000,
        paiements: [PaiementModel(montant: 10000, moyen: 'VIREMENT')],
      );

      expect(doc.isPayeIntegral, true);
      expect(doc.soldeRestant, 0);
      expect(doc.canPay, false);
    });
  });

  group('PaiementModel', () {
    test('Labels moyens de paiement', () {
      expect(PaiementModel(moyen: 'ESPECES').moyenLabel, 'Espèces');
      expect(PaiementModel(moyen: 'MOBILE_MONEY').moyenLabel, 'Mobile Money');
      expect(PaiementModel(moyen: 'VIREMENT').moyenLabel, 'Virement');
      expect(PaiementModel(moyen: 'CHEQUE').moyenLabel, 'Chèque');
      expect(PaiementModel(moyen: 'CARTE').moyenLabel, 'Carte');
    });
  });

  group('CommandeModel lifecycle', () {
    test('Statut labels corrects', () {
      // Test via import
      expect(DocumentModel(type: 'DEVIS').typeLabel, 'Devis');
      expect(DocumentModel(type: 'BON_LIVRAISON').typeLabel, 'Bon de livraison');
      expect(DocumentModel(type: 'AVOIR').typeLabel, 'Avoir');
    });
  });
}
