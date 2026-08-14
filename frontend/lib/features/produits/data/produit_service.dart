import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';

/// Modèle Produit côté Flutter.
class ProduitModel {
  final int? id;
  final String nom;
  final String? description;
  final String? reference;
  final String? codeBarres;
  final double prixAchat;
  final double prixVente;
  final int seuilAlerte;
  final String? categorieNom;
  final int? categorieId;
  final bool actif;

  ProduitModel({
    this.id,
    required this.nom,
    this.description,
    this.reference,
    this.codeBarres,
    this.prixAchat = 0,
    this.prixVente = 0,
    this.seuilAlerte = 10,
    this.categorieNom,
    this.categorieId,
    this.actif = true,
  });

  factory ProduitModel.fromJson(Map<String, dynamic> json) {
    return ProduitModel(
      id: json['id'] as int?,
      nom: json['nom'] as String? ?? '',
      description: json['description'] as String?,
      reference: json['reference'] as String?,
      codeBarres: json['codeBarres'] as String?,
      prixAchat: (json['prixAchat'] as num?)?.toDouble() ?? 0,
      prixVente: (json['prixVente'] as num?)?.toDouble() ?? 0,
      seuilAlerte: json['seuilAlerte'] as int? ?? 10,
      categorieNom: (json['categorie'] as Map<String, dynamic>?)?['nom'] as String?,
      categorieId: (json['categorie'] as Map<String, dynamic>?)?['id'] as int?,
      actif: json['actif'] as bool? ?? true,
    );
  }

  double get marge => prixVente - prixAchat;
  double get margePercent => prixAchat > 0 ? (marge / prixAchat) * 100 : 0;
}

/// Service API Produits.
class ProduitService {
  final Dio _dio = ApiClient.instance;

  Future<List<ProduitModel>> getProduits({int page = 0, int size = 50, String? search}) async {
    final params = <String, dynamic>{'page': page, 'size': size};
    if (search != null && search.isNotEmpty) params['search'] = search;
    final response = await _dio.get('/products', queryParameters: params);
    final data = response.data['data']['content'] as List;
    return data.map((e) => ProduitModel.fromJson(e)).toList();
  }

  Future<ProduitModel> getProduit(int id) async {
    final response = await _dio.get('/products/$id');
    return ProduitModel.fromJson(response.data['data']);
  }
}
