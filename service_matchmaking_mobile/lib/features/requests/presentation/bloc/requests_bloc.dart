import 'package:bloc/bloc.dart';

import '../../domain/repositories/requests_repository.dart';
import 'requests_event.dart';
import 'requests_state.dart';

class RequestsBloc extends Bloc<RequestsEvent, RequestsState> {
  RequestsBloc(this._requestsRepository) : super(const RequestsState()) {
    on<RequestsStarted>(_onStarted);
    on<RequestsRefreshed>(_onRefreshed);
    on<RequestsCategoryChanged>(_onCategoryChanged);
  }

  final RequestsRepository _requestsRepository;

  Future<void> _onStarted(
    RequestsStarted event,
    Emitter<RequestsState> emit,
  ) async {
    await _loadData(emit);
  }

  Future<void> _onRefreshed(
    RequestsRefreshed event,
    Emitter<RequestsState> emit,
  ) async {
    await _loadData(emit);
  }

  Future<void> _onCategoryChanged(
    RequestsCategoryChanged event,
    Emitter<RequestsState> emit,
  ) async {
    emit(state.copyWith(selectedCategoryId: event.categoryId));
    await _loadData(emit);
  }

  Future<void> _loadData(Emitter<RequestsState> emit) async {
    emit(state.copyWith(status: RequestsStatus.loading, errorMessage: null));

    try {
      final categories = await _requestsRepository.getCategories();
      final requests = await _requestsRepository.getOpenRequests(
        categoryId: state.selectedCategoryId,
      );
      emit(
        state.copyWith(
          status: RequestsStatus.success,
          categories: categories,
          requests: requests.items,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: RequestsStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }
}
