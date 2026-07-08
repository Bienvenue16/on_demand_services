import 'package:bloc/bloc.dart';

import '../../domain/repositories/requests_repository.dart';
import 'my_proposals_event.dart';
import 'my_proposals_state.dart';

class MyProposalsBloc extends Bloc<MyProposalsEvent, MyProposalsState> {
  MyProposalsBloc(this._requestsRepository)
      : super(const MyProposalsState()) {
    on<MyProposalsStarted>(_onStarted);
    on<MyProposalsWithdrawRequested>(_onWithdrawRequested);
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

  Future<void> _onWithdrawRequested(
    MyProposalsWithdrawRequested event,
    Emitter<MyProposalsState> emit,
  ) async {
    emit(state.copyWith(withdrawingId: event.proposalId, errorMessage: null));
    try {
      await _requestsRepository.deleteProposal(event.proposalId);
      final updated =
          state.proposals.where((p) => p.id != event.proposalId).toList();
      emit(
        state.copyWith(
          status: MyProposalsStatus.success,
          proposals: updated,
          clearWithdrawingId: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: MyProposalsStatus.failure,
          errorMessage: e.toString(),
          clearWithdrawingId: true,
        ),
      );
    }
  }
}
