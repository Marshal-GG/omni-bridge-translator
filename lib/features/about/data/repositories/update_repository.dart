import 'package:omni_bridge/features/startup/domain/entities/update_info.dart';
import 'package:omni_bridge/features/startup/domain/repositories/i_update_repository.dart'
    as startup;
import '../../domain/entities/update_result.dart' as domain;
import '../../domain/repositories/i_update_repository.dart';

class UpdateRepositoryImpl implements IUpdateRepository {
  final startup.IUpdateRepository _startupRepo;

  UpdateRepositoryImpl(this._startupRepo);

  @override
  Future<domain.UpdateResult> checkForUpdate() async {
    final info = await _startupRepo.checkForUpdate();
    return domain.UpdateResult(
      status: _mapStatus(info.status),
      latestVersion: info.latestVersion,
      releaseUrl: info.releaseUrl,
      downloadUrl: info.downloadUrl,
      errorMessage: info.errorMessage,
      forceUpdateMessage: info.forceUpdateMessage,
    );
  }

  domain.UpdateStatus _mapStatus(UpdateInfoStatus s) => switch (s) {
    UpdateInfoStatus.upToDate => domain.UpdateStatus.upToDate,
    UpdateInfoStatus.available => domain.UpdateStatus.available,
    UpdateInfoStatus.forced => domain.UpdateStatus.forced,
    UpdateInfoStatus.error => domain.UpdateStatus.error,
  };
}
