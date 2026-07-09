import 'package:equatable/equatable.dart';

class ReplyPreview extends Equatable {
  const ReplyPreview({
    required this.id,
    required this.senderId,
    required this.content,
    this.mediaType,
  });

  final String id;
  final String senderId;
  final String content;
  final String? mediaType;

  @override
  List<Object?> get props => [id, senderId, content, mediaType];
}

class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.isRead = false,
    this.mediaUrl,
    this.mediaType,
    this.audioDurationSeconds,
    this.replyTo,
    this.isDeleted = false,
    this.editedAt,
    this.reactions = const {},
  });

  final String id;
  final String roomId;
  final String senderId;
  final String content;
  final DateTime createdAt;
  final bool isRead;
  final String? mediaUrl;
  final String? mediaType;
  final double? audioDurationSeconds;
  final ReplyPreview? replyTo;
  final bool isDeleted;
  final DateTime? editedAt;

  /// emoji -> liste des ids utilisateurs ayant reagi avec cet emoji.
  final Map<String, List<String>> reactions;

  bool get isVoice => mediaType == 'audio';

  ChatMessage copyWith({
    bool? isRead,
    String? content,
    bool? isDeleted,
    String? mediaUrl,
    DateTime? editedAt,
    Map<String, List<String>>? reactions,
  }) {
    return ChatMessage(
      id: id,
      roomId: roomId,
      senderId: senderId,
      content: content ?? this.content,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaType: mediaType,
      audioDurationSeconds: audioDurationSeconds,
      replyTo: replyTo,
      isDeleted: isDeleted ?? this.isDeleted,
      editedAt: editedAt ?? this.editedAt,
      reactions: reactions ?? this.reactions,
    );
  }

  @override
  List<Object?> get props => [
        id,
        roomId,
        senderId,
        content,
        createdAt,
        isRead,
        mediaUrl,
        mediaType,
        audioDurationSeconds,
        replyTo,
        isDeleted,
        editedAt,
        reactions,
      ];
}
