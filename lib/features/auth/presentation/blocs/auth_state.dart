import 'package:equatable/equatable.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

/// Browser is open waiting for Google sign-in. The login screen shows a
/// cancel button in this state so the user can go back and try again.
class AuthGoogleSignInPending extends AuthState {
  const AuthGoogleSignInPending();
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated();
}

class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}

class AuthPasswordResetSent extends AuthState {
  final String email;

  const AuthPasswordResetSent(this.email);

  @override
  List<Object?> get props => [email];
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}
