import 'package:equatable/equatable.dart';

import '../../domain/entities/chat_message.dart';
import '../../domain/entities/conversation.dart';

enum MessagesStatus { initial, loading, success, failure }

class MessagesState extends Equatable {
  const MessagesState({
    this.status = MessagesStatus.initial,
    this.conversations = const [],
    this.activeRoomId,
    this.messagesByRoom = const {},
    this.isSocketConnected = false,
    this.errorMessage,
    this.currentUserId,
  });

  final MessagesStatus status;
  final List<Conversation> conversations;
  final String? activeRoomId;
  final Map<String, List<ChatMessage>> messagesByRoom;
  final bool isSocketConnected;
  final String? errorMessage;
  final String? currentUserId;

  List<ChatMessage> get activeMessages =>
      activeRoomId == null ? const [] : (messagesByRoom[activeRoomId] ?? const []);

  MessagesState copyWith({
    MessagesStatus? status,
    List<Conversation>? conversations,
    String? activeRoomId,
    Map<String, List<ChatMessage>>? messagesByRoom,
    bool? isSocketConnected,
    String? errorMessage,
    String? currentUserId,
  }) {
    return MessagesState(
      status: status ?? this.status,
      conversations: conversations ?? this.conversations,
      activeRoomId: activeRoomId ?? this.activeRoomId,
      messagesByRoom: messagesByRoom ?? this.messagesByRoom,
      isSocketConnected: isSocketConnected ?? this.isSocketConnected,
      errorMessage: errorMessage,
      currentUserId: currentUserId ?? this.currentUserId,
    );
  }

  @override
  List<Object?> get props => [
        status,
        conversations,
        activeRoomId,
        messagesByRoom,
        isSocketConnected,
        errorMessage,
        currentUserId,
      ];
}
