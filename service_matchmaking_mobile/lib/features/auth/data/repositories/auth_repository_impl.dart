import 'package:dio/dio.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<bool> hasSession() => _apiClient.hasSession();

  @override
  Future<void> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    String role = 'client',
  }) async {
    await _apiClient.post(
      '/auth/register',
      data: {
        'email': email,
        'password': password,
        'full_name': fullName,
        'phone': phone,
        'role': role,
      },
      skipAuth: true,
    );
  }

  @override
  Future<User> login({required String email, required String password}) async {
    final tokens = await _apiClient.post(
      '/auth/login',
      data: {'email': email, 'password': password},
      skipAuth: true,
    );

    final access = (tokens['access_token'] ?? '').toString();
    final refresh = (tokens['refresh_token'] ?? '').toString();
    if (access.isEmpty || refresh.isEmpty) {
      throw AppException('Reponse login invalide');
    }

    await _apiClient.saveTokens(accessToken: access, refreshToken: refresh);
    return getCurrentUser();
  }

  @override
  Future<void> forgotPassword({required String email}) async {
    await _apiClient.post(
      '/auth/forgot-password',
      data: {'email': email},
      skipAuth: true,
    );
  }

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    await _apiClient.post(
      '/auth/reset-password',
      data: {
        'token': token,
        'new_password': newPassword,
      },
      skipAuth: true,
    );
  }

  @override
  Future<User> getCurrentUser() async {
    final data = await _apiClient.get('/users/me');

    return _mapUser(data);
  }

  @override
  Future<String?> uploadAvatar(String filePath) async {
    final data = await _apiClient.postMultipart(
      '/uploads/image',
      data: FormData.fromMap(
        {
          'file': await MultipartFile.fromFile(filePath),
          'file_type': 'avatar',
        },
      ),
    );

    return (data['url'] ?? data['file_url'] ?? data['path'])?.toString();
  }

  @override
  Future<User> updateCurrentUser({
    required String fullName,
    String? phone,
    String? avatarUrl,
  }) async {
    final payload = <String, dynamic>{
      'full_name': fullName,
      'phone': phone,
      'avatar_url': avatarUrl,
    };

    final data = await _apiClient.put('/users/me', data: payload);
    return _mapUser(data);
  }

  User _mapUser(Map<String, dynamic> data) {
    return User(
      id: (data['id'] ?? data['_id'] ?? '').toString(),
      email: (data['email'] ?? '').toString(),
      fullName: (data['full_name'] ?? '').toString(),
      role: (data['role'] ?? 'client').toString(),
      isVerified: data['is_verified'] == true,
      isActive: data['is_active'] != false,
      phone: data['phone']?.toString(),
      avatarUrl: data['avatar_url']?.toString(),
      createdAt: DateTime.tryParse((data['created_at'] ?? '').toString()),
    );
  }

  @override
  Future<void> logout() async {
    try {
      await _apiClient.post('/auth/logout');
    } finally {
      await _apiClient.clearTokens();
    }
  }
}
