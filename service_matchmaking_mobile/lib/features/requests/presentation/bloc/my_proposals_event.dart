import 'package:equatable/equatable.dart';

sealed class MyProposalsEvent extends Equatable {
  const MyProposalsEvent();

  @override
  List<Object?> get props => [];
}

final class MyProposalsStarted extends MyProposalsEvent {
  const MyProposalsStarted();
}

final class MyProposalsWithdrawRequested extends MyProposalsEvent {
  const MyProposalsWithdrawRequested(this.proposalId);

  final String proposalId;

  @override
  List<Object?> get props => [proposalId];
}
