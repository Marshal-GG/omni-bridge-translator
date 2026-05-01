import '../entities/update_info.dart';
import '../repositories/i_update_repository.dart';

class CheckForUpdateUseCase {
  final IUpdateRepository _repository;

  CheckForUpdateUseCase(this._repository);

  Future<UpdateInfo> call() => _repository.checkForUpdate();
}
