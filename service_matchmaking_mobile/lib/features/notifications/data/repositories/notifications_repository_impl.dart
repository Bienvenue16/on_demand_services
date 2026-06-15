import '../../../../core/network/api_client.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notifications_repository.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  NotificationsRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<AppNotification>> getNotifications() async {
    final data = await _apiClient.get('/notifications', query: {
      'page': 1,
      'limit': 100,
    });

    final dynamic rawItems = data['data'] ?? data['items'] ?? <dynamic>[];
    return (rawItems is List ? rawItems : <dynamic>[])
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (item) => AppNotification(
            id: (item['id'] ?? item['_id'] ?? '').toString(),
            type: (item['type'] ?? 'info').toString(),
            title: (item['title'] ?? '').toString(),
            body: (item['body'] ?? item['message'] ?? '').toString(),
            isRead: item['is_read'] == true,
            targetRequestId: _extractRequestId(item),
            targetRoomId: _extractRoomId(item),
            createdAt: DateTime.tryParse((item['created_at'] ?? '').toString()),
          ),
        )
        .toList();
  }

  String? _extractRequestId(Map<dynamic, dynamic> item) {
    final direct = (item['request_id'] ?? item['requestId'])?.toString();
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }

    final data = item['data'];
    if (data is Map<dynamic, dynamic>) {
      final nested = (data['request_id'] ?? data['requestId'])?.toString();
      if (nested != null && nested.isNotEmpty) {
        return nested;
      }
    }
    return null;
  }

  String? _extractRoomId(Map<dynamic, dynamic> item) {
    final direct = (item['room_id'] ?? item['roomId'])?.toString();
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }

    final data = item['data'];
    if (data is Map<dynamic, dynamic>) {
      final nested = (data['room_id'] ?? data['roomId'])?.toString();
      if (nested != null && nested.isNotEmpty) {
        return nested;
      }
    }
    return null;
  }

  @override
  Future<int> getUnreadCount() async {
    final data = await _apiClient.get('/notifications/unread-count');
    return int.tryParse((data['count'] ?? 0).toString()) ?? 0;
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    await _apiClient.patch('/notifications/$notificationId/read');
  }

  @override
  Future<void> markAllAsRead() async {
    await _apiClient.patch('/notifications/read-all');
  }
}
