import 'package:equatable/equatable.dart';

import '../../domain/entities/user.dart';

enum ProfileStatus { initial, loading, success, failure, saving }

class ProfileState extends Equatable {
  const ProfileState({
    this.status = ProfileStatus.initial,
    this.user,
    this.errorMessage,
  });

  final ProfileStatus status;
  final User? user;
  final String? errorMessage;

  ProfileState copyWith({
    ProfileStatus? status,
    User? user,
    String? errorMessage,
  }) {
    return ProfileState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, user, errorMessage];
}
