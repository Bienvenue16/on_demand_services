import 'package:equatable/equatable.dart';

class User extends Equatable {
  const User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.isVerified,
    required this.isActive,
    this.phone,
    this.avatarUrl,
    this.createdAt,
  });

  final String id;
  final String email;
  final String fullName;
  final String role;
  final bool isVerified;
  final bool isActive;
  final String? phone;
  final String? avatarUrl;
  final DateTime? createdAt;

  bool get isProvider => role == 'provider';
  bool get isAdmin => role == 'admin';

  @override
  List<Object?> get props => [
        id,
        email,
        fullName,
        role,
        isVerified,
        isActive,
        phone,
        avatarUrl,
        createdAt,
      ];
}
