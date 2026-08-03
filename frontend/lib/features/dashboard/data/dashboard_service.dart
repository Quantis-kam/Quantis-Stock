import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';

/// Service API pour le Dashboard.
class DashboardService {
  final Dio _dio = ApiClient.instance;

  Future<Map<String, dynamic>> getKpis() async {
    final response = await _dio.get('/dashboard/kpis');
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getVentesParMois({int? year}) async {
    final response = await _dio.get('/dashboard/sales', queryParameters: {
      if (year != null) 'year': year,
    });
    final data = response.data['data'] as List;
    return data.cast<Map<String, dynamic>>();
  }
}
