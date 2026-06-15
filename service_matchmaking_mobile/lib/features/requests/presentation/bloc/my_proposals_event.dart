import 'package:equatable/equatable.dart';

sealed class MyProposalsEvent extends Equatable {
  const MyProposalsEvent();

  @override
  List<Object?> get props => [];
}

final class MyProposalsStarted extends MyProposalsEvent {
  const MyProposalsStarted();
}
