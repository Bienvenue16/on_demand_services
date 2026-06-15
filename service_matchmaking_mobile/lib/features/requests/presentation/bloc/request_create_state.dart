import 'package:equatable/equatable.dart';

enum RequestCreateStatus { initial, submitting, success, failure }

class RequestCreateState extends Equatable {
  const RequestCreateState({
    this.status = RequestCreateStatus.initial,
    this.createdRequestId,
    this.errorMessage,
  });

  final RequestCreateStatus status;
  final String? createdRequestId;
  final String? errorMessage;

  RequestCreateState copyWith({
    RequestCreateStatus? status,
    String? createdRequestId,
    String? errorMessage,
  }) {
    return RequestCreateState(
      status: status ?? this.status,
      createdRequestId: createdRequestId ?? this.createdRequestId,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, createdRequestId, errorMessage];
}
