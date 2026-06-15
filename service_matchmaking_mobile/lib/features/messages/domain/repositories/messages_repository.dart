import '../entities/chat_message.dart';
import '../entities/conversation.dart';

abstract class MessagesRepository {
  Stream<bool> get connectionStatus;
  Future<String> startConversation(String requestId, String recipientId);
  Future<List<Conversation>> getConversations({String? currentUserId});
  Future<List<ChatMessage>> getHistory(String roomId);
  Future<void> sendMessage({required String roomId, required String content});
  Future<void> markAsRead(String roomId);
  Stream<ChatMessage> watchRoom(String roomId);
  Future<void> disconnectRoom();
}
