import 'package:equatable/equatable.dart';

sealed class MyRequestsEvent extends Equatable {
  const MyRequestsEvent();

  @override
  List<Object?> get props => [];
}

final class MyRequestsStarted extends MyRequestsEvent {
  const MyRequestsStarted(this.userId);

  final String userId;

  @override
  List<Object?> get props => [userId];
}

final class MyRequestsStatusFilterChanged extends MyRequestsEvent {
  const MyRequestsStatusFilterChanged(this.userId, this.status);

  final String userId;
  final String? status;

  @override
  List<Object?> get props => [userId, status];
}

final class MyRequestsStatusUpdated extends MyRequestsEvent {
  const MyRequestsStatusUpdated({
    required this.userId,
    required this.requestId,
    required this.status,
  });

  final String userId;
  final String requestId;
  final String status;

  @override
  List<Object?> get props => [userId, requestId, status];
}
