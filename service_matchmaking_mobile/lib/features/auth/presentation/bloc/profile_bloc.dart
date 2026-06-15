import 'package:bloc/bloc.dart';

import '../../domain/repositories/auth_repository.dart';
import 'profile_event.dart';
import 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  ProfileBloc(this._authRepository) : super(const ProfileState()) {
    on<ProfileStarted>(_onStarted);
    on<ProfileUpdated>(_onUpdated);
    on<ProfileAvatarUploadRequested>(_onAvatarUploadRequested);
  }

  final AuthRepository _authRepository;

  Future<void> _onStarted(
    ProfileStarted event,
    Emitter<ProfileState> emit,
  ) async {
    emit(state.copyWith(status: ProfileStatus.loading, errorMessage: null));
    try {
      final user = await _authRepository.getCurrentUser();
      emit(state.copyWith(status: ProfileStatus.success, user: user));
    } catch (e) {
      emit(
        state.copyWith(
          status: ProfileStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onUpdated(
    ProfileUpdated event,
    Emitter<ProfileState> emit,
  ) async {
    emit(state.copyWith(status: ProfileStatus.saving, errorMessage: null));
    try {
      final user = await _authRepository.updateCurrentUser(
        fullName: event.fullName,
        phone: event.phone,
        avatarUrl: event.avatarUrl ?? state.user?.avatarUrl,
      );
      emit(state.copyWith(status: ProfileStatus.success, user: user));
    } catch (e) {
      emit(
        state.copyWith(
          status: ProfileStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onAvatarUploadRequested(
    ProfileAvatarUploadRequested event,
    Emitter<ProfileState> emit,
  ) async {
    final currentUser = state.user;
    if (currentUser == null) {
      emit(
        state.copyWith(
          status: ProfileStatus.failure,
          errorMessage: 'Profil non charge',
        ),
      );
      return;
    }

    emit(state.copyWith(status: ProfileStatus.saving, errorMessage: null));
    try {
      final uploadedUrl = await _authRepository.uploadAvatar(event.filePath);
      if (uploadedUrl == null || uploadedUrl.isEmpty) {
        throw Exception('Upload avatar invalide');
      }

      final user = await _authRepository.updateCurrentUser(
        fullName: currentUser.fullName,
        phone: currentUser.phone,
        avatarUrl: uploadedUrl,
      );
      emit(state.copyWith(status: ProfileStatus.success, user: user));
    } catch (e) {
      emit(
        state.copyWith(
          status: ProfileStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }
}
