import 'package:bloc/bloc.dart';

import '../../domain/repositories/requests_repository.dart';
import 'request_create_event.dart';
import 'request_create_state.dart';

class RequestCreateBloc extends Bloc<RequestCreateEvent, RequestCreateState> {
  RequestCreateBloc(this._requestsRepository) : super(const RequestCreateState()) {
    on<RequestCreateSubmitted>(_onSubmitted);
  }

  final RequestsRepository _requestsRepository;

  Future<void> _onSubmitted(
    RequestCreateSubmitted event,
    Emitter<RequestCreateState> emit,
  ) async {
    emit(state.copyWith(status: RequestCreateStatus.submitting, errorMessage: null));

    try {
      final requestId = await _requestsRepository.createRequest(
        categoryId: event.categoryId,
        title: event.title,
        description: event.description,
        urgency: event.urgency,
        locationAddress: event.locationAddress,
        photos: event.photos,
      );

      emit(
        state.copyWith(
          status: RequestCreateStatus.success,
          createdRequestId: requestId,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: RequestCreateStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }
}
