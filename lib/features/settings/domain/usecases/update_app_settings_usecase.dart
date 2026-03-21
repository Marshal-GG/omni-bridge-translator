import 'package:dartz/dartz.dart';
import 'package:omni_bridge/core/error/failures.dart';
import 'package:omni_bridge/features/settings/domain/repositories/i_settings_repository.dart';

class UpdateAppSettingsUseCase {
  final ISettingsRepository repository;

  UpdateAppSettingsUseCase(this.repository);

  Future<Either<Failure, void>> call(Map<String, dynamic> settings) {
    return repository.syncSettings(settings);
  }
}
