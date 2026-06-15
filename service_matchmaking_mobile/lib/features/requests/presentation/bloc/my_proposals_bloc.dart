import 'package:bloc/bloc.dart';

import '../../domain/repositories/requests_repository.dart';
import 'my_proposals_event.dart';
import 'my_proposals_state.dart';

class MyProposalsBloc extends Bloc<MyProposalsEvent, MyProposalsState> {
  MyProposalsBloc(this._requestsRepository)
      : super(const MyProposalsState()) {
    on<MyProposalsStarted>(_onStarted);
  }

  final RequestsRepository _requestsRepository;

  Future<void> _onStarted(
    MyProposalsStarted event,
    Emitter<MyProposalsState> emit,
  ) async {
    emit(state.copyWith(status: MyProposalsStatus.loading, errorMessage: null));

    try {
      final proposals = await _requestsRepository.getMyProposals();
      emit(state.copyWith(status: MyProposalsStatus.success, proposals: proposals));
    } catch (e) {
      emit(
        state.copyWith(
          status: MyProposalsStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }
}
