import 'package:equatable/equatable.dart';

class Conversation extends Equatable {
  const Conversation({
    required this.roomId,
    required this.requestId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatarUrl,
    this.lastMessage,
    this.requestTitle,
    this.unreadCount = 0,
  });

  final String roomId;
  final String requestId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatarUrl;
  final String? lastMessage;
  final String? requestTitle;
  final int unreadCount;

  @override
  List<Object?> get props => [
        roomId,
        requestId,
        otherUserId,
        otherUserName,
        otherUserAvatarUrl,
        lastMessage,
        requestTitle,
        unreadCount,
      ];
}
