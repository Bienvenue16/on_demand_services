import 'package:bloc/bloc.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this._authRepository) : super(const AuthState.unknown()) {
    on<AuthAppStarted>(_onAppStarted);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
  }

  final AuthRepository _authRepository;

  Future<void> _onAppStarted(
    AuthAppStarted event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading));

    try {
      final hasSession = await _authRepository.hasSession();
      if (!hasSession) {
        emit(state.copyWith(status: AuthStatus.unauthenticated, user: null));
        return;
      }

      final user = await _authRepository.getCurrentUser();
      emit(state.copyWith(status: AuthStatus.authenticated, user: user));
    } catch (_) {
      emit(state.copyWith(status: AuthStatus.unauthenticated, user: null));
    }
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading, errorMessage: null));

    try {
      final user = await _authRepository.login(
        email: event.email,
        password: event.password,
      );
      emit(state.copyWith(status: AuthStatus.authenticated, user: user));
    } catch (e) {
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          user: null,
          errorMessage: _messageFor(e),
        ),
      );
      emit(state.copyWith(status: AuthStatus.unauthenticated));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _authRepository.logout();
    emit(state.copyWith(status: AuthStatus.unauthenticated, user: null));
  }

  Future<void> _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading, errorMessage: null));

    try {
      await _authRepository.register(
        email: event.email,
        password: event.password,
        fullName: event.fullName,
        phone: event.phone,
        role: event.role,
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          user: null,
          errorMessage: _messageFor(e),
        ),
      );
      emit(state.copyWith(status: AuthStatus.unauthenticated));
      return;
    }

    // Le compte vient d'etre cree : on tente une connexion immediate pour
    // eviter de renvoyer l'utilisateur vers l'ecran de connexion. Ca ne
    // fonctionne que si le compte est deja verifie (ex: mode DEBUG cote
    // backend) ; sinon on l'informe qu'il doit d'abord verifier son email.
    try {
      final user = await _authRepository.login(
        email: event.email,
        password: event.password,
      );
      emit(state.copyWith(status: AuthStatus.authenticated, user: user));
    } catch (e) {
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          user: null,
          errorMessage: 'Compte cree. ${_messageFor(e)}',
        ),
      );
      emit(state.copyWith(status: AuthStatus.unauthenticated));
    }
  }

  String _messageFor(Object error) {
    if (error is AppException) return error.message;
    return error.toString();
  }
}
