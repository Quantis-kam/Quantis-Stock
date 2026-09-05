import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';

class UserModel {
  final int id;
  final String nom;
  final String prenom;
  final String email;
  final String role;
  final String? depotName;
  final int? depotId;
  final bool actif;

  UserModel({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.email,
    required this.role,
    this.depotName,
    this.depotId,
    required this.actif,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      nom: json['nom'] as String,
      prenom: json['prenom'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      depotName: json['depot'] != null ? json['depot']['nom'] as String? : null,
      depotId: json['depot'] != null ? json['depot']['id'] as int? : null,
      actif: json['actif'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nom': nom,
      'prenom': prenom,
      'role': role,
      'depotId': depotId,
      'actif': actif,
    };
  }
}

class AuditLogModel {
  final int id;
  final String? userEmail;
  final String action;
  final String entite;
  final int? entiteId;
  final String? details;
  final String? ipAddress;
  final DateTime createdAt;

  AuditLogModel({
    required this.id,
    this.userEmail,
    required this.action,
    required this.entite,
    this.entiteId,
    this.details,
    this.ipAddress,
    required this.createdAt,
  });

  factory AuditLogModel.fromJson(Map<String, dynamic> json) {
    return AuditLogModel(
      id: json['id'] as int,
      userEmail: json['utilisateur'] != null ? json['utilisateur']['email'] as String? : 'Système',
      action: json['action'] as String,
      entite: json['entite'] as String,
      entiteId: json['entiteId'] as int?,
      details: json['details'] as String?,
      ipAddress: json['ipAddress'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class UserService {
  final Dio _dio = ApiClient.instance;

  // =================== USERS ===================

  Future<List<UserModel>> getUsers({int page = 0, int size = 50}) async {
    final response = await _dio.get('/users', queryParameters: {
      'page': page,
      'size': size,
    });
    final data = response.data['data']['content'] as List;
    return data.map((e) => UserModel.fromJson(e)).toList();
  }

  Future<UserModel> createUser(Map<String, dynamic> userMap) async {
    // register is on /auth/register
    final response = await _dio.post('/auth/register', data: userMap);
    final userJson = response.data['data']['utilisateur'];
    // In our backend, register returns AuthResponse, but let's parse the user info from it
    return UserModel.fromJson(userJson);
  }

  Future<UserModel> updateUser(int id, UserModel user) async {
    final response = await _dio.put('/users/$id', data: user.toJson());
    return UserModel.fromJson(response.data['data']);
  }

  Future<void> deleteUser(int id) async {
    await _dio.delete('/users/$id');
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    await _dio.post('/users/change-password', data: {
      'ancienMotDePasse': currentPassword,
      'nouveauMotDePasse': newPassword,
    });
  }

  // =================== AUDIT LOGS ===================

  Future<List<AuditLogModel>> getAuditLogs({int page = 0, int size = 50}) async {
    final response = await _dio.get('/audit-logs', queryParameters: {
      'page': page,
      'size': size,
    });
    final data = response.data['data']['content'] as List;
    return data.map((e) => AuditLogModel.fromJson(e)).toList();
  }

  // =================== PERMISSIONS GRANULAIRES ===================

  Future<Map<String, dynamic>> getUserPermissions(int userId) async {
    final response = await _dio.get('/users/$userId/permissions');
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<void> updateUserPermissions(int userId, Map<String, dynamic> data) async {
    await _dio.put('/users/$userId/permissions', data: data);
  }

  Future<List<dynamic>> getPermissionsCatalog() async {
    final response = await _dio.get('/users/permissions/catalog');
    return response.data['data'] as List<dynamic>;
  }
}
