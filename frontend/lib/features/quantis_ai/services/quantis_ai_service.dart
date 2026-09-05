import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';

/// Service API pour communiquer avec Quantis AI backend.
class QuantisAiService {
  /// Envoie un message à Quantis et retourne la réponse.
  static Future<QuantisResponse> chat(String message, {String? conversationId}) async {
    try {
      final response = await ApiClient.instance.post(
        '/quantis/chat',
        data: {
          'message': message,
          if (conversationId != null) 'conversationId': conversationId,
        },
      );

      return QuantisResponse.fromJson(response.data);
    } on DioException {
      return QuantisResponse(
        message: 'Impossible de contacter Quantis. Vérifiez votre connexion. 🔌',
        conversationId: conversationId ?? '',
        type: 'ERROR',
        suggestions: [],
      );
    }
  }

  /// Récupère les suggestions initiales.
  static Future<List<String>> getSuggestions() async {
    try {
      final response = await ApiClient.instance.get('/quantis/suggestions');
      return List<String>.from(response.data);
    } catch (_) {
      return [
        '📊 Comment va mon stock ?',
        '⚠️ Y a-t-il des ruptures ?',
        '💰 Chiffre d\'affaires du mois ?',
      ];
    }
  }

  /// Vérifie le statut de l'IA.
  static Future<Map<String, dynamic>> getStatus() async {
    try {
      final response = await ApiClient.instance.get('/quantis/status');
      return Map<String, dynamic>.from(response.data);
    } catch (_) {
      return {'enabled': false, 'provider': 'unknown'};
    }
  }

  /// Efface l'historique d'une conversation.
  static Future<void> clearConversation(String conversationId) async {
    try {
      await ApiClient.instance.delete('/quantis/chat/$conversationId');
    } catch (_) {}
  }
}

/// Modèle de réponse Quantis AI.
class QuantisResponse {
  final String message;
  final String conversationId;
  final String type;
  final List<String> suggestions;

  QuantisResponse({
    required this.message,
    required this.conversationId,
    required this.type,
    required this.suggestions,
  });

  factory QuantisResponse.fromJson(Map<String, dynamic> json) {
    return QuantisResponse(
      message: json['message'] ?? '',
      conversationId: json['conversationId'] ?? '',
      type: json['type'] ?? 'TEXT',
      suggestions: json['suggestions'] != null
          ? List<String>.from(json['suggestions'])
          : [],
    );
  }
}
