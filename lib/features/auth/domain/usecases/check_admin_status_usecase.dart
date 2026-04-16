import '../repositories/i_auth_repository.dart';

class CheckAdminStatusUseCase {
  final IAuthRepository _repository;

  CheckAdminStatusUseCase(this._repository);

  Future<bool> call(String email) => _repository.isAdmin(email);
}
