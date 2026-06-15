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
    on<MessagesSocketReceived>(_onSocketReceived);
    on<MessagesConnectionChanged>(_onConnectionChanged);
    on<MessagesReconnectRequested>(_onReconnectRequested);
  }

  final MessagesRepository _messagesRepository;
  StreamSubscription<ChatMessage>? _roomSubscription;
  StreamSubscription<bool>? _connectionSubscription;

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
        ),
      );

      await _roomSubscription?.cancel();
      _roomSubscription = _messagesRepository.watchRoom(event.roomId).listen((incoming) {
        add(
          MessagesSocketReceived(
            incoming.id,
            incoming.roomId,
            incoming.senderId,
            incoming.content,
            incoming.createdAt,
          ),
        );
      });

      await _connectionSubscription?.cancel();
      _connectionSubscription = _messagesRepository.connectionStatus.listen((isConnected) {
        add(MessagesConnectionChanged(isConnected));
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
      await _messagesRepository.sendMessage(
        roomId: event.roomId,
        content: event.content,
      );

      final optimistic = ChatMessage(
        id: 'temp-${DateTime.now().microsecondsSinceEpoch}',
        roomId: event.roomId,
        senderId: state.currentUserId ?? 'me',
        content: event.content,
        createdAt: DateTime.now(),
      );
      _appendMessage(optimistic, emit);
    } catch (e) {
      emit(
        state.copyWith(
          status: MessagesStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onSocketReceived(
    MessagesSocketReceived event,
    Emitter<MessagesState> emit,
  ) async {
    final message = ChatMessage(
      id: event.id,
      roomId: event.roomId,
      senderId: event.senderId,
      content: event.content,
      createdAt: event.createdAt,
    );
    _appendMessage(message, emit);
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

  @override
  Future<void> close() async {
    await _roomSubscription?.cancel();
    await _connectionSubscription?.cancel();
    await _messagesRepository.disconnectRoom();
    return super.close();
  }
}
