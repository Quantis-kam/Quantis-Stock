import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';

/// Modèle Unité de Mesure côté Flutter.
class UniteMesureModel {
  final int id;
  final String nom;
  final String abreviation;

  UniteMesureModel({
    required this.id,
    required this.nom,
    required this.abreviation,
  });

  factory UniteMesureModel.fromJson(Map<String, dynamic> json) {
    return UniteMesureModel(
      id: json['id'] as int,
      nom: json['nom'] as String? ?? '',
      abreviation: json['abreviation'] as String? ?? '',
    );
  }
}

/// Modèle Variante de Produit côté Flutter.
class VarianteModel {
  final int? id;
  final String attribut;
  final String valeur;
  final String? skuVariante;
  final String? codeBarresVariante;
  final double? prixAchatOverride;
  final double? prixVenteOverride;

  VarianteModel({
    this.id,
    required this.attribut,
    required this.valeur,
    this.skuVariante,
    this.codeBarresVariante,
    this.prixAchatOverride,
    this.prixVenteOverride,
  });

  factory VarianteModel.fromJson(Map<String, dynamic> json) {
    return VarianteModel(
      id: json['id'] as int?,
      attribut: json['attribut'] as String? ?? '',
      valeur: json['valeur'] as String? ?? '',
      skuVariante: json['skuVariante'] as String?,
      codeBarresVariante: json['codeBarresVariante'] as String?,
      prixAchatOverride: (json['prixAchatOverride'] as num?)?.toDouble(),
      prixVenteOverride: (json['prixVenteOverride'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'attribut': attribut,
      'valeur': valeur,
      'skuVariante': skuVariante,
      'codeBarresVariante': codeBarresVariante,
      'prixAchatOverride': prixAchatOverride,
      'prixVenteOverride': prixVenteOverride,
    };
  }
}

/// Modèle Produit côté Flutter.
class ProduitModel {
  final int? id;
  final String nom;
  final String? description;
  final String reference; // Mapped to SKU
  final String? codeBarres;
  final double prixAchat;
  final double prixVente;
  final double tauxTva;
  final int seuilAlerte;
  final String? imageUrl;
  final int? categorieId;
  final String? categorieNom;
  final int? uniteId;
  final String? uniteNom;
  final String? uniteAbreviation;
  final List<VarianteModel> variantes;
  final bool actif;

  ProduitModel({
    this.id,
    required this.nom,
    this.description,
    required this.reference,
    this.codeBarres,
    this.prixAchat = 0,
    this.prixVente = 0,
    this.tauxTva = 18.0,
    this.seuilAlerte = 10,
    this.imageUrl,
    this.categorieId,
    this.categorieNom,
    this.uniteId,
    this.uniteNom,
    this.uniteAbreviation,
    this.variantes = const [],
    this.actif = true,
  });

  factory ProduitModel.fromJson(Map<String, dynamic> json) {
    var varList = json['variantes'] as List? ?? [];
    List<VarianteModel> vars = varList.map((e) => VarianteModel.fromJson(e as Map<String, dynamic>)).toList();

    return ProduitModel(
      id: json['id'] as int?,
      nom: json['nom'] as String? ?? '',
      description: json['description'] as String?,
      reference: json['sku'] as String? ?? json['reference'] as String? ?? '',
      codeBarres: json['codeBarres'] as String?,
      prixAchat: (json['prixAchat'] as num?)?.toDouble() ?? 0,
      prixVente: (json['prixVente'] as num?)?.toDouble() ?? 0,
      tauxTva: (json['tauxTva'] as num?)?.toDouble() ?? 18.0,
      seuilAlerte: json['seuilAlerte'] as int? ?? 10,
      imageUrl: json['imageUrl'] as String?,
      categorieId: (json['categorie'] as Map<String, dynamic>?)?['id'] as int?,
      categorieNom: (json['categorie'] as Map<String, dynamic>?)?['nom'] as String?,
      uniteId: (json['unite'] as Map<String, dynamic>?)?['id'] as int?,
      uniteNom: (json['unite'] as Map<String, dynamic>?)?['nom'] as String?,
      uniteAbreviation: (json['unite'] as Map<String, dynamic>?)?['abreviation'] as String?,
      variantes: vars,
      actif: json['actif'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'nom': nom,
      'description': description,
      'sku': reference,
      'codeBarres': codeBarres,
      'prixAchat': prixAchat,
      'prixVente': prixVente,
      'tauxTva': tauxTva,
      'seuilAlerte': seuilAlerte,
      'imageUrl': imageUrl,
      'categorieId': categorieId,
      'uniteId': uniteId,
      'variantes': variantes.map((e) => e.toJson()).toList(),
      'actif': actif,
    };
  }

  double get marge => prixVente - prixAchat;
  double get margePercent => prixAchat > 0 ? (marge / prixAchat) * 100 : 0;
}

/// Service API Produits.
class ProduitService {
  final Dio _dio = ApiClient.instance;

  Future<List<ProduitModel>> getProduits({int page = 0, int size = 100, String? search}) async {
    final params = <String, dynamic>{'page': page, 'size': size};
    
    Response response;
    if (search != null && search.isNotEmpty) {
      params['q'] = search;
      response = await _dio.get('/products/search', queryParameters: params);
    } else {
      response = await _dio.get('/products', queryParameters: params);
    }
    
    final data = response.data['data']['content'] as List;
    return data.map((e) => ProduitModel.fromJson(e)).toList();
  }

  Future<ProduitModel> getProduit(int id) async {
    final response = await _dio.get('/products/$id');
    return ProduitModel.fromJson(response.data['data']);
  }

  Future<ProduitModel> createProduit(ProduitModel produit) async {
    final response = await _dio.post('/products', data: produit.toJson());
    return ProduitModel.fromJson(response.data['data']);
  }

  Future<ProduitModel> updateProduit(int id, ProduitModel produit) async {
    final response = await _dio.put('/products/$id', data: produit.toJson());
    return ProduitModel.fromJson(response.data['data']);
  }

  Future<void> deleteProduit(int id) async {
    await _dio.delete('/products/$id');
  }

  Future<List<UniteMesureModel>> getUnits() async {
    final response = await _dio.get('/products/units');
    final data = response.data['data'] as List;
    return data.map((e) => UniteMesureModel.fromJson(e)).toList();
  }

  Future<int> importProductsCsv(List<int> bytes, String filename) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final response = await _dio.post('/products/import', data: formData);
    return response.data['data']['importedCount'] as int;
  }
}
