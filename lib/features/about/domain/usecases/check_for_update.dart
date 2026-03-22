import '../entities/update_result.dart';
import '../repositories/i_update_repository.dart';

class CheckForUpdate {
  final IUpdateRepository _repository;

  CheckForUpdate(this._repository);

  Future<UpdateResult> call() {
    return _repository.checkForUpdate();
  }
}
