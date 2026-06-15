import 'package:equatable/equatable.dart';

sealed class RequestsEvent extends Equatable {
  const RequestsEvent();

  @override
  List<Object?> get props => [];
}

final class RequestsStarted extends RequestsEvent {
  const RequestsStarted();
}

final class RequestsRefreshed extends RequestsEvent {
  const RequestsRefreshed();
}

final class RequestsCategoryChanged extends RequestsEvent {
  const RequestsCategoryChanged(this.categoryId);

  final String? categoryId;

  @override
  List<Object?> get props => [categoryId];
}
