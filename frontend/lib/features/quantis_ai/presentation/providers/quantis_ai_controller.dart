import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../services/quantis_ai_service.dart';
import '../models/chat_ui_message.dart';

class QuantisAiState {
  final List<ChatUiMessage> messages;
  final bool isLoading;
  final String? conversationId;
  final List<String> currentSuggestions;
  final String? error;

  const QuantisAiState({
    this.messages = const [],
    this.isLoading = false,
    this.conversationId,
    this.currentSuggestions = const [],
    this.error,
  });

  QuantisAiState copyWith({
    List<ChatUiMessage>? messages,
    bool? isLoading,
    String? conversationId,
    List<String>? currentSuggestions,
    String? error,
  }) {
    return QuantisAiState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      conversationId: conversationId ?? this.conversationId,
      currentSuggestions: currentSuggestions ?? this.currentSuggestions,
      error: error,
    );
  }
}

class QuantisAiNotifier extends StateNotifier<QuantisAiState> {
  QuantisAiNotifier() : super(const QuantisAiState()) {
    init();
  }

  static const _uuid = Uuid();

  Future<void> init() async {
    final convId = _uuid.v4();
    state = state.copyWith(conversationId: convId);

    // Initial greeting
    final welcomeMessage = ChatUiMessage(
      id: _uuid.v4(),
      text: 'Bonjour ! Je suis **Quantis**, votre assistant expert en gestion de stock et logistique. 📦✨\n\n'
          'Comment puis-je vous aider aujourd\'hui ? Je peux analyser vos stocks, vous alerter sur les ruptures, enregistrer des mouvements ou créer des produits.',
      sender: MessageSender.assistant,
      timestamp: DateTime.now(),
      suggestions: const [
        '📊 Comment va mon stock aujourd\'hui ?',
        '⚠️ Y a-t-il des ruptures de stock ?',
        '💰 Quel est le chiffre d\'affaires du mois ?',
        '📦 Rechercher un produit',
      ],
    );

    state = state.copyWith(
      messages: [welcomeMessage],
      currentSuggestions: welcomeMessage.suggestions,
    );

    try {
      final suggestions = await QuantisAiService.getSuggestions();
      if (suggestions.isNotEmpty && mounted) {
        state = state.copyWith(currentSuggestions: suggestions);
      }
    } catch (_) {}
  }

  Future<ChatUiMessage?> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isLoading) return null;

    final userMsg = ChatUiMessage(
      id: _uuid.v4(),
      text: trimmed,
      sender: MessageSender.user,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isLoading: true,
      currentSuggestions: [],
      error: null,
    );

    try {
      final response = await QuantisAiService.chat(
        trimmed,
        conversationId: state.conversationId,
      );

      final isError = response.type == 'ERROR';
      final assistantMsg = ChatUiMessage(
        id: _uuid.v4(),
        text: response.message,
        sender: MessageSender.assistant,
        timestamp: DateTime.now(),
        isError: isError,
        suggestions: response.suggestions,
      );

      state = state.copyWith(
        messages: [...state.messages, assistantMsg],
        isLoading: false,
        conversationId: response.conversationId.isNotEmpty
            ? response.conversationId
            : state.conversationId,
        currentSuggestions: response.suggestions.isNotEmpty
            ? response.suggestions
            : state.currentSuggestions,
      );
      return assistantMsg;
    } catch (e) {
      final errorMsg = ChatUiMessage(
        id: _uuid.v4(),
        text: 'Désolé, une erreur de communication est survenue. Veuillez vérifier votre connexion. 🔌',
        sender: MessageSender.assistant,
        timestamp: DateTime.now(),
        isError: true,
      );

      state = state.copyWith(
        messages: [...state.messages, errorMsg],
        isLoading: false,
        error: e.toString(),
      );
      return errorMsg;
    }
  }

  Future<void> clearHistory() async {
    if (state.conversationId != null) {
      await QuantisAiService.clearConversation(state.conversationId!);
    }
    state = const QuantisAiState();
    await init();
  }
}

final quantisAiProvider =
    StateNotifierProvider<QuantisAiNotifier, QuantisAiState>((ref) {
  return QuantisAiNotifier();
});
