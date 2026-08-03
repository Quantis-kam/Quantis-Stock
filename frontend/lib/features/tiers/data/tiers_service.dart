import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import 'tiers_models.dart';

/// Service API pour les Clients et Fournisseurs.
class TiersService {
  final Dio _dio = ApiClient.instance;

  // =================== CLIENTS ===================

  Future<List<ClientModel>> getClients({int page = 0, int size = 50}) async {
    final response = await _dio.get('/clients', queryParameters: {
      'page': page,
      'size': size,
    });
    final data = response.data['data']['content'] as List;
    return data.map((e) => ClientModel.fromJson(e)).toList();
  }

  Future<ClientModel> getClient(int id) async {
    final response = await _dio.get('/clients/$id');
    return ClientModel.fromJson(response.data['data']);
  }

  Future<List<ClientModel>> searchClients(String query) async {
    final response = await _dio.get('/clients/search', queryParameters: {'q': query});
    final data = response.data['data']['content'] as List;
    return data.map((e) => ClientModel.fromJson(e)).toList();
  }

  Future<ClientModel> createClient(ClientModel client) async {
    final response = await _dio.post('/clients', data: client.toJson());
    return ClientModel.fromJson(response.data['data']);
  }

  Future<ClientModel> updateClient(int id, ClientModel client) async {
    final response = await _dio.put('/clients/$id', data: client.toJson());
    return ClientModel.fromJson(response.data['data']);
  }

  // =================== FOURNISSEURS ===================

  Future<List<FournisseurModel>> getFournisseurs({int page = 0, int size = 50}) async {
    final response = await _dio.get('/suppliers', queryParameters: {
      'page': page,
      'size': size,
    });
    final data = response.data['data']['content'] as List;
    return data.map((e) => FournisseurModel.fromJson(e)).toList();
  }

  Future<FournisseurModel> getFournisseur(int id) async {
    final response = await _dio.get('/suppliers/$id');
    return FournisseurModel.fromJson(response.data['data']);
  }

  Future<FournisseurModel> createFournisseur(FournisseurModel fournisseur) async {
    final response = await _dio.post('/suppliers', data: fournisseur.toJson());
    return FournisseurModel.fromJson(response.data['data']);
  }

  Future<FournisseurModel> updateFournisseur(int id, FournisseurModel fournisseur) async {
    final response = await _dio.put('/suppliers/$id', data: fournisseur.toJson());
    return FournisseurModel.fromJson(response.data['data']);
  }

  Future<void> deleteFournisseur(int id) async {
    await _dio.delete('/suppliers/$id');
  }
}
