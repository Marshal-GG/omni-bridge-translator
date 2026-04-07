import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:omni_bridge/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:omni_bridge/features/auth/presentation/blocs/auth_event.dart';
import 'package:omni_bridge/features/auth/presentation/blocs/auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final IAuthRepository authRepository;

  AuthBloc({required this.authRepository}) : super(const AuthInitial()) {
    on<AuthLoginWithEmailPasswordEvent>(_onLoginWithEmailPassword);
    on<AuthRegisterWithEmailPasswordEvent>(_onRegisterWithEmailPassword);
    on<AuthLoginWithGoogleEvent>(_onLoginWithGoogle);
    on<AuthCancelGoogleEvent>(_onCancelGoogle);
    on<AuthSendPasswordResetEvent>(_onSendPasswordReset);
    on<AuthLogoutEvent>(_onLogout);
  }

  Future<void> _onLoginWithEmailPassword(
    AuthLoginWithEmailPasswordEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await authRepository.signInWithEmailAndPassword(
        event.email,
        event.password,
      );
      emit(const AuthAuthenticated());
    } on FirebaseAuthException catch (e) {
      emit(AuthError(e.message ?? 'Authentication failed.'));
    } catch (e) {
      emit(AuthError('An unexpected error occurred: $e'));
    }
  }

  Future<void> _onRegisterWithEmailPassword(
    AuthRegisterWithEmailPasswordEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await authRepository.registerWithEmailAndPassword(
        event.email,
        event.password,
      );
      emit(const AuthAuthenticated());
    } on FirebaseAuthException catch (e) {
      emit(AuthError(e.message ?? 'Registration failed.'));
    } catch (e) {
      emit(AuthError('An unexpected error occurred: $e'));
    }
  }

  Future<void> _onLoginWithGoogle(
    AuthLoginWithGoogleEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthGoogleSignInPending());
    try {
      await authRepository.signInWithGoogle();
      emit(const AuthAuthenticated());
    } on FirebaseAuthException catch (e) {
      emit(AuthError(e.message ?? 'Google Sign-in failed.'));
    } catch (e) {
      emit(AuthError('An unexpected error occurred: $e'));
    }
  }

  void _onCancelGoogle(AuthCancelGoogleEvent event, Emitter<AuthState> emit) {
    emit(const AuthInitial());
  }

  Future<void> _onSendPasswordReset(
    AuthSendPasswordResetEvent event,
    Emitter<AuthState> emit,
  ) async {
    // We don't necessarily want to put the whole screen in a loading state,
    // but we can to prevent multiple clicks. Let's emit AuthLoading momentarily.
    emit(const AuthLoading());
    try {
      await authRepository.sendPasswordReset(event.email);
      emit(AuthPasswordResetSent(event.email));
      // Reset back to initial state so they can try to login again if they want
      emit(const AuthInitial());
    } on FirebaseAuthException catch (e) {
      emit(AuthError(e.message ?? 'Failed to send reset email.'));
    } catch (e) {
      emit(AuthError('An unexpected error occurred: $e'));
    }
  }

  Future<void> _onLogout(AuthLogoutEvent event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    try {
      await authRepository.signOut();
      emit(const AuthUnauthenticated());
    } catch (e) {
      emit(AuthError('Failed to sign out: $e'));
    }
  }
}
