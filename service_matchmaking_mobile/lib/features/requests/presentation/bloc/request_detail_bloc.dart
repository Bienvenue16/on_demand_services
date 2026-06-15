import 'package:bloc/bloc.dart';

import '../../domain/repositories/requests_repository.dart';
import 'request_detail_event.dart';
import 'request_detail_state.dart';

class RequestDetailBloc extends Bloc<RequestDetailEvent, RequestDetailState> {
  RequestDetailBloc(this._requestsRepository)
      : super(const RequestDetailState()) {
    on<RequestDetailStarted>(_onStarted);
    on<ProposalSubmitted>(_onProposalSubmitted);
    on<ProposalAccepted>(_onProposalAccepted);
    on<ProposalDeclined>(_onProposalDeclined);
    on<ProposalRoomOpenConsumed>(_onProposalRoomOpenConsumed);
  }

  final RequestsRepository _requestsRepository;

  Future<void> _onStarted(
    RequestDetailStarted event,
    Emitter<RequestDetailState> emit,
  ) async {
    emit(state.copyWith(status: RequestDetailStatus.loading, errorMessage: null));
    await _reload(event.requestId, emit);
  }

  Future<void> _onProposalSubmitted(
    ProposalSubmitted event,
    Emitter<RequestDetailState> emit,
  ) async {
    emit(state.copyWith(status: RequestDetailStatus.actionLoading));
    try {
      await _requestsRepository.submitProposal(
        requestId: event.requestId,
        message: event.message,
        priceEstimate: event.priceEstimate,
      );
      await _reload(event.requestId, emit);
    } catch (e) {
      emit(
        state.copyWith(
          status: RequestDetailStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onProposalAccepted(
    ProposalAccepted event,
    Emitter<RequestDetailState> emit,
  ) async {
    emit(state.copyWith(status: RequestDetailStatus.actionLoading));
    try {
      final roomId = await _requestsRepository.acceptProposal(event.proposalId);
      await _reload(event.requestId, emit, roomIdToOpen: roomId);
    } catch (e) {
      emit(
        state.copyWith(
          status: RequestDetailStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onProposalDeclined(
    ProposalDeclined event,
    Emitter<RequestDetailState> emit,
  ) async {
    emit(state.copyWith(status: RequestDetailStatus.actionLoading));
    try {
      await _requestsRepository.declineProposal(event.proposalId);
      await _reload(event.requestId, emit);
    } catch (e) {
      emit(
        state.copyWith(
          status: RequestDetailStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  void _onProposalRoomOpenConsumed(
    ProposalRoomOpenConsumed event,
    Emitter<RequestDetailState> emit,
  ) {
    emit(state.copyWith(roomIdToOpen: null));
  }

  Future<void> _reload(
    String requestId,
    Emitter<RequestDetailState> emit,
    {String? roomIdToOpen}
  ) async {
    try {
      final request = await _requestsRepository.getRequestById(requestId);
      final proposals = await _requestsRepository.getProposalsByRequest(requestId);
      emit(
        state.copyWith(
          status: RequestDetailStatus.success,
          request: request,
          proposals: proposals,
          errorMessage: null,
          roomIdToOpen: roomIdToOpen,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: RequestDetailStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }
}
