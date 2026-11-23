import 'package:flutter_test/flutter_test.dart';
import 'package:quantis_stock/features/produits/data/produit_service.dart';

void main() {
  group('ProduitModel — TVA 0% & Prix d\'achat optionnel', () {
    test('Conserve TVA à 0% sans revenir à 18%', () {
      final p = ProduitModel.fromJson({
        'id': 10,
        'nom': 'Sac de riz 25kg',
        'sku': 'RIZ-25',
        'prixAchat': 0,
        'prixVente': 15000,
        'tauxTva': 0,
      });

      expect(p.tauxTva, 0.0);
      expect(p.toJson()['tauxTva'], 0.0);
    });

    test('Prix d\'achat absent ou 0 ne génère pas de fausse marge', () {
      final sansPa = ProduitModel(
        nom: 'Savon',
        reference: 'SAV-1',
        prixAchat: 0,
        prixVente: 500,
        tauxTva: 0,
      );

      expect(sansPa.hasPrixAchat, isFalse);
      expect(sansPa.marge, 0);
      expect(sansPa.margePercent, 0);

      final avecPa = ProduitModel(
        nom: 'Huile 5L',
        reference: 'HUI-5',
        prixAchat: 4000,
        prixVente: 5000,
        tauxTva: 18,
      );

      expect(avecPa.hasPrixAchat, isTrue);
      expect(avecPa.marge, 1000);
      expect(avecPa.margePercent, 25.0);
    });
  });
}

