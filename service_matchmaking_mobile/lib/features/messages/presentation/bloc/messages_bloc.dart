import 'dart:async';

import 'package:bloc/bloc.dart';

import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/messages_repository.dart';
import 'messages_event.dart';
import 'messages_state.dart';

class MessagesBloc extends Bloc<MessagesEvent, MessagesState> {
  MessagesBloc(this._messagesRepository) : super(const MessagesState()) {
    on<MessagesStarted>(_onStarted);
    on<MessagesConversationOpened>(_onConversationOpened);
    on<MessagesSendRequested>(_onSendRequested);
    on<MessagesImageSendRequested>(_onImageSendRequested);
    on<MessagesVoiceSendRequested>(_onVoiceSendRequested);
    on<MessagesReplyToRequested>(_onReplyToRequested);
    on<MessagesEditRequested>(_onEditRequested);
    on<MessagesDeleteRequested>(_onDeleteRequested);
    on<MessagesReactionToggled>(_onReactionToggled);
    on<MessagesUpdateReceived>(_onUpdateReceived);
    on<MessagesTypingRequested>(_onTypingRequested);
    on<MessagesTypingReceived>(_onTypingReceived);
    on<MessagesReadReceiptReceived>(_onReadReceiptReceived);
    on<MessagesConversationsRefreshRequested>(_onConversationsRefreshRequested);
    on<MessagesHistoryRefreshRequested>(_onHistoryRefreshRequested);
    on<MessagesSocketReceived>(_onSocketReceived);
    on<MessagesConnectionChanged>(_onConnectionChanged);
    on<MessagesReconnectRequested>(_onReconnectRequested);
  }

  final MessagesRepository _messagesRepository;
  StreamSubscription<ChatMessage>? _roomSubscription;
  StreamSubscription<bool>? _connectionSubscription;
  StreamSubscription<TypingEvent>? _typingSubscription;
  StreamSubscription<String>? _readSubscription;
  StreamSubscription<MessageUpdateEvent>? _updatesSubscription;
  Timer? _typingTimeoutTimer;

  Future<void> _onStarted(
    MessagesStarted event,
    Emitter<MessagesState> emit,
  ) async {
    emit(
      state.copyWith(
        status: MessagesStatus.loading,
        errorMessage: null,
        currentUserId: event.currentUserId,
      ),
    );

    try {
      final conversations = await _messagesRepository.getConversations(
        currentUserId: event.currentUserId,
      );
      emit(
        state.copyWith(
          status: MessagesStatus.success,
          conversations: conversations,
          currentUserId: event.currentUserId,
        ),
      );

      final requested = event.initialRoomId?.trim();
      final hasRequested = requested != null && requested.isNotEmpty;

      if (hasRequested) {
        // Ouvrir directement la salle demandée, même si elle est nouvelle (sans historique).
        add(MessagesConversationOpened(requested));
      } else if (conversations.isNotEmpty) {
        add(MessagesConversationOpened(conversations.first.roomId));
      }
    } catch (e) {
      emit(
        state.copyWith(
          status: MessagesStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onConversationOpened(
    MessagesConversationOpened event,
    Emitter<MessagesState> emit,
  ) async {
    try {
      final messages = await _messagesRepository.getHistory(event.roomId);
      await _messagesRepository.markAsRead(event.roomId);

      final updated = Map<String, List<ChatMessage>>.from(state.messagesByRoom);
      updated[event.roomId] = messages;

      emit(
        state.copyWith(
          status: MessagesStatus.success,
          activeRoomId: event.roomId,
          messagesByRoom: updated,
          isOtherTyping: false,
          clearReplyingTo: true,
        ),
      );

      await _roomSubscription?.cancel();
      _roomSubscription = _messagesRepository.watchRoom(event.roomId).listen((incoming) {
        add(MessagesSocketReceived(incoming));
      });

      await _connectionSubscription?.cancel();
      _connectionSubscription = _messagesRepository.connectionStatus.listen((isConnected) {
        add(MessagesConnectionChanged(isConnected));
      });

      await _typingSubscription?.cancel();
      _typingSubscription = _messagesRepository.typingEvents.listen((typing) {
        add(MessagesTypingReceived(typing.senderId, typing.isTyping));
      });

      await _readSubscription?.cancel();
      _readSubscription = _messagesRepository.readEvents.listen((readerId) {
        add(MessagesReadReceiptReceived(readerId));
      });

      await _updatesSubscription?.cancel();
      _updatesSubscription = _messagesRepository.messageUpdates.listen((update) {
        add(
          MessagesUpdateReceived(
            roomId: update.roomId,
            messageId: update.messageId,
            updateType: update.type,
            content: update.content,
            reactions: update.reactions,
          ),
        );
      });
    } catch (e) {
      emit(
        state.copyWith(
          status: MessagesStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onSendRequested(
    MessagesSendRequested event,
    Emitter<MessagesState> emit,
  ) async {
    try {
      unawaited(_messagesRepository.sendTyping(event.roomId, false));
      final sent = await _messagesRepository.sendMessage(
        roomId: event.roomId,
        content: event.content,
        replyToId: event.replyToId,
      );
      _appendMessage(sent, emit);
      if (event.replyToId != null) {
        emit(state.copyWith(clearReplyingTo: true));
      }
    } catch (e) {
      emit(
        state.copyWith(
          status: MessagesStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onImageSendRequested(
    MessagesImageSendRequested event,
    Emitter<MessagesState> emit,
  ) async {
    try {
      final mediaUrl = await _messagesRepository.uploadChatImage(event.filePath);
      if (mediaUrl == null || mediaUrl.isEmpty) {
        emit(
          state.copyWith(
            status: MessagesStatus.failure,
            errorMessage: 'Echec de l\'envoi de l\'image',
          ),
        );
        return;
      }

      final sent = await _messagesRepository.sendMessage(
        roomId: event.roomId,
        content: '',
        mediaUrl: mediaUrl,
        mediaType: 'image',
        replyToId: event.replyToId,
      );
      _appendMessage(sent, emit);
      if (event.replyToId != null) {
        emit(state.copyWith(clearReplyingTo: true));
      }
    } catch (e) {
      emit(
        state.copyWith(
          status: MessagesStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onVoiceSendRequested(
    MessagesVoiceSendRequested event,
    Emitter<MessagesState> emit,
  ) async {
    try {
      final mediaUrl = await _messagesRepository.uploadVoiceMessage(event.filePath);
      if (mediaUrl == null || mediaUrl.isEmpty) {
        emit(
          state.copyWith(
            status: MessagesStatus.failure,
            errorMessage: 'Echec de l\'envoi du message vocal',
          ),
        );
        return;
      }

      final sent = await _messagesRepository.sendMessage(
        roomId: event.roomId,
        content: '',
        mediaUrl: mediaUrl,
        mediaType: 'audio',
        audioDurationSeconds: event.durationSeconds,
        replyToId: event.replyToId,
      );
      _appendMessage(sent, emit);
      if (event.replyToId != null) {
        emit(state.copyWith(clearReplyingTo: true));
      }
    } catch (e) {
      emit(
        state.copyWith(
          status: MessagesStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onReplyToRequested(
    MessagesReplyToRequested event,
    Emitter<MessagesState> emit,
  ) async {
    if (event.message == null) {
      emit(state.copyWith(clearReplyingTo: true));
    } else {
      emit(state.copyWith(replyingTo: event.message));
    }
  }

  Future<void> _onEditRequested(
    MessagesEditRequested event,
    Emitter<MessagesState> emit,
  ) async {
    final roomId = state.activeRoomId;
    if (roomId == null) return;

    // Optimiste : on applique tout de suite localement, sans attendre le serveur.
    _updateMessage(roomId, event.messageId, emit, (m) => m.copyWith(content: event.content));

    try {
      await _messagesRepository.editMessage(event.messageId, event.content);
    } catch (e) {
      emit(
        state.copyWith(
          status: MessagesStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onDeleteRequested(
    MessagesDeleteRequested event,
    Emitter<MessagesState> emit,
  ) async {
    final roomId = state.activeRoomId;
    if (roomId == null) return;

    _updateMessage(
      roomId,
      event.messageId,
      emit,
      (m) => m.copyWith(isDeleted: true, content: '', mediaUrl: null),
    );

    try {
      await _messagesRepository.deleteMessage(event.messageId);
    } catch (e) {
      emit(
        state.copyWith(
          status: MessagesStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onReactionToggled(
    MessagesReactionToggled event,
    Emitter<MessagesState> emit,
  ) async {
    final roomId = state.activeRoomId;
    if (roomId == null) return;
    final currentUserId = state.currentUserId;

    // Optimiste : bascule immediate cote local, en attendant la confirmation serveur.
    _updateMessage(roomId, event.messageId, emit, (m) {
      final reactions = Map<String, List<String>>.from(
        m.reactions.map((key, value) => MapEntry(key, [...value])),
      );
      final users = reactions[event.emoji] ?? <String>[];
      if (currentUserId != null && users.contains(currentUserId)) {
        users.remove(currentUserId);
      } else if (currentUserId != null) {
        users.add(currentUserId);
      }
      if (users.isEmpty) {
        reactions.remove(event.emoji);
      } else {
        reactions[event.emoji] = users;
      }
      return m.copyWith(reactions: reactions);
    });

    try {
      await _messagesRepository.toggleReaction(event.messageId, event.emoji);
    } catch (e) {
      emit(
        state.copyWith(
          status: MessagesStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onUpdateReceived(
    MessagesUpdateReceived event,
    Emitter<MessagesState> emit,
  ) async {
    switch (event.updateType) {
      case 'edited':
        _updateMessage(
          event.roomId,
          event.messageId,
          emit,
          (m) => m.copyWith(content: event.content ?? m.content),
        );
        break;
      case 'deleted':
        _updateMessage(
          event.roomId,
          event.messageId,
          emit,
          (m) => m.copyWith(isDeleted: true, content: '', mediaUrl: null),
        );
        break;
      case 'reaction':
        _updateMessage(
          event.roomId,
          event.messageId,
          emit,
          (m) => m.copyWith(reactions: event.reactions ?? m.reactions),
        );
        break;
    }
  }

  Future<void> _onTypingRequested(
    MessagesTypingRequested event,
    Emitter<MessagesState> emit,
  ) async {
    final roomId = state.activeRoomId;
    if (roomId == null) return;
    await _messagesRepository.sendTyping(roomId, event.isTyping);
  }

  Future<void> _onTypingReceived(
    MessagesTypingReceived event,
    Emitter<MessagesState> emit,
  ) async {
    if (event.senderId.isEmpty || event.senderId == state.currentUserId) {
      return;
    }

    _typingTimeoutTimer?.cancel();
    emit(state.copyWith(isOtherTyping: event.isTyping));

    if (event.isTyping) {
      _typingTimeoutTimer = Timer(const Duration(seconds: 4), () {
        add(MessagesTypingReceived(event.senderId, false));
      });
    }
  }

  Future<void> _onReadReceiptReceived(
    MessagesReadReceiptReceived event,
    Emitter<MessagesState> emit,
  ) async {
    final roomId = state.activeRoomId;
    if (roomId == null || event.readerId.isEmpty || event.readerId == state.currentUserId) {
      return;
    }

    final current = state.messagesByRoom[roomId];
    if (current == null || current.isEmpty) return;

    final hasOwnUnread = current.any(
      (m) => m.senderId == state.currentUserId && !m.isRead,
    );
    if (!hasOwnUnread) return;

    final updatedMessages = current
        .map(
          (m) => m.senderId == state.currentUserId ? m.copyWith(isRead: true) : m,
        )
        .toList();

    final updated = Map<String, List<ChatMessage>>.from(state.messagesByRoom);
    updated[roomId] = updatedMessages;
    emit(state.copyWith(messagesByRoom: updated));
  }

  Future<void> _onConversationsRefreshRequested(
    MessagesConversationsRefreshRequested event,
    Emitter<MessagesState> emit,
  ) async {
    try {
      final conversations = await _messagesRepository.getConversations(
        currentUserId: state.currentUserId,
      );
      emit(state.copyWith(conversations: conversations));
    } catch (_) {
      // Rafraichissement best-effort : on garde la liste actuelle en cas d'echec.
    }
  }

  Future<void> _onHistoryRefreshRequested(
    MessagesHistoryRefreshRequested event,
    Emitter<MessagesState> emit,
  ) async {
    try {
      final messages = await _messagesRepository.getHistory(event.roomId);
      final updated = Map<String, List<ChatMessage>>.from(state.messagesByRoom);
      updated[event.roomId] = messages;
      emit(state.copyWith(messagesByRoom: updated));
    } catch (_) {
      // Rafraichissement best-effort : on garde l'historique actuel en cas d'echec.
    }
  }

  Future<void> _onSocketReceived(
    MessagesSocketReceived event,
    Emitter<MessagesState> emit,
  ) async {
    final message = event.message;
    _appendMessage(message, emit);

    if (message.roomId == state.activeRoomId && message.senderId != state.currentUserId) {
      unawaited(_messagesRepository.markAsRead(message.roomId));
    }
  }

  Future<void> _onConnectionChanged(
    MessagesConnectionChanged event,
    Emitter<MessagesState> emit,
  ) async {
    emit(state.copyWith(isSocketConnected: event.isConnected));
  }

  Future<void> _onReconnectRequested(
    MessagesReconnectRequested event,
    Emitter<MessagesState> emit,
  ) async {
    final roomId = state.activeRoomId;
    if (roomId == null || roomId.isEmpty) {
      return;
    }
    add(MessagesConversationOpened(roomId));
  }

  void _appendMessage(ChatMessage message, Emitter<MessagesState> emit) {
    final updated = Map<String, List<ChatMessage>>.from(state.messagesByRoom);
    final current = List<ChatMessage>.from(updated[message.roomId] ?? const []);

    if (current.any((m) => m.id == message.id)) {
      return;
    }

    current.add(message);
    updated[message.roomId] = current;

    emit(
      state.copyWith(
        status: MessagesStatus.success,
        messagesByRoom: updated,
      ),
    );
  }

  void _updateMessage(
    String roomId,
    String messageId,
    Emitter<MessagesState> emit,
    ChatMessage Function(ChatMessage message) transform,
  ) {
    final current = state.messagesByRoom[roomId];
    if (current == null) return;

    var changed = false;
    final updatedMessages = current.map((m) {
      if (m.id != messageId) return m;
      changed = true;
      return transform(m);
    }).toList();

    if (!changed) return;

    final updated = Map<String, List<ChatMessage>>.from(state.messagesByRoom);
    updated[roomId] = updatedMessages;
    emit(state.copyWith(messagesByRoom: updated));
  }

  @override
  Future<void> close() async {
    _typingTimeoutTimer?.cancel();
    await _roomSubscription?.cancel();
    await _connectionSubscription?.cancel();
    await _typingSubscription?.cancel();
    await _readSubscription?.cancel();
    await _updatesSubscription?.cancel();
    await _messagesRepository.disconnectRoom();
    return super.close();
  }
}
