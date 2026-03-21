import 'package:omni_bridge/features/auth/domain/repositories/i_auth_repository.dart';

class LogoutUseCase {
  final IAuthRepository repository;

  LogoutUseCase(this.repository);

  Future<void> call() async {
    await repository.signOut();
  }
}
