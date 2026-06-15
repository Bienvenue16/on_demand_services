import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/repositories/messages_repository.dart';

class MessagesRepositoryImpl implements MessagesRepository {
  MessagesRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;
  final Map<String, Map<String, String?>> _userPreviewCache = {};
  final Map<String, Map<String, String?>> _requestPreviewCache = {};

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _socketSubscription;
  final StreamController<ChatMessage> _controller =
      StreamController<ChatMessage>.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  @override
  Stream<bool> get connectionStatus => _connectionController.stream;

  @override
  Future<String> startConversation(String requestId, String recipientId) async {
    final response = await _apiClient.post(
      '/messages/room',
      data: {
        'request_id': requestId,
        'other_user_id': recipientId,
      },
    );

    final roomId = (response['room_id'] ?? response['roomId'] ?? '').toString();
    if (roomId.isEmpty) {
      throw Exception('Impossible de résoudre la conversation.');
    }
    return roomId;
  }

  @override
  Future<List<Conversation>> getConversations({String? currentUserId}) async {
    final rawItems = await _apiClient.getList('/messages/conversations');
    final conversations = rawItems
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (item) {
            final roomId = (item['room_id'] ?? item['roomId'] ?? '').toString();
            final requestMap = item['request'];
            final requestId = requestMap is Map<dynamic, dynamic>
                ? (requestMap['id'] ?? requestMap['_id'] ?? _extractRequestId(roomId)).toString()
                : _extractRequestId(roomId);
            return Conversation(
              roomId: roomId,
              requestId: requestId,
              otherUserId: _extractOtherUserId(item, roomId: roomId, currentUserId: currentUserId),
              otherUserName: _extractOtherUserName(item),
              otherUserAvatarUrl: _extractOtherUserAvatarUrl(item),
              lastMessage: _extractLastMessage(item),
              requestTitle: _extractRequestTitle(item),
              unreadCount: int.tryParse((item['unread_count'] ?? 0).toString()) ?? 0,
            );
          },
        )
        .where((conv) => conv.roomId.isNotEmpty)
        .toList();

    return _enrichConversationsWithPreview(conversations);
  }

  @override
  Future<List<ChatMessage>> getHistory(String roomId) async {
    final data = await _apiClient.get('/messages/$roomId/history', query: {
      'page': 1,
      'limit': 50,
    });

    final dynamic rawItems = data['data'] ?? data['items'] ?? <dynamic>[];
    return (rawItems is List ? rawItems : <dynamic>[])
        .whereType<Map<dynamic, dynamic>>()
        .map((item) => _mapMessage(item, roomId: roomId))
        .toList();
  }

  @override
  Future<void> sendMessage({
    required String roomId,
    required String content,
  }) async {
    await _apiClient.post('/messages/$roomId', data: {'content': content});
  }

  @override
  Future<void> markAsRead(String roomId) async {
    await _apiClient.patch('/messages/$roomId/read');
  }

  @override
  Stream<ChatMessage> watchRoom(String roomId) {
    _connect(roomId);
    return _controller.stream;
  }

  void _connect(String roomId) {
    unawaited(disconnectRoom());
    _safeEmitConnection(false);

    _apiClient.getAccessToken().then((token) {
      if (token == null || token.isEmpty) return;

      final wsUri = _buildWsUri(roomId, token);
      _channel = WebSocketChannel.connect(wsUri);
      _safeEmitConnection(true);
      _socketSubscription = _channel!.stream.listen(
        (event) {
          try {
            final payload = event is String ? jsonDecode(event) : event;
            if (payload is Map<String, dynamic>) {
              _controller.add(_mapMessage(payload, roomId: roomId));
            }
          } catch (_) {
            // Ignore malformed websocket payloads.
          }
        },
        onDone: () => _safeEmitConnection(false),
        onError: (_) => _safeEmitConnection(false),
      );
    });
  }

  Uri _buildWsUri(String roomId, String token) {
    final baseUri = Uri.parse(_apiClient.baseUrl);
    final wsScheme = baseUri.scheme == 'https' ? 'wss' : 'ws';

    return Uri(
      scheme: wsScheme,
      host: baseUri.host,
      port: baseUri.hasPort ? baseUri.port : null,
      path: '/ws/chat/$roomId',
      queryParameters: {'token': token},
    );
  }

  @override
  Future<void> disconnectRoom() async {
    await _socketSubscription?.cancel();
    _socketSubscription = null;
    await _channel?.sink.close();
    _channel = null;
    _safeEmitConnection(false);
  }

  void _safeEmitConnection(bool connected) {
    if (!_connectionController.isClosed) {
      _connectionController.add(connected);
    }
  }

  Future<List<Conversation>> _enrichConversationsWithPreview(
    List<Conversation> conversations,
  ) async {
    if (conversations.isEmpty) {
      return conversations;
    }

    final enriched = await Future.wait(
      conversations.map((conversation) async {
        final needsUserPreview =
            conversation.otherUserName.isEmpty || conversation.otherUserAvatarUrl == null;
        final needsRequestPreview =
            conversation.requestTitle == null || conversation.requestTitle!.trim().isEmpty;
        final userPreview = needsUserPreview && conversation.otherUserId.isNotEmpty
            ? await _fetchUserPreview(conversation.otherUserId)
            : const <String, String?>{};
        final requestPreview = needsRequestPreview && conversation.requestId.isNotEmpty
            ? await _fetchRequestPreview(conversation.requestId)
            : const <String, String?>{};

        return Conversation(
          roomId: conversation.roomId,
          requestId: conversation.requestId,
          otherUserId: conversation.otherUserId,
          otherUserName: conversation.otherUserName.isNotEmpty
              ? conversation.otherUserName
              : (userPreview['fullName'] ?? 'Utilisateur'),
          otherUserAvatarUrl: conversation.otherUserAvatarUrl ?? userPreview['avatarUrl'],
          lastMessage: conversation.lastMessage,
          requestTitle: conversation.requestTitle ?? requestPreview['title'],
          unreadCount: conversation.unreadCount,
        );
      }),
    );

    return enriched;
  }

  String _extractOtherUserId(
    Map<dynamic, dynamic> item, {
    required String roomId,
    String? currentUserId,
  }) {
    final otherUser = item['other_user'];
    if (otherUser is Map<dynamic, dynamic>) {
      final directId = (otherUser['id'] ?? otherUser['_id'] ?? '').toString();
      if (directId.isNotEmpty) {
        return directId;
      }
    }

    final parsed = _extractParticipantIdFromRoomId(
      roomId,
      currentUserId: currentUserId,
    );
    if (parsed.isNotEmpty) {
      return parsed;
    }

    return (item['other_user_id'] ?? '').toString();
  }

  String? _extractOtherUserAvatarUrl(Map<dynamic, dynamic> item) {
    final otherUser = item['other_user'];
    if (otherUser is Map<dynamic, dynamic>) {
      return _normalizeUrl(
        (otherUser['avatar_url'] ?? otherUser['avatar'])?.toString(),
      );
    }
    return _normalizeUrl((item['other_user_avatar_url'] ?? item['other_user_avatar'])?.toString());
  }

  String _extractOtherUserName(Map<dynamic, dynamic> item) {
    final otherUser = item['other_user'];
    if (otherUser is Map<dynamic, dynamic>) {
      return (otherUser['full_name'] ?? 'Utilisateur').toString();
    }
    return (item['other_user_name'] ?? 'Utilisateur').toString();
  }

  String _extractRequestId(String roomId) {
    final parts = roomId.split('_').where((part) => part.isNotEmpty).toList();
    if (parts.length >= 3) {
      return parts.first;
    }
    return (parts.isNotEmpty && parts.length > 2) ? parts.first : '';
  }

  String _extractParticipantIdFromRoomId(
    String roomId, {
    String? currentUserId,
  }) {
    final parts = roomId.split('_').where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) {
      return '';
    }

    final participantParts = parts.length >= 3 ? parts.sublist(1) : parts;
    if (participantParts.isEmpty) {
      return '';
    }

    if (currentUserId != null && currentUserId.isNotEmpty) {
      for (final participantId in participantParts) {
        if (participantId != currentUserId) {
          return participantId;
        }
      }
    }

    return participantParts.first;
  }

  String? _extractRequestTitle(Map<dynamic, dynamic> item) {
    final request = item['request'];
    if (request is Map<dynamic, dynamic>) {
      return (request['title'] ?? request['name'])?.toString();
    }
    return item['request_title']?.toString();
  }

  Future<Map<String, String?>> _fetchUserPreview(String userId) async {
    final cached = _userPreviewCache[userId];
    if (cached != null) {
      return cached;
    }

    try {
      final data = await _apiClient.get('/users/$userId');
      final preview = <String, String?>{
        'fullName': (data['full_name'] ?? data['fullName'] ?? 'Utilisateur').toString(),
        'avatarUrl': _normalizeUrl((data['avatar_url'] ?? data['avatar'])?.toString()),
      };
      _userPreviewCache[userId] = preview;
      return preview;
    } catch (_) {
      return const {};
    }
  }

  Future<Map<String, String?>> _fetchRequestPreview(String requestId) async {
    final cached = _requestPreviewCache[requestId];
    if (cached != null) {
      return cached;
    }

    try {
      final data = await _apiClient.get('/requests/$requestId');
      final preview = <String, String?>{
        'title': (data['title'] ?? data['request_title'] ?? '').toString(),
      };
      _requestPreviewCache[requestId] = preview;
      return preview;
    } catch (_) {
      return const {};
    }
  }

  String? _normalizeUrl(String? url) {
    final value = url?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    return value;
  }

  String? _extractLastMessage(Map<dynamic, dynamic> item) {
    final last = item['last_message'];
    if (last is Map<dynamic, dynamic>) {
      return last['content']?.toString();
    }
    return item['last_message']?.toString();
  }

  ChatMessage _mapMessage(Map<dynamic, dynamic> item, {required String roomId}) {
    return ChatMessage(
      id: (item['id'] ?? item['_id'] ?? DateTime.now().microsecondsSinceEpoch.toString())
          .toString(),
      roomId: (item['room_id'] ?? roomId).toString(),
      senderId: (item['sender_id'] ?? '').toString(),
      content: (item['content'] ?? '').toString(),
      createdAt: DateTime.tryParse((item['created_at'] ?? item['timestamp'] ?? '').toString()) ??
          DateTime.now(),
      isRead: item['is_read'] == true,
    );
  }

  Future<void> dispose() async {
    await disconnectRoom();
    await _connectionController.close();
    await _controller.close();
  }
}
