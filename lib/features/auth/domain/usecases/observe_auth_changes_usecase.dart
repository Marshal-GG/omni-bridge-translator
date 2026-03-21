import 'package:firebase_auth/firebase_auth.dart';
import 'package:omni_bridge/features/auth/domain/repositories/i_auth_repository.dart';

class ObserveAuthChangesUseCase {
  final IAuthRepository repository;

  ObserveAuthChangesUseCase(this.repository);

  Stream<User?> call() {
    return repository.authStateChanges;
  }
}
