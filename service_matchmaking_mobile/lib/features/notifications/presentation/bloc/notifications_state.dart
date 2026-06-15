import 'package:equatable/equatable.dart';

import '../../domain/entities/app_notification.dart';

enum NotificationsStatus { initial, loading, success, failure }

class NotificationsState extends Equatable {
  const NotificationsState({
    this.status = NotificationsStatus.initial,
    this.notifications = const [],
    this.unreadCount = 0,
    this.errorMessage,
  });

  final NotificationsStatus status;
  final List<AppNotification> notifications;
  final int unreadCount;
  final String? errorMessage;

  NotificationsState copyWith({
    NotificationsStatus? status,
    List<AppNotification>? notifications,
    int? unreadCount,
    String? errorMessage,
  }) {
    return NotificationsState(
      status: status ?? this.status,
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, notifications, unreadCount, errorMessage];
}
