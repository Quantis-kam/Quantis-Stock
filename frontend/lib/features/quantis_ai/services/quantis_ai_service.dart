import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';

/// Type d'événement émis par le stream SSE.
enum ChatStreamEventType { step, complete, error }

/// Événement émis lors du streaming temps réel avec Quantis AI.
class ChatStreamEvent {
  final ChatStreamEventType type;
  final String? step;
  final String? label;
  final String? icon;
  final QuantisResponse? response;
  final String? error;

  const ChatStreamEvent.step({
    required this.step,
    required this.label,
    this.icon,
  })  : type = ChatStreamEventType.step,
        response = null,
        error = null;

  const ChatStreamEvent.complete(this.response)
      : type = ChatStreamEventType.complete,
        step = null,
        label = null,
        icon = null,
        error = null;

  const ChatStreamEvent.error(this.error)
      : type = ChatStreamEventType.error,
        step = null,
        label = null,
        icon = null,
        response = null;
}

/// Service API pour communiquer avec Quantis AI backend.
class QuantisAiService {
  /// Envoie un message à Quantis et retourne la réponse synchrone.
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

  /// Écoute en streaming SSE les étapes d'exécution et la réponse finale de Quantis.
  static Stream<ChatStreamEvent> chatStream(
    String message, {
    String? conversationId,
  }) async* {
    try {
      final response = await ApiClient.instance.post<ResponseBody>(
        '/quantis/chat-stream',
        data: {
          'message': message,
          if (conversationId != null) 'conversationId': conversationId,
        },
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            'Accept': 'text/event-stream',
          },
        ),
      );

      final responseBody = response.data;
      if (responseBody == null) {
        throw Exception('Flux SSE vide');
      }

      String currentEvent = 'message';
      final buffer = StringBuffer();

      await for (final line in responseBody.stream
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) {
          if (buffer.isNotEmpty) {
            final dataStr = buffer.toString();
            buffer.clear();
            try {
              final json = jsonDecode(dataStr) as Map<String, dynamic>;
              if (currentEvent == 'step') {
                yield ChatStreamEvent.step(
                  step: json['step']?.toString(),
                  label: json['label']?.toString(),
                  icon: json['icon']?.toString(),
                );
              } else if (currentEvent == 'complete') {
                yield ChatStreamEvent.complete(QuantisResponse.fromJson(json));
              } else if (currentEvent == 'error') {
                yield ChatStreamEvent.error(json['error']?.toString() ?? 'Erreur SSE');
              }
            } catch (_) {}
          }
          currentEvent = 'message';
          continue;
        }

        if (trimmed.startsWith('event:')) {
          currentEvent = trimmed.substring(6).trim();
        } else if (trimmed.startsWith('data:')) {
          buffer.write(trimmed.substring(5).trim());
        }
      }

      if (buffer.isNotEmpty) {
        try {
          final json = jsonDecode(buffer.toString()) as Map<String, dynamic>;
          if (currentEvent == 'complete') {
            yield ChatStreamEvent.complete(QuantisResponse.fromJson(json));
          }
        } catch (_) {}
      }
    } catch (_) {
      // Fallback résilient : étapes simulées puis chat synchrone
      yield const ChatStreamEvent.step(
        step: 'thinking',
        label: 'Quantis analyse votre demande...',
        icon: '🧠',
      );
      yield const ChatStreamEvent.step(
        step: 'processing',
        label: 'Exécution en cours...',
        icon: '⚙️',
      );

      final fallbackRes = await chat(message, conversationId: conversationId);
      yield const ChatStreamEvent.step(
        step: 'done',
        label: 'Action terminée',
        icon: '✅',
      );
      yield ChatStreamEvent.complete(fallbackRes);
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
  final List<Map<String, dynamic>> actions;
  final Map<String, dynamic>? data;

  QuantisResponse({
    required this.message,
    required this.conversationId,
    required this.type,
    required this.suggestions,
    this.actions = const [],
    this.data,
  });

  factory QuantisResponse.fromJson(Map<String, dynamic> json) {
    return QuantisResponse(
      message: json['message'] ?? '',
      conversationId: json['conversationId'] ?? '',
      type: json['type'] ?? 'TEXT',
      suggestions: json['suggestions'] != null
          ? List<String>.from(json['suggestions'])
          : [],
      actions: json['actions'] != null
          ? List<Map<String, dynamic>>.from(
              (json['actions'] as List).map((e) => Map<String, dynamic>.from(e)))
          : [],
      data: json['data'] != null ? Map<String, dynamic>.from(json['data']) : null,
    );
  }
}
