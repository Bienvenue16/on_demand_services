import 'package:equatable/equatable.dart';

sealed class RequestDetailEvent extends Equatable {
  const RequestDetailEvent();

  @override
  List<Object?> get props => [];
}

final class RequestDetailStarted extends RequestDetailEvent {
  const RequestDetailStarted(this.requestId);

  final String requestId;

  @override
  List<Object?> get props => [requestId];
}

final class ProposalSubmitted extends RequestDetailEvent {
  const ProposalSubmitted({
    required this.requestId,
    required this.message,
    this.priceEstimate,
  });

  final String requestId;
  final String message;
  final double? priceEstimate;

  @override
  List<Object?> get props => [requestId, message, priceEstimate];
}

final class ProposalAccepted extends RequestDetailEvent {
  const ProposalAccepted({
    required this.requestId,
    required this.proposalId,
  });

  final String requestId;
  final String proposalId;

  @override
  List<Object?> get props => [requestId, proposalId];
}

final class ProposalRoomOpenConsumed extends RequestDetailEvent {
  const ProposalRoomOpenConsumed();
}

final class ProposalDeclined extends RequestDetailEvent {
  const ProposalDeclined({
    required this.requestId,
    required this.proposalId,
  });

  final String requestId;
  final String proposalId;

  @override
  List<Object?> get props => [requestId, proposalId];
}
