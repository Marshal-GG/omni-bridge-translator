import 'package:dartz/dartz.dart';
import 'package:omni_bridge/core/error/failures.dart';
import 'package:omni_bridge/features/settings/domain/repositories/i_settings_repository.dart';

class SyncSettingsUseCase {
  final ISettingsRepository repository;

  SyncSettingsUseCase(this.repository);

  Future<Either<Failure, void>> call(Map<String, dynamic> settings) async {
    return await repository.syncSettings(settings);
  }
}
