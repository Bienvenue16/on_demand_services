import 'package:equatable/equatable.dart';

import '../../domain/entities/proposal.dart';

enum MyProposalsStatus { initial, loading, success, failure }

class MyProposalsState extends Equatable {
  const MyProposalsState({
    this.status = MyProposalsStatus.initial,
    this.proposals = const [],
    this.errorMessage,
  });

  final MyProposalsStatus status;
  final List<Proposal> proposals;
  final String? errorMessage;

  MyProposalsState copyWith({
    MyProposalsStatus? status,
    List<Proposal>? proposals,
    String? errorMessage,
  }) {
    return MyProposalsState(
      status: status ?? this.status,
      proposals: proposals ?? this.proposals,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, proposals, errorMessage];
}
