import 'package:equatable/equatable.dart';

import '../../domain/entities/proposal.dart';

enum MyProposalsStatus { initial, loading, success, failure }

class MyProposalsState extends Equatable {
  const MyProposalsState({
    this.status = MyProposalsStatus.initial,
    this.proposals = const [],
    this.withdrawingId,
    this.errorMessage,
  });

  final MyProposalsStatus status;
  final List<Proposal> proposals;
  final String? withdrawingId;
  final String? errorMessage;

  MyProposalsState copyWith({
    MyProposalsStatus? status,
    List<Proposal>? proposals,
    String? withdrawingId,
    bool clearWithdrawingId = false,
    String? errorMessage,
  }) {
    return MyProposalsState(
      status: status ?? this.status,
      proposals: proposals ?? this.proposals,
      withdrawingId: clearWithdrawingId ? null : (withdrawingId ?? this.withdrawingId),
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, proposals, withdrawingId, errorMessage];
}
