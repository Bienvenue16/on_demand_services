import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
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
  String? _activeRoomId;
  Timer? _reconnectTimer;
  static const _reconnectDelay = Duration(seconds: 3);
  final StreamController<ChatMessage> _controller =
      StreamController<ChatMessage>.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  final StreamController<TypingEvent> _typingController =
      StreamController<TypingEvent>.broadcast();
  final StreamController<String> _readController =
      StreamController<String>.broadcast();
  final StreamController<MessageUpdateEvent> _updatesController =
      StreamController<MessageUpdateEvent>.broadcast();

  @override
  Stream<bool> get connectionStatus => _connectionController.stream;

  @override
  Stream<TypingEvent> get typingEvents => _typingController.stream;

  @override
  Stream<String> get readEvents => _readController.stream;

  @override
  Stream<MessageUpdateEvent> get messageUpdates => _updatesController.stream;

  @override
  Future<String> startConversation(String requestId, String recipientId) async {
    final response = await _apiClient.post(
      '/messages/room',
      data: {'request_id': requestId, 'other_user_id': recipientId},
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
        .map((item) {
          final roomId = (item['room_id'] ?? item['roomId'] ?? '').toString();
          final requestMap = item['request'];
          final requestId = requestMap is Map<dynamic, dynamic>
              ? (requestMap['id'] ??
                        requestMap['_id'] ??
                        _extractRequestId(roomId))
                    .toString()
              : _extractRequestId(roomId);
          return Conversation(
            roomId: roomId,
            requestId: requestId,
            otherUserId: _extractOtherUserId(
              item,
              roomId: roomId,
              currentUserId: currentUserId,
            ),
            otherUserName: _extractOtherUserName(item),
            otherUserAvatarUrl: _extractOtherUserAvatarUrl(item),
            lastMessage: _extractLastMessage(item),
            requestTitle: _extractRequestTitle(item),
            unreadCount:
                int.tryParse((item['unread_count'] ?? 0).toString()) ?? 0,
          );
        })
        .where((conv) => conv.roomId.isNotEmpty)
        .toList();

    return _enrichConversationsWithPreview(conversations);
  }

  @override
  Future<List<ChatMessage>> getHistory(String roomId) async {
    final data = await _apiClient.get(
      '/messages/$roomId/history',
      query: {'page': 1, 'limit': 50},
    );

    final dynamic rawItems = data['data'] ?? data['items'] ?? <dynamic>[];
    // Le backend trie par date decroissante (le plus recent d'abord) pour la
    // pagination ; l'app affiche par contre l'historique du plus ancien au
    // plus recent (comme les nouveaux messages temps reel qui s'ajoutent a la
    // fin), donc on remet la page dans l'ordre chronologique ici.
    final messages = (rawItems is List ? rawItems : <dynamic>[])
        .whereType<Map<dynamic, dynamic>>()
        .map((item) => _mapMessage(item, roomId: roomId))
        .toList();
    return messages.reversed.toList();
  }

  @override
  Future<ChatMessage> sendMessage({
    required String roomId,
    required String content,
    String? mediaUrl,
    String? mediaType,
    double? audioDurationSeconds,
    String? replyToId,
  }) async {
    final data = await _apiClient.post(
      '/messages/$roomId',
      data: {
        'content': content,
        if (mediaUrl != null && mediaUrl.isNotEmpty) 'media_url': mediaUrl,
        if (mediaType != null && mediaType.isNotEmpty) 'media_type': mediaType,
        if (audioDurationSeconds != null)
          'audio_duration_seconds': audioDurationSeconds,
        if (replyToId != null && replyToId.isNotEmpty) 'reply_to_id': replyToId,
      },
    );
    return _mapMessage(data, roomId: roomId);
  }

  @override
  Future<String?> uploadChatImage(String filePath) async {
    final data = await _apiClient.postMultipart(
      '/uploads/image',
      data: FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
        'file_type': 'message',
      }),
    );
    final raw = (data['url'] ?? data['file_url'] ?? data['path'])?.toString();
    return _normalizeUrl(raw);
  }

  @override
  Future<String?> uploadVoiceMessage(String filePath) async {
    final data = await _apiClient.postMultipart(
      '/uploads/image',
      data: FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
        'file_type': 'voice',
      }),
    );
    final raw = (data['url'] ?? data['file_url'] ?? data['path'])?.toString();
    return _normalizeUrl(raw);
  }

  @override
  Future<void> editMessage(String messageId, String content) async {
    await _apiClient.patch(
      '/messages/message/$messageId',
      data: {'content': content},
    );
  }

  @override
  Future<void> deleteMessage(String messageId) async {
    await _apiClient.delete('/messages/message/$messageId');
  }

  @override
  Future<void> toggleReaction(String messageId, String emoji) async {
    await _apiClient.post(
      '/messages/message/$messageId/react',
      data: {'emoji': emoji},
    );
  }

  @override
  Future<void> sendTyping(String roomId, bool isTyping) async {
    final channel = _channel;
    if (channel == null) return;
    try {
      channel.sink.add(jsonEncode({'type': 'typing', 'is_typing': isTyping}));
    } catch (_) {
      // Le statut de frappe est un bonus best-effort : on ignore les erreurs d'envoi.
    }
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
    _activeRoomId = roomId;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    unawaited(_closeChannel());
    _safeEmitConnection(false);

    _apiClient.getAccessToken().then((token) {
      // Le salon a change ou ete ferme entre-temps : cette tentative est perimee.
      if (_activeRoomId != roomId) return;
      if (token == null || token.isEmpty) return;

      try {
        final wsUri = _buildWsUri(roomId, token);
        _channel = WebSocketChannel.connect(wsUri);
        _safeEmitConnection(true);
        _socketSubscription = _channel!.stream.listen(
          (event) {
            try {
              final payload = event is String ? jsonDecode(event) : event;
              if (payload is! Map<String, dynamic>) return;

              switch (payload['type']?.toString() ?? 'text') {
                case 'typing':
                  _typingController.add((
                    senderId: (payload['sender_id'] ?? '').toString(),
                    isTyping: payload['is_typing'] == true,
                  ));
                  break;
                case 'read':
                  _readController.add((payload['reader_id'] ?? '').toString());
                  break;
                case 'message_edited':
                  _updatesController.add((
                    roomId: (payload['room_id'] ?? roomId).toString(),
                    messageId: (payload['message_id'] ?? '').toString(),
                    type: 'edited',
                    content: payload['content']?.toString(),
                    reactions: null,
                  ));
                  break;
                case 'message_deleted':
                  _updatesController.add((
                    roomId: (payload['room_id'] ?? roomId).toString(),
                    messageId: (payload['message_id'] ?? '').toString(),
                    type: 'deleted',
                    content: null,
                    reactions: null,
                  ));
                  break;
                case 'reaction_updated':
                  _updatesController.add((
                    roomId: (payload['room_id'] ?? roomId).toString(),
                    messageId: (payload['message_id'] ?? '').toString(),
                    type: 'reaction',
                    content: null,
                    reactions: _parseReactions(payload['reactions']),
                  ));
                  break;
                default:
                  _controller.add(_mapMessage(payload, roomId: roomId));
              }
            } catch (_) {
              // Ignore malformed websocket payloads.
            }
          },
          onDone: () => _handleDisconnected(roomId),
          onError: (_) => _handleDisconnected(roomId),
        );
      } catch (_) {
        _handleDisconnected(roomId);
      }
    });
  }

  /// Reagit a une coupure (volontaire ou non) du canal WebSocket : si le salon
  /// est toujours celui suivi activement, planifie une reconnexion automatique.
  void _handleDisconnected(String roomId) {
    _safeEmitConnection(false);
    if (_activeRoomId != roomId) return;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () {
      if (_activeRoomId == roomId) {
        _connect(roomId);
      }
    });
  }

  Future<void> _closeChannel() async {
    await _socketSubscription?.cancel();
    _socketSubscription = null;
    await _channel?.sink.close();
    _channel = null;
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
    _activeRoomId = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _closeChannel();
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
            conversation.otherUserName.isEmpty ||
            conversation.otherUserAvatarUrl == null;
        final needsRequestPreview =
            conversation.requestTitle == null ||
            conversation.requestTitle!.trim().isEmpty;
        final userPreview =
            needsUserPreview && conversation.otherUserId.isNotEmpty
            ? await _fetchUserPreview(conversation.otherUserId)
            : const <String, String?>{};
        final requestPreview =
            needsRequestPreview && conversation.requestId.isNotEmpty
            ? await _fetchRequestPreview(conversation.requestId)
            : const <String, String?>{};

        return Conversation(
          roomId: conversation.roomId,
          requestId: conversation.requestId,
          otherUserId: conversation.otherUserId,
          otherUserName: conversation.otherUserName.isNotEmpty
              ? conversation.otherUserName
              : (userPreview['fullName'] ?? 'Utilisateur'),
          otherUserAvatarUrl:
              conversation.otherUserAvatarUrl ?? userPreview['avatarUrl'],
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
    return _normalizeUrl(
      (item['other_user_avatar_url'] ?? item['other_user_avatar'])?.toString(),
    );
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
        'fullName': (data['full_name'] ?? data['fullName'] ?? 'Utilisateur')
            .toString(),
        'avatarUrl': _normalizeUrl(
          (data['avatar_url'] ?? data['avatar'])?.toString(),
        ),
      };
      // On ne memorise durablement que si un avatar existe : sinon un compte
      // fraichement cree (sans photo au premier chargement) resterait sans
      // avatar pour le reste de la session, meme apres l'upload d'une photo.
      if (preview['avatarUrl'] != null) {
        _userPreviewCache[userId] = preview;
      }
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

  /// Corrige les URLs `localhost`/relatives renvoyees par le backend (avatars,
  /// medias) pour pointer vers l'hote reel de l'API (ex: tunnel ngrok) : sur un
  /// telephone, 'localhost' pointe vers le telephone lui-meme, pas le serveur.
  String? _normalizeUrl(String? url) {
    final value = url?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }

    final baseUri = Uri.parse(_apiClient.baseUrl);

    if (value.startsWith('http://') || value.startsWith('https://')) {
      final parsed = Uri.tryParse(value);
      if (parsed != null) {
        final host = parsed.host.toLowerCase();
        if (host == 'localhost' || host == '127.0.0.1' || host == '0.0.0.0') {
          return Uri(
            scheme: baseUri.scheme,
            host: baseUri.host,
            port: baseUri.hasPort ? baseUri.port : null,
            path: parsed.path,
            query: parsed.hasQuery ? parsed.query : null,
          ).toString();
        }
      }
      return value;
    }

    if (value.startsWith('//')) {
      return '${baseUri.scheme}:$value';
    }

    final normalizedPath = value.startsWith('/') ? value : '/$value';
    return Uri(
      scheme: baseUri.scheme,
      host: baseUri.host,
      port: baseUri.hasPort ? baseUri.port : null,
      path: normalizedPath,
    ).toString();
  }

  String? _extractLastMessage(Map<dynamic, dynamic> item) {
    final last = item['last_message'];
    if (last is Map<dynamic, dynamic>) {
      return last['content']?.toString();
    }
    return item['last_message']?.toString();
  }

  ChatMessage _mapMessage(
    Map<dynamic, dynamic> item, {
    required String roomId,
  }) {
    final replyToMap = item['reply_to'];
    return ChatMessage(
      // 'message_id' est la cle utilisee par les payloads WebSocket ; 'id'/'_id'
      // par les reponses REST. Sans ce fallback, l'anti-doublon (comparaison
      // d'id) ne matche jamais entre les deux sources et le message apparait deux fois.
      id:
          (item['id'] ??
                  item['_id'] ??
                  item['message_id'] ??
                  DateTime.now().microsecondsSinceEpoch.toString())
              .toString(),
      roomId: (item['room_id'] ?? roomId).toString(),
      senderId: (item['sender_id'] ?? '').toString(),
      content: (item['content'] ?? '').toString(),
      createdAt:
          DateTime.tryParse(
            (item['created_at'] ?? item['timestamp'] ?? '').toString(),
          ) ??
          DateTime.now(),
      isRead: item['is_read'] == true,
      mediaUrl: _normalizeUrl(item['media_url']?.toString()),
      mediaType: item['media_type']?.toString(),
      audioDurationSeconds: _toDoubleOrNull(item['audio_duration_seconds']),
      replyTo: replyToMap is Map<dynamic, dynamic>
          ? ReplyPreview(
              id: (replyToMap['id'] ?? '').toString(),
              senderId: (replyToMap['sender_id'] ?? '').toString(),
              content: (replyToMap['content'] ?? '').toString(),
              mediaType: replyToMap['media_type']?.toString(),
            )
          : null,
      isDeleted: item['is_deleted'] == true,
      editedAt: DateTime.tryParse((item['edited_at'] ?? '').toString()),
      reactions: _parseReactions(item['reactions']),
    );
  }

  Map<String, List<String>> _parseReactions(dynamic raw) {
    if (raw is! Map) return const {};
    return raw.map(
      (key, value) => MapEntry(
        key.toString(),
        value is List ? value.map((e) => e.toString()).toList() : <String>[],
      ),
    );
  }

  double? _toDoubleOrNull(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }

  Future<void> dispose() async {
    await disconnectRoom();
    await _connectionController.close();
    await _controller.close();
    await _typingController.close();
    await _readController.close();
    await _updatesController.close();
  }
}
