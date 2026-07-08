import 'package:equatable/equatable.dart';

class ServiceRequest extends Equatable {
  const ServiceRequest({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.description,
    required this.urgency,
    required this.status,
    this.clientId,
    this.clientName,
    this.clientAvatarUrl,
    this.locationAddress,
    this.locationLat,
    this.locationLng,
    this.photos = const [],
    this.proposalsCount = 0,
    this.createdAt,
  });

  final String id;
  final String categoryId;
  final String title;
  final String description;
  final String urgency;
  final String status;
  final String? clientId;
  final String? clientName;
  final String? clientAvatarUrl;
  final String? locationAddress;
  final double? locationLat;
  final double? locationLng;
  final List<String> photos;
  final int proposalsCount;
  final DateTime? createdAt;

  bool get hasLocation => locationLat != null && locationLng != null;

  ServiceRequest copyWith({
    String? id,
    String? categoryId,
    String? title,
    String? description,
    String? urgency,
    String? status,
    String? clientId,
    String? clientName,
    String? clientAvatarUrl,
    String? locationAddress,
    double? locationLat,
    double? locationLng,
    List<String>? photos,
    int? proposalsCount,
    DateTime? createdAt,
  }) {
    return ServiceRequest(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      title: title ?? this.title,
      description: description ?? this.description,
      urgency: urgency ?? this.urgency,
      status: status ?? this.status,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      clientAvatarUrl: clientAvatarUrl ?? this.clientAvatarUrl,
      locationAddress: locationAddress ?? this.locationAddress,
      locationLat: locationLat ?? this.locationLat,
      locationLng: locationLng ?? this.locationLng,
      photos: photos ?? this.photos,
      proposalsCount: proposalsCount ?? this.proposalsCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        categoryId,
        title,
        description,
        urgency,
        status,
        clientId,
        clientName,
        clientAvatarUrl,
        locationAddress,
        locationLat,
        locationLng,
        photos,
        proposalsCount,
        createdAt,
      ];
}
