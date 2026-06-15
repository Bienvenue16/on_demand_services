import 'package:equatable/equatable.dart';

sealed class NotificationsEvent extends Equatable {
  const NotificationsEvent();

  @override
  List<Object?> get props => [];
}

final class NotificationsStarted extends NotificationsEvent {
  const NotificationsStarted();
}

final class NotificationsMarkOneRead extends NotificationsEvent {
  const NotificationsMarkOneRead(this.notificationId);

  final String notificationId;

  @override
  List<Object?> get props => [notificationId];
}

final class NotificationsMarkAllRead extends NotificationsEvent {
  const NotificationsMarkAllRead();
}
