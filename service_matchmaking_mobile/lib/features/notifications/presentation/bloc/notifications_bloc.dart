import 'package:bloc/bloc.dart';

import '../../domain/repositories/notifications_repository.dart';
import 'notifications_event.dart';
import 'notifications_state.dart';

class NotificationsBloc extends Bloc<NotificationsEvent, NotificationsState> {
  NotificationsBloc(this._notificationsRepository)
      : super(const NotificationsState()) {
    on<NotificationsStarted>(_onStarted);
    on<NotificationsMarkOneRead>(_onMarkOneRead);
    on<NotificationsMarkAllRead>(_onMarkAllRead);
  }

  final NotificationsRepository _notificationsRepository;

  Future<void> _onStarted(
    NotificationsStarted event,
    Emitter<NotificationsState> emit,
  ) async {
    emit(state.copyWith(status: NotificationsStatus.loading, errorMessage: null));
    await _reload(emit);
  }

  Future<void> _onMarkOneRead(
    NotificationsMarkOneRead event,
    Emitter<NotificationsState> emit,
  ) async {
    try {
      await _notificationsRepository.markAsRead(event.notificationId);
      await _reload(emit);
    } catch (e) {
      emit(
        state.copyWith(
          status: NotificationsStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onMarkAllRead(
    NotificationsMarkAllRead event,
    Emitter<NotificationsState> emit,
  ) async {
    try {
      await _notificationsRepository.markAllAsRead();
      await _reload(emit);
    } catch (e) {
      emit(
        state.copyWith(
          status: NotificationsStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _reload(Emitter<NotificationsState> emit) async {
    try {
      final notifications = await _notificationsRepository.getNotifications();
      final unreadCount = await _notificationsRepository.getUnreadCount();
      emit(
        state.copyWith(
          status: NotificationsStatus.success,
          notifications: notifications,
          unreadCount: unreadCount,
          errorMessage: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: NotificationsStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }
}
