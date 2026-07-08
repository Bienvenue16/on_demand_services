import 'package:equatable/equatable.dart';

sealed class RequestCreateEvent extends Equatable {
  const RequestCreateEvent();

  @override
  List<Object?> get props => [];
}

final class RequestCreateSubmitted extends RequestCreateEvent {
  const RequestCreateSubmitted({
    required this.categoryId,
    required this.title,
    required this.description,
    required this.urgency,
    this.locationAddress,
    this.locationLat,
    this.locationLng,
    this.photos = const [],
  });

  final String categoryId;
  final String title;
  final String description;
  final String urgency;
  final String? locationAddress;
  final double? locationLat;
  final double? locationLng;
  final List<String> photos;

  @override
  List<Object?> get props => [
        categoryId,
        title,
        description,
        urgency,
        locationAddress,
        locationLat,
        locationLng,
        photos,
      ];
}
