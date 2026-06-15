import 'package:equatable/equatable.dart';

class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    this.targetRequestId,
    this.targetRoomId,
    this.createdAt,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final bool isRead;
  final String? targetRequestId;
  final String? targetRoomId;
  final DateTime? createdAt;

  @override
  List<Object?> get props => [
        id,
        type,
        title,
        body,
        isRead,
        targetRequestId,
        targetRoomId,
        createdAt,
      ];
}
