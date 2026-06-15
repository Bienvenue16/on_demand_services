import '../entities/app_notification.dart';

abstract class NotificationsRepository {
  Future<List<AppNotification>> getNotifications();
  Future<int> getUnreadCount();
  Future<void> markAsRead(String notificationId);
  Future<void> markAllAsRead();
}
