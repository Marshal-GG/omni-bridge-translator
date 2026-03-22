import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthLoginWithEmailPasswordEvent extends AuthEvent {
  final String email;
  final String password;

  const AuthLoginWithEmailPasswordEvent(this.email, this.password);

  @override
  List<Object?> get props => [email, password];
}

class AuthRegisterWithEmailPasswordEvent extends AuthEvent {
  final String email;
  final String password;

  const AuthRegisterWithEmailPasswordEvent(this.email, this.password);

  @override
  List<Object?> get props => [email, password];
}

class AuthLoginWithGoogleEvent extends AuthEvent {
  const AuthLoginWithGoogleEvent();
}

class AuthSendPasswordResetEvent extends AuthEvent {
  final String email;

  const AuthSendPasswordResetEvent(this.email);

  @override
  List<Object?> get props => [email];
}

class AuthLogoutEvent extends AuthEvent {
  const AuthLogoutEvent();
}
