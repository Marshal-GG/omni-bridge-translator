import 'package:omni_bridge/features/auth/domain/repositories/i_auth_repository.dart';

class UpdateDisplayNameUseCase {
  final IAuthRepository repository;

  UpdateDisplayNameUseCase(this.repository);

  Future<void> call(String name) => repository.updateDisplayName(name);
}
