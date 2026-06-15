import 'package:equatable/equatable.dart';

import '../../domain/entities/service_request.dart';

enum MyRequestsStatus { initial, loading, success, failure, actionLoading }

class MyRequestsState extends Equatable {
  const MyRequestsState({
    this.status = MyRequestsStatus.initial,
    this.requests = const [],
    this.selectedStatus,
    this.errorMessage,
  });

  final MyRequestsStatus status;
  final List<ServiceRequest> requests;
  final String? selectedStatus;
  final String? errorMessage;

  MyRequestsState copyWith({
    MyRequestsStatus? status,
    List<ServiceRequest>? requests,
    String? selectedStatus,
    String? errorMessage,
  }) {
    return MyRequestsState(
      status: status ?? this.status,
      requests: requests ?? this.requests,
      selectedStatus: selectedStatus,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, requests, selectedStatus, errorMessage];
}
