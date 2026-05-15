class ChatMessage {
  final String role; // 'user', 'assistant', 'system'
  final String content;
  final DateTime timestamp;
  final String? correction; // Grammar correction if any

  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.correction,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toApiMessage() {
    return {
      'role': role,
      'content': content,
    };
  }
}
