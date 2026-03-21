import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:omni_bridge/core/error/failures.dart';
import 'package:omni_bridge/features/auth/domain/repositories/i_auth_repository.dart';

class LoginWithGoogleUseCase {
  final IAuthRepository repository;

  LoginWithGoogleUseCase(this.repository);

  Future<Either<Failure, User>> call() async {
    return await repository.signInWithGoogle();
  }
}
