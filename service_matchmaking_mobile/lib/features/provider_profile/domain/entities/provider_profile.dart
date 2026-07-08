import 'package:equatable/equatable.dart';

class ProviderProfileEntity extends Equatable {
  const ProviderProfileEntity({
    this.bio,
    this.skills = const [],
    this.categoryIds = const [],
    this.locationLat,
    this.locationLng,
    this.locationCity,
    this.locationAddress,
    this.radiusKm = 20,
    this.portfolio = const [],
    this.certificates = const [],
    this.avgRating = 0,
    this.totalReviews = 0,
    this.isVerifiedProvider = false,
  });

  final String? bio;
  final List<String> skills;
  final List<String> categoryIds;
  final double? locationLat;
  final double? locationLng;
  final String? locationCity;
  final String? locationAddress;
  final double radiusKm;
  final List<String> portfolio;
  final List<String> certificates;
  final double avgRating;
  final int totalReviews;
  final bool isVerifiedProvider;

  bool get hasLocation => locationLat != null && locationLng != null;

  ProviderProfileEntity copyWith({
    String? bio,
    List<String>? skills,
    List<String>? categoryIds,
    double? locationLat,
    double? locationLng,
    String? locationCity,
    String? locationAddress,
    double? radiusKm,
    List<String>? portfolio,
    List<String>? certificates,
  }) {
    return ProviderProfileEntity(
      bio: bio ?? this.bio,
      skills: skills ?? this.skills,
      categoryIds: categoryIds ?? this.categoryIds,
      locationLat: locationLat ?? this.locationLat,
      locationLng: locationLng ?? this.locationLng,
      locationCity: locationCity ?? this.locationCity,
      locationAddress: locationAddress ?? this.locationAddress,
      radiusKm: radiusKm ?? this.radiusKm,
      portfolio: portfolio ?? this.portfolio,
      certificates: certificates ?? this.certificates,
      avgRating: avgRating,
      totalReviews: totalReviews,
      isVerifiedProvider: isVerifiedProvider,
    );
  }

  @override
  List<Object?> get props => [
        bio,
        skills,
        categoryIds,
        locationLat,
        locationLng,
        locationCity,
        locationAddress,
        radiusKm,
        portfolio,
        certificates,
        avgRating,
        totalReviews,
        isVerifiedProvider,
      ];
}
