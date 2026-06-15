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
    this.photos = const [],
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
  final List<String> photos;
  final DateTime? createdAt;

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
    List<String>? photos,
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
      photos: photos ?? this.photos,
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
        photos,
        createdAt,
      ];
}
