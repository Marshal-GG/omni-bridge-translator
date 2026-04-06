import '../../domain/entities/update_result.dart' as domain;
import '../../domain/repositories/i_update_repository.dart';
import '../../../../features/startup/data/datasources/update_remote_datasource.dart';

class UpdateRepositoryImpl implements IUpdateRepository {
  final UpdateRemoteDataSource _updateService;

  UpdateRepositoryImpl(this._updateService);

  @override
  Future<domain.UpdateResult> checkForUpdate() async {
    final result = await _updateService.checkForUpdate();
    return domain.UpdateResult(
      status: domain.UpdateStatus.values[result.status.index],
      latestVersion: result.latestVersion,
      releaseUrl: result.releaseUrl,
      downloadUrl: result.downloadUrl,
      errorMessage: result.errorMessage,
    );
  }
}
