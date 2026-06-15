import 'package:equatable/equatable.dart';

import '../../domain/entities/proposal.dart';
import '../../domain/entities/service_request.dart';

enum RequestDetailStatus { initial, loading, success, failure, actionLoading }

class RequestDetailState extends Equatable {
  const RequestDetailState({
    this.status = RequestDetailStatus.initial,
    this.request,
    this.proposals = const [],
    this.errorMessage,
    this.roomIdToOpen,
  });

  final RequestDetailStatus status;
  final ServiceRequest? request;
  final List<Proposal> proposals;
  final String? errorMessage;
  final String? roomIdToOpen;

  RequestDetailState copyWith({
    RequestDetailStatus? status,
    ServiceRequest? request,
    List<Proposal>? proposals,
    String? errorMessage,
    String? roomIdToOpen,
  }) {
    return RequestDetailState(
      status: status ?? this.status,
      request: request ?? this.request,
      proposals: proposals ?? this.proposals,
      errorMessage: errorMessage,
      roomIdToOpen: roomIdToOpen,
    );
  }

  @override
  List<Object?> get props => [status, request, proposals, errorMessage, roomIdToOpen];
}
