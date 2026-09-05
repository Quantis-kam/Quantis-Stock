enum MessageSender { user, assistant, system }

enum ActionStatus { pending, inProgress, success, failed }

class ActionPayload {
  final String title;
  final String? description;
  final Map<String, dynamic>? parameters;
  final ActionStatus status;

  const ActionPayload({
    required this.title,
    this.description,
    this.parameters,
    this.status = ActionStatus.success,
  });
}

class ChatUiMessage {
  final String id;
  final String text;
  final MessageSender sender;
  final DateTime timestamp;
  final bool isError;
  final List<String> suggestions;
  final List<ActionPayload> actions;

  ChatUiMessage({
    required this.id,
    required this.text,
    required this.sender,
    required this.timestamp,
    this.isError = false,
    this.suggestions = const [],
    this.actions = const [],
  });

  ChatUiMessage copyWith({
    String? id,
    String? text,
    MessageSender? sender,
    DateTime? timestamp,
    bool? isError,
    List<String>? suggestions,
    List<ActionPayload>? actions,
  }) {
    return ChatUiMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      sender: sender ?? this.sender,
      timestamp: timestamp ?? this.timestamp,
      isError: isError ?? this.isError,
      suggestions: suggestions ?? this.suggestions,
      actions: actions ?? this.actions,
    );
  }
}
