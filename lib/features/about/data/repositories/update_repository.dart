import '../../domain/entities/update_result.dart' as domain;
import '../../domain/repositories/i_update_repository.dart';
import '../../../../data/services/server/update_service.dart';

class UpdateRepositoryImpl implements IUpdateRepository {
  final UpdateService _updateService;

  UpdateRepositoryImpl(this._updateService);

  @override
  Future<domain.UpdateResult> checkForUpdate() async {
    final result = await _updateService.checkForUpdate();
    return domain.UpdateResult(
      status: domain.UpdateStatus.values[result.status.index],
      latestVersion: result.latestVersion,
      releaseUrl: result.releaseUrl,
      errorMessage: result.errorMessage,
    );
  }
}
