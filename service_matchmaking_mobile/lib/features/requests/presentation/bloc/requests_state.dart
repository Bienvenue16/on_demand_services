import 'package:equatable/equatable.dart';

import '../../domain/entities/category.dart';
import '../../domain/entities/service_request.dart';

enum RequestsStatus { initial, loading, success, failure }

class RequestsState extends Equatable {
  const RequestsState({
    this.status = RequestsStatus.initial,
    this.categories = const [],
    this.requests = const [],
    this.selectedCategoryId,
    this.errorMessage,
  });

  final RequestsStatus status;
  final List<Category> categories;
  final List<ServiceRequest> requests;
  final String? selectedCategoryId;
  final String? errorMessage;

  RequestsState copyWith({
    RequestsStatus? status,
    List<Category>? categories,
    List<ServiceRequest>? requests,
    String? selectedCategoryId,
    String? errorMessage,
  }) {
    return RequestsState(
      status: status ?? this.status,
      categories: categories ?? this.categories,
      requests: requests ?? this.requests,
      selectedCategoryId: selectedCategoryId,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        categories,
        requests,
        selectedCategoryId,
        errorMessage,
      ];
}
