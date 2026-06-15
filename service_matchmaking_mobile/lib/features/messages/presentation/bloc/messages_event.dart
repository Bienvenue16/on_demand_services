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
  const MessagesSocketReceived(this.id, this.roomId, this.senderId, this.content, this.createdAt);

  final String id;
  final String roomId;
  final String senderId;
  final String content;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, roomId, senderId, content, createdAt];
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
