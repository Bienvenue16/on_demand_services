import 'package:equatable/equatable.dart';

class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.isRead = false,
  });

  final String id;
  final String roomId;
  final String senderId;
  final String content;
  final DateTime createdAt;
  final bool isRead;

  @override
  List<Object?> get props => [id, roomId, senderId, content, createdAt, isRead];
}
