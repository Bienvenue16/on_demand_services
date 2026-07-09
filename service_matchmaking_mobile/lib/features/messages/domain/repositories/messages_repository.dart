import '../entities/chat_message.dart';
import '../entities/conversation.dart';

/// Evenement "l'autre participant est en train d'ecrire".
typedef TypingEvent = ({String senderId, bool isTyping});

/// Evenement de mise a jour d'un message existant (edition/suppression/reaction).
typedef MessageUpdateEvent = ({
  String roomId,
  String messageId,
  String type, // 'edited' | 'deleted' | 'reaction'
  String? content,
  Map<String, List<String>>? reactions,
});

abstract class MessagesRepository {
  Stream<bool> get connectionStatus;
  Stream<TypingEvent> get typingEvents;
  Stream<String> get readEvents;
  Stream<MessageUpdateEvent> get messageUpdates;

  Future<String> startConversation(String requestId, String recipientId);
  Future<List<Conversation>> getConversations({String? currentUserId});
  Future<List<ChatMessage>> getHistory(String roomId);
  Future<ChatMessage> sendMessage({
    required String roomId,
    required String content,
    String? mediaUrl,
    String? mediaType,
    double? audioDurationSeconds,
    String? replyToId,
  });
  Future<String?> uploadChatImage(String filePath);
  Future<String?> uploadVoiceMessage(String filePath);
  Future<void> sendTyping(String roomId, bool isTyping);
  Future<void> markAsRead(String roomId);
  Future<void> editMessage(String messageId, String content);
  Future<void> deleteMessage(String messageId);
  Future<void> toggleReaction(String messageId, String emoji);
  Stream<ChatMessage> watchRoom(String roomId);
  Future<void> disconnectRoom();
}
