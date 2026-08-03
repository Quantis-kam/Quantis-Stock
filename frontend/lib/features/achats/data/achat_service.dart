import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import 'achat_models.dart';

/// Service API pour les commandes fournisseur.
class AchatService {
  final Dio _dio = ApiClient.instance;

  Future<List<CommandeModel>> getCommandes({int page = 0, int size = 50}) async {
    final response = await _dio.get('/purchases', queryParameters: {'page': page, 'size': size});
    final data = response.data['data']['content'] as List;
    return data.map((e) => CommandeModel.fromJson(e)).toList();
  }

  Future<CommandeModel> getCommande(int id) async {
    final response = await _dio.get('/purchases/$id');
    return CommandeModel.fromJson(response.data['data']);
  }

  Future<CommandeModel> creerCommande(Map<String, dynamic> data) async {
    final response = await _dio.post('/purchases', data: data);
    return CommandeModel.fromJson(response.data['data']);
  }

  Future<CommandeModel> valider(int id) async {
    final response = await _dio.put('/purchases/$id/validate');
    return CommandeModel.fromJson(response.data['data']);
  }

  Future<CommandeModel> annuler(int id) async {
    final response = await _dio.put('/purchases/$id/cancel');
    return CommandeModel.fromJson(response.data['data']);
  }

  Future<CommandeModel> receptionner(int id, Map<String, dynamic> data) async {
    final response = await _dio.post('/purchases/$id/receive', data: data);
    return CommandeModel.fromJson(response.data['data']);
  }
}
