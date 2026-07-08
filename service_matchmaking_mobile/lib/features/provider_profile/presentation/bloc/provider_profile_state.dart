import 'package:equatable/equatable.dart';

import '../../domain/entities/provider_profile.dart';

enum ProviderProfileStatus { initial, loading, success, saving, failure }

class ProviderProfileState extends Equatable {
  const ProviderProfileState({
    this.status = ProviderProfileStatus.initial,
    this.profile = const ProviderProfileEntity(),
    this.uploadingPortfolio = false,
    this.uploadingCertificate = false,
    this.errorMessage,
  });

  final ProviderProfileStatus status;
  final ProviderProfileEntity profile;
  final bool uploadingPortfolio;
  final bool uploadingCertificate;
  final String? errorMessage;

  ProviderProfileState copyWith({
    ProviderProfileStatus? status,
    ProviderProfileEntity? profile,
    bool? uploadingPortfolio,
    bool? uploadingCertificate,
    String? errorMessage,
  }) {
    return ProviderProfileState(
      status: status ?? this.status,
      profile: profile ?? this.profile,
      uploadingPortfolio: uploadingPortfolio ?? this.uploadingPortfolio,
      uploadingCertificate: uploadingCertificate ?? this.uploadingCertificate,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        profile,
        uploadingPortfolio,
        uploadingCertificate,
        errorMessage,
      ];
}
