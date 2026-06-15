import 'package:equatable/equatable.dart';

class Proposal extends Equatable {
  const Proposal({
    required this.id,
    required this.requestId,
    required this.providerId,
    required this.message,
    required this.status,
    this.providerName,
    this.providerAvatarUrl,
    this.requestTitle,
    this.requestUrgency,
    this.requestStatus,
    this.requestPhotos = const [],
    this.priceEstimate,
    this.createdAt,
  });

  final String id;
  final String requestId;
  final String providerId;
  final String message;
  final String status;
  final String? providerName;
  final String? providerAvatarUrl;
  final String? requestTitle;
  final String? requestUrgency;
  final String? requestStatus;
  final List<String> requestPhotos;
  final double? priceEstimate;
  final DateTime? createdAt;

  @override
  List<Object?> get props => [
        id,
        requestId,
        providerId,
        message,
        status,
        providerName,
        providerAvatarUrl,
        requestTitle,
        requestUrgency,
        requestStatus,
        requestPhotos,
        priceEstimate,
        createdAt,
      ];
}
