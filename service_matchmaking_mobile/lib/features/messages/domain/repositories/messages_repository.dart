import '../entities/chat_message.dart';
import '../entities/conversation.dart';

/// Evenement "l'autre participant est en train d'ecrire".
typedef TypingEvent = ({String senderId, bool isTyping});

abstract class MessagesRepository {
  Stream<bool> get connectionStatus;
  Stream<TypingEvent> get typingEvents;
  Stream<String> get readEvents;
  Future<String> startConversation(String requestId, String recipientId);
  Future<List<Conversation>> getConversations({String? currentUserId});
  Future<List<ChatMessage>> getHistory(String roomId);
  Future<ChatMessage> sendMessage({
    required String roomId,
    required String content,
    String? mediaUrl,
  });
  Future<String?> uploadChatImage(String filePath);
  Future<void> sendTyping(String roomId, bool isTyping);
  Future<void> markAsRead(String roomId);
  Stream<ChatMessage> watchRoom(String roomId);
  Future<void> disconnectRoom();
}
