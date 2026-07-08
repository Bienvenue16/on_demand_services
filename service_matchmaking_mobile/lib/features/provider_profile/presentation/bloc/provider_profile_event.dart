import 'package:equatable/equatable.dart';

sealed class ProviderProfileEvent extends Equatable {
  const ProviderProfileEvent();

  @override
  List<Object?> get props => [];
}

final class ProviderProfileStarted extends ProviderProfileEvent {
  const ProviderProfileStarted();
}

final class ProviderProfileSaved extends ProviderProfileEvent {
  const ProviderProfileSaved({
    required this.bio,
    required this.skills,
    required this.categoryIds,
    required this.radiusKm,
    this.locationLat,
    this.locationLng,
    this.locationCity,
    this.locationAddress,
  });

  final String bio;
  final List<String> skills;
  final List<String> categoryIds;
  final double radiusKm;
  final double? locationLat;
  final double? locationLng;
  final String? locationCity;
  final String? locationAddress;

  @override
  List<Object?> get props => [
        bio,
        skills,
        categoryIds,
        radiusKm,
        locationLat,
        locationLng,
        locationCity,
        locationAddress,
      ];
}

final class ProviderProfilePortfolioImageAdded extends ProviderProfileEvent {
  const ProviderProfilePortfolioImageAdded(this.filePath);

  final String filePath;

  @override
  List<Object?> get props => [filePath];
}

final class ProviderProfileCertificateImageAdded extends ProviderProfileEvent {
  const ProviderProfileCertificateImageAdded(this.filePath);

  final String filePath;

  @override
  List<Object?> get props => [filePath];
}

final class ProviderProfilePortfolioImageRemoved extends ProviderProfileEvent {
  const ProviderProfilePortfolioImageRemoved(this.url);

  final String url;

  @override
  List<Object?> get props => [url];
}

final class ProviderProfileCertificateImageRemoved extends ProviderProfileEvent {
  const ProviderProfileCertificateImageRemoved(this.url);

  final String url;

  @override
  List<Object?> get props => [url];
}
