import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import 'document_models.dart';

/// Service API pour les documents commerciaux et paiements.
class DocumentService {
  final Dio _dio = ApiClient.instance;

  Future<List<DocumentModel>> getDocuments(String type, {int page = 0, int size = 50}) async {
    final response = await _dio.get('/documents', queryParameters: {
      'type': type,
      'page': page,
      'size': size,
    });
    final data = response.data['data']['content'] as List;
    return data.map((e) => DocumentModel.fromJson(e)).toList();
  }

  Future<DocumentModel> getDocument(int id) async {
    final response = await _dio.get('/documents/$id');
    return DocumentModel.fromJson(response.data['data']);
  }

  Future<DocumentModel> creerDocument(Map<String, dynamic> data) async {
    final response = await _dio.post('/documents', data: data);
    return DocumentModel.fromJson(response.data['data']);
  }

  Future<DocumentModel> valider(int id) async {
    final response = await _dio.put('/documents/$id/validate');
    return DocumentModel.fromJson(response.data['data']);
  }

  Future<DocumentModel> annuler(int id) async {
    final response = await _dio.put('/documents/$id/cancel');
    return DocumentModel.fromJson(response.data['data']);
  }

  Future<void> enregistrerPaiement(Map<String, dynamic> data) async {
    await _dio.post('/documents/payments', data: data);
  }

  Future<List<PaiementModel>> getPaiements(int documentId) async {
    final response = await _dio.get('/documents/$documentId/payments');
    final data = response.data['data'] as List;
    return data.map((e) => PaiementModel.fromJson(e)).toList();
  }
}
