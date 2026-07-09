import 'package:equatable/equatable.dart';

import '../../domain/entities/chat_message.dart';

sealed class MessagesEvent extends Equatable {
  const MessagesEvent();

  @override
  List<Object?> get props => [];
}

final class MessagesStarted extends MessagesEvent {
  const MessagesStarted({this.initialRoomId, this.currentUserId});

  final String? initialRoomId;
  final String? currentUserId;

  @override
  List<Object?> get props => [initialRoomId, currentUserId];
}

final class MessagesConversationOpened extends MessagesEvent {
  const MessagesConversationOpened(this.roomId);

  final String roomId;

  @override
  List<Object?> get props => [roomId];
}

final class MessagesSendRequested extends MessagesEvent {
  const MessagesSendRequested({
    required this.roomId,
    required this.content,
    this.replyToId,
  });

  final String roomId;
  final String content;
  final String? replyToId;

  @override
  List<Object?> get props => [roomId, content, replyToId];
}

final class MessagesSocketReceived extends MessagesEvent {
  const MessagesSocketReceived(this.message);

  final ChatMessage message;

  @override
  List<Object?> get props => [message];
}

final class MessagesConnectionChanged extends MessagesEvent {
  const MessagesConnectionChanged(this.isConnected);

  final bool isConnected;

  @override
  List<Object?> get props => [isConnected];
}

final class MessagesReconnectRequested extends MessagesEvent {
  const MessagesReconnectRequested();
}

final class MessagesImageSendRequested extends MessagesEvent {
  const MessagesImageSendRequested({
    required this.roomId,
    required this.filePath,
    this.replyToId,
  });

  final String roomId;
  final String filePath;
  final String? replyToId;

  @override
  List<Object?> get props => [roomId, filePath, replyToId];
}

final class MessagesVoiceSendRequested extends MessagesEvent {
  const MessagesVoiceSendRequested({
    required this.roomId,
    required this.filePath,
    required this.durationSeconds,
    this.replyToId,
  });

  final String roomId;
  final String filePath;
  final double durationSeconds;
  final String? replyToId;

  @override
  List<Object?> get props => [roomId, filePath, durationSeconds, replyToId];
}

/// Selectionne (ou annule, si null) le message auquel on est en train de repondre.
final class MessagesReplyToRequested extends MessagesEvent {
  const MessagesReplyToRequested(this.message);

  final ChatMessage? message;

  @override
  List<Object?> get props => [message];
}

final class MessagesEditRequested extends MessagesEvent {
  const MessagesEditRequested({required this.messageId, required this.content});

  final String messageId;
  final String content;

  @override
  List<Object?> get props => [messageId, content];
}

final class MessagesDeleteRequested extends MessagesEvent {
  const MessagesDeleteRequested(this.messageId);

  final String messageId;

  @override
  List<Object?> get props => [messageId];
}

final class MessagesReactionToggled extends MessagesEvent {
  const MessagesReactionToggled({required this.messageId, required this.emoji});

  final String messageId;
  final String emoji;

  @override
  List<Object?> get props => [messageId, emoji];
}

/// Recu depuis le WebSocket : un message existant a ete edite/supprime/reagi.
final class MessagesUpdateReceived extends MessagesEvent {
  const MessagesUpdateReceived({
    required this.roomId,
    required this.messageId,
    required this.updateType,
    this.content,
    this.reactions,
  });

  final String roomId;
  final String messageId;
  final String updateType;
  final String? content;
  final Map<String, List<String>>? reactions;

  @override
  List<Object?> get props => [roomId, messageId, updateType, content, reactions];
}

/// Declenche depuis le composer local pour signaler (ou arreter de signaler) qu'on ecrit.
final class MessagesTypingRequested extends MessagesEvent {
  const MessagesTypingRequested(this.isTyping);

  final bool isTyping;

  @override
  List<Object?> get props => [isTyping];
}

/// Recu depuis le WebSocket : l'autre participant ecrit (ou a arrete d'ecrire).
final class MessagesTypingReceived extends MessagesEvent {
  const MessagesTypingReceived(this.senderId, this.isTyping);

  final String senderId;
  final bool isTyping;

  @override
  List<Object?> get props => [senderId, isTyping];
}

/// Recu depuis le WebSocket : quelqu'un a lu les messages du salon actif.
final class MessagesReadReceiptReceived extends MessagesEvent {
  const MessagesReadReceiptReceived(this.readerId);

  final String readerId;

  @override
  List<Object?> get props => [readerId];
}

/// Tire-pour-rafraichir sur la liste des conversations.
final class MessagesConversationsRefreshRequested extends MessagesEvent {
  const MessagesConversationsRefreshRequested();
}

/// Tire-pour-rafraichir sur l'historique de la conversation ouverte.
final class MessagesHistoryRefreshRequested extends MessagesEvent {
  const MessagesHistoryRefreshRequested(this.roomId);

  final String roomId;

  @override
  List<Object?> get props => [roomId];
}
