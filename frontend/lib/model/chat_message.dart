import 'package:frontend/model/chat_models.dart';

/// Sender of a chat message.
enum ChatMessageSender { user, agent }

/// Wraps output chunks with sender metadata for the chat UI.
class ChatMessage {
  final String id;
  final ChatMessageSender sender;
  final DateTime timestamp;
  final List<OutputItemBase> chunks;

  ChatMessage({
    required this.id,
    required this.sender,
    required this.timestamp,
    required this.chunks,
  });

  /// Convenience factory for a user text message.
  factory ChatMessage.user(String text) => ChatMessage(
    id: 'user-${DateTime.now().millisecondsSinceEpoch}',
    sender: ChatMessageSender.user,
    timestamp: DateTime.now(),
    chunks: [TextChunk(type: OutputItemType.text, content: text)],
  );

  /// Convenience factory for an agent response containing one or more chunks.
  factory ChatMessage.agent(List<OutputItemBase> chunks) => ChatMessage(
    id: 'agent-${DateTime.now().millisecondsSinceEpoch}',
    sender: ChatMessageSender.agent,
    timestamp: DateTime.now(),
    chunks: chunks,
  );
}
