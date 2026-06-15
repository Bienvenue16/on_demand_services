import '../entities/user.dart';

abstract class AuthRepository {
  Future<bool> hasSession();
  Future<void> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    String role,
  });
  Future<User> login({required String email, required String password});
  Future<void> forgotPassword({required String email});
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  });
  Future<User> getCurrentUser();
  Future<String?> uploadAvatar(String filePath);
  Future<User> updateCurrentUser({
    required String fullName,
    String? phone,
    String? avatarUrl,
  });
  Future<void> logout();
}
