import 'package:dio/dio.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/provider_profile.dart';
import '../../domain/repositories/provider_profile_repository.dart';

class ProviderProfileRepositoryImpl implements ProviderProfileRepository {
  ProviderProfileRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<ProviderProfileEntity?> getMyProfile() async {
    try {
      final data = await _apiClient.get('/users/providers/me');
      return _mapProfile(data);
    } on AppException catch (e) {
      if (e.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  @override
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
  }) async {
    final payload = <String, dynamic>{
      if (bio != null) 'bio': bio,
      if (skills != null) 'skills': skills,
      if (categoryIds != null) 'categories': categoryIds,
      if (radiusKm != null) 'radius_km': radiusKm,
      if (portfolio != null) 'portfolio': portfolio,
      if (certificates != null) 'certificates': certificates,
      if (locationLat != null && locationLng != null)
        'location': {
          'lat': locationLat,
          'lng': locationLng,
          if (locationCity != null && locationCity.isNotEmpty) 'city': locationCity,
          if (locationAddress != null && locationAddress.isNotEmpty) 'address': locationAddress,
        },
    };

    final data = await _apiClient.put('/users/providers/me', data: payload);
    return _mapProfile(data);
  }

  @override
  Future<String?> uploadPortfolioImage(String filePath) async {
    return _uploadImage(filePath, 'portfolio');
  }

  @override
  Future<String?> uploadCertificateImage(String filePath) async {
    return _uploadImage(filePath, 'certificate');
  }

  Future<String?> _uploadImage(String filePath, String fileType) async {
    final data = await _apiClient.postMultipart(
      '/uploads/image',
      data: FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
        'file_type': fileType,
      }),
    );
    return (data['url'] ?? data['file_url'] ?? data['path'])?.toString();
  }

  ProviderProfileEntity _mapProfile(Map<String, dynamic> data) {
    final location = data['location'];
    final locationMap = location is Map ? location : null;

    return ProviderProfileEntity(
      bio: data['bio']?.toString(),
      skills: _stringList(data['skills']),
      categoryIds: _stringList(data['categories']),
      locationLat: _toDoubleOrNull(locationMap?['lat']),
      locationLng: _toDoubleOrNull(locationMap?['lng']),
      locationCity: locationMap?['city']?.toString(),
      locationAddress: locationMap?['address']?.toString(),
      radiusKm: _toDoubleOrNull(data['radius_km']) ?? 20,
      portfolio: _stringList(data['portfolio']),
      certificates: _stringList(data['certificates']),
      avgRating: _toDoubleOrNull(data['avg_rating']) ?? 0,
      totalReviews: int.tryParse((data['total_reviews'] ?? 0).toString()) ?? 0,
      isVerifiedProvider: data['is_verified_provider'] == true,
    );
  }

  List<String> _stringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return const [];
  }

  double? _toDoubleOrNull(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
