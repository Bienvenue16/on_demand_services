import 'package:bloc/bloc.dart';

import '../../domain/repositories/provider_profile_repository.dart';
import 'provider_profile_event.dart';
import 'provider_profile_state.dart';

class ProviderProfileBloc extends Bloc<ProviderProfileEvent, ProviderProfileState> {
  ProviderProfileBloc(this._repository) : super(const ProviderProfileState()) {
    on<ProviderProfileStarted>(_onStarted);
    on<ProviderProfileSaved>(_onSaved);
    on<ProviderProfilePortfolioImageAdded>(_onPortfolioImageAdded);
    on<ProviderProfileCertificateImageAdded>(_onCertificateImageAdded);
    on<ProviderProfilePortfolioImageRemoved>(_onPortfolioImageRemoved);
    on<ProviderProfileCertificateImageRemoved>(_onCertificateImageRemoved);
  }

  final ProviderProfileRepository _repository;

  Future<void> _onStarted(
    ProviderProfileStarted event,
    Emitter<ProviderProfileState> emit,
  ) async {
    emit(state.copyWith(status: ProviderProfileStatus.loading, errorMessage: null));
    try {
      final profile = await _repository.getMyProfile();
      emit(
        state.copyWith(
          status: ProviderProfileStatus.success,
          profile: profile ?? state.profile,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: ProviderProfileStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onSaved(
    ProviderProfileSaved event,
    Emitter<ProviderProfileState> emit,
  ) async {
    emit(state.copyWith(status: ProviderProfileStatus.saving, errorMessage: null));
    try {
      final profile = await _repository.updateMyProfile(
        bio: event.bio,
        skills: event.skills,
        categoryIds: event.categoryIds,
        radiusKm: event.radiusKm,
        locationLat: event.locationLat,
        locationLng: event.locationLng,
        locationCity: event.locationCity,
        locationAddress: event.locationAddress,
      );
      emit(state.copyWith(status: ProviderProfileStatus.success, profile: profile));
    } catch (e) {
      emit(
        state.copyWith(
          status: ProviderProfileStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onPortfolioImageAdded(
    ProviderProfilePortfolioImageAdded event,
    Emitter<ProviderProfileState> emit,
  ) async {
    emit(state.copyWith(uploadingPortfolio: true, errorMessage: null));
    try {
      final url = await _repository.uploadPortfolioImage(event.filePath);
      if (url == null || url.isEmpty) {
        throw Exception('Echec de l\'envoi de la photo');
      }
      final updatedPortfolio = [...state.profile.portfolio, url];
      final profile = await _repository.updateMyProfile(portfolio: updatedPortfolio);
      emit(
        state.copyWith(
          status: ProviderProfileStatus.success,
          profile: profile,
          uploadingPortfolio: false,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: ProviderProfileStatus.failure,
          errorMessage: e.toString(),
          uploadingPortfolio: false,
        ),
      );
    }
  }

  Future<void> _onCertificateImageAdded(
    ProviderProfileCertificateImageAdded event,
    Emitter<ProviderProfileState> emit,
  ) async {
    emit(state.copyWith(uploadingCertificate: true, errorMessage: null));
    try {
      final url = await _repository.uploadCertificateImage(event.filePath);
      if (url == null || url.isEmpty) {
        throw Exception('Echec de l\'envoi du document');
      }
      final updatedCertificates = [...state.profile.certificates, url];
      final profile = await _repository.updateMyProfile(certificates: updatedCertificates);
      emit(
        state.copyWith(
          status: ProviderProfileStatus.success,
          profile: profile,
          uploadingCertificate: false,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: ProviderProfileStatus.failure,
          errorMessage: e.toString(),
          uploadingCertificate: false,
        ),
      );
    }
  }

  Future<void> _onPortfolioImageRemoved(
    ProviderProfilePortfolioImageRemoved event,
    Emitter<ProviderProfileState> emit,
  ) async {
    final updatedPortfolio =
        state.profile.portfolio.where((url) => url != event.url).toList();
    try {
      final profile = await _repository.updateMyProfile(portfolio: updatedPortfolio);
      emit(state.copyWith(status: ProviderProfileStatus.success, profile: profile));
    } catch (e) {
      emit(
        state.copyWith(
          status: ProviderProfileStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onCertificateImageRemoved(
    ProviderProfileCertificateImageRemoved event,
    Emitter<ProviderProfileState> emit,
  ) async {
    final updatedCertificates =
        state.profile.certificates.where((url) => url != event.url).toList();
    try {
      final profile = await _repository.updateMyProfile(certificates: updatedCertificates);
      emit(state.copyWith(status: ProviderProfileStatus.success, profile: profile));
    } catch (e) {
      emit(
        state.copyWith(
          status: ProviderProfileStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }
}
