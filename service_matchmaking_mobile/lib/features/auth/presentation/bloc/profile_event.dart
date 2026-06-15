import 'package:equatable/equatable.dart';

sealed class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => [];
}

final class ProfileStarted extends ProfileEvent {
  const ProfileStarted();
}

final class ProfileUpdated extends ProfileEvent {
  const ProfileUpdated({
    required this.fullName,
    this.phone,
    this.avatarUrl,
  });

  final String fullName;
  final String? phone;
  final String? avatarUrl;

  @override
  List<Object?> get props => [fullName, phone, avatarUrl];
}

final class ProfileAvatarUploadRequested extends ProfileEvent {
  const ProfileAvatarUploadRequested({required this.filePath});

  final String filePath;

  @override
  List<Object?> get props => [filePath];
}
