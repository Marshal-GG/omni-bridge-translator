import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:omni_bridge/features/auth/domain/repositories/i_auth_repository.dart';

class GetCurrentUserUseCase {
  final IAuthRepository repository;

  GetCurrentUserUseCase(this.repository);

  ValueListenable<User?> call() {
    return repository.currentUser;
  }
}
