import '../entities/provider_profile.dart';

abstract class ProviderProfileRepository {
  /// Retourne `null` si le prestataire n'a pas encore de profil (404 backend).
  Future<ProviderProfileEntity?> getMyProfile();

  Future<ProviderProfileEntity> updateMyProfile({
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
  });

  Future<String?> uploadPortfolioImage(String filePath);
  Future<String?> uploadCertificateImage(String filePath);
}
