import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';

/// Modèle Catégorie côté Flutter.
class CategorieModel {
  final int? id;
  final String nom;
  final String? description;
  final int? parentId;
  final String? parentNom;
  final List<CategorieModel> sousCategories;

  CategorieModel({
    this.id,
    required this.nom,
    this.description,
    this.parentId,
    this.parentNom,
    this.sousCategories = const [],
  });

  factory CategorieModel.fromJson(Map<String, dynamic> json) {
    var subList = json['sousCategories'] as List? ?? [];
    List<CategorieModel> subs = subList.map((e) => CategorieModel.fromJson(e as Map<String, dynamic>)).toList();
    
    return CategorieModel(
      id: json['id'] as int?,
      nom: json['nom'] as String? ?? '',
      description: json['description'] as String?,
      parentId: (json['parent'] as Map<String, dynamic>?)?['id'] as int?,
      parentNom: (json['parent'] as Map<String, dynamic>?)?['nom'] as String?,
      sousCategories: subs,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'nom': nom,
      'description': description,
      'parentId': parentId,
    };
  }
}

/// Service API Catégories.
class CategorieService {
  final Dio _dio = ApiClient.instance;

  Future<List<CategorieModel>> getCategories() async {
    final response = await _dio.get('/categories');
    final data = response.data['data'] as List;
    return data.map((e) => CategorieModel.fromJson(e)).toList();
  }

  Future<List<CategorieModel>> getRoots() async {
    final response = await _dio.get('/categories/roots');
    final data = response.data['data'] as List;
    return data.map((e) => CategorieModel.fromJson(e)).toList();
  }

  Future<CategorieModel> create(CategorieModel cat) async {
    final response = await _dio.post('/categories', data: cat.toJson());
    return CategorieModel.fromJson(response.data['data']);
  }

  Future<CategorieModel> update(int id, CategorieModel cat) async {
    final response = await _dio.put('/categories/$id', data: cat.toJson());
    return CategorieModel.fromJson(response.data['data']);
  }

  Future<void> delete(int id) async {
    await _dio.delete('/categories/$id');
  }
}
