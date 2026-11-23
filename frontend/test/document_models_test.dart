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
      expect(PaiementModel(moyen: 'WAVE').moyenLabel, 'Wave');
      expect(PaiementModel(moyen: 'ORANGE_MONEY').moyenLabel, 'Orange Money');
      expect(PaiementModel(moyen: 'MOOV_MONEY').moyenLabel, 'Moov Money');
      expect(PaiementModel(moyen: 'CARTE_BANCAIRE').moyenLabel, 'Carte Bancaire');
      expect(PaiementModel(moyen: 'CREDIT').moyenLabel, 'À Crédit');
      expect(PaiementModel(moyen: 'MOBILE_MONEY').moyenLabel, 'Mobile Money');
      expect(PaiementModel(moyen: 'VIREMENT').moyenLabel, 'Virement');
      expect(PaiementModel(moyen: 'CHEQUE').moyenLabel, 'Chèque');
      expect(PaiementModel(moyen: 'CARTE').moyenLabel, 'Carte');
    });

    test('LigneDocumentModel respecte TVA 0% et ne force pas 18%', () {
      final ligne = LigneDocumentModel.fromJson({
        'id': 1,
        'designation': 'Article sans TVA',
        'quantite': 2,
        'prixUnitaire': 5000,
        'tauxTva': 0,
        'montantHt': 10000,
        'montantTva': 0,
        'montantTtc': 10000,
      });
      expect(ligne.tauxTva, 0);
      expect(ligne.montantTva, 0);
      expect(ligne.montantTtc, 10000);

      final ligneMissingTva = LigneDocumentModel.fromJson({
        'id': 2,
        'designation': 'Article sans champ TVA',
        'quantite': 1,
        'prixUnitaire': 2500,
      });
      expect(ligneMissingTva.tauxTva, 0);
    });
  });

  group('CommandeModel lifecycle', () {
    test('Statut labels corrects', () {
      // Test via import
      expect(DocumentModel(type: 'DEVIS').typeLabel, 'Devis');
      expect(DocumentModel(type: 'BON_LIVRAISON').typeLabel, 'Bon de livraison');
      expect(DocumentModel(type: 'AVOIR').typeLabel, 'Avoir');
    });

    test('canPay uniquement sur FACTURE validée non soldée et canSolderCommande sur COMMANDE_CLIENT', () {
      final cmdEnAttente = DocumentModel(
        type: 'COMMANDE_CLIENT',
        statut: 'BROUILLON',
        totalTtc: 20000,
      );
      expect(cmdEnAttente.canSolderCommande, isTrue);
      expect(cmdEnAttente.isCommandeSoldee, isFalse);
      expect(cmdEnAttente.canPay, isFalse);

      final cmdSoldee = DocumentModel(
        type: 'COMMANDE_CLIENT',
        statut: 'VALIDE',
        totalTtc: 20000,
        notes: 'Soldée → FAC-2026-00010',
      );
      expect(cmdSoldee.isCommandeSoldee, isTrue);
      expect(cmdSoldee.canSolderCommande, isFalse);
    });
  });
}
