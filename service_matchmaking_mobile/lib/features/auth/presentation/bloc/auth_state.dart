import 'package:equatable/equatable.dart';

import '../../domain/entities/user.dart';

enum AuthStatus {
  unknown,
  loading,
  authenticated,
  unauthenticated,
  failure,
}

class AuthState extends Equatable {
  const AuthState({
    required this.status,
    this.user,
    this.errorMessage,
  });

  const AuthState.unknown() : this(status: AuthStatus.unknown);

  final AuthStatus status;
  final User? user;
  final String? errorMessage;

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }

  bool get isAuthenticated => status == AuthStatus.authenticated && user != null;

  @override
  List<Object?> get props => [status, user, errorMessage];
}
