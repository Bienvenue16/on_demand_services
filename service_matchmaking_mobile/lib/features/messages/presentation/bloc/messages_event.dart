import 'package:equatable/equatable.dart';

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
  const MessagesSendRequested({required this.roomId, required this.content});

  final String roomId;
  final String content;

  @override
  List<Object?> get props => [roomId, content];
}

final class MessagesSocketReceived extends MessagesEvent {
  const MessagesSocketReceived(
    this.id,
    this.roomId,
    this.senderId,
    this.content,
    this.createdAt, {
    this.mediaUrl,
  });

  final String id;
  final String roomId;
  final String senderId;
  final String content;
  final DateTime createdAt;
  final String? mediaUrl;

  @override
  List<Object?> get props => [id, roomId, senderId, content, createdAt, mediaUrl];
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
  const MessagesImageSendRequested({required this.roomId, required this.filePath});

  final String roomId;
  final String filePath;

  @override
  List<Object?> get props => [roomId, filePath];
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
