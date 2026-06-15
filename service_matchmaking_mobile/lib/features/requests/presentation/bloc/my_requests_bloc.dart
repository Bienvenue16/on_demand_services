import 'package:bloc/bloc.dart';

import '../../domain/repositories/requests_repository.dart';
import 'my_requests_event.dart';
import 'my_requests_state.dart';

class MyRequestsBloc extends Bloc<MyRequestsEvent, MyRequestsState> {
  MyRequestsBloc(this._requestsRepository) : super(const MyRequestsState()) {
    on<MyRequestsStarted>(_onStarted);
    on<MyRequestsStatusFilterChanged>(_onFilterChanged);
    on<MyRequestsStatusUpdated>(_onStatusUpdated);
  }

  final RequestsRepository _requestsRepository;

  Future<void> _onStarted(
    MyRequestsStarted event,
    Emitter<MyRequestsState> emit,
  ) async {
    emit(state.copyWith(status: MyRequestsStatus.loading, errorMessage: null));
    await _load(event.userId, emit);
  }

  Future<void> _onFilterChanged(
    MyRequestsStatusFilterChanged event,
    Emitter<MyRequestsState> emit,
  ) async {
    emit(state.copyWith(
      selectedStatus: event.status,
      status: MyRequestsStatus.loading,
      errorMessage: null,
    ));
    await _load(event.userId, emit);
  }

  Future<void> _onStatusUpdated(
    MyRequestsStatusUpdated event,
    Emitter<MyRequestsState> emit,
  ) async {
    emit(state.copyWith(status: MyRequestsStatus.actionLoading));
    try {
      await _requestsRepository.updateRequestStatus(
        requestId: event.requestId,
        status: event.status,
      );
      await _load(event.userId, emit);
    } catch (e) {
      emit(
        state.copyWith(
          status: MyRequestsStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _load(String userId, Emitter<MyRequestsState> emit) async {
    try {
      final requests = await _requestsRepository.getMyRequests(
        userId: userId,
        status: state.selectedStatus,
      );
      emit(state.copyWith(status: MyRequestsStatus.success, requests: requests));
    } catch (e) {
      emit(
        state.copyWith(
          status: MyRequestsStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }
}
