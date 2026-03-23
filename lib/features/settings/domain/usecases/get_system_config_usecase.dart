import 'package:dartz/dartz.dart';
import 'package:omni_bridge/core/error/failures.dart';
import 'package:omni_bridge/features/settings/domain/entities/system_config.dart';
import 'package:omni_bridge/features/settings/domain/repositories/i_settings_repository.dart';

class GetSystemConfigUseCase {
  final ISettingsRepository repository;

  GetSystemConfigUseCase(this.repository);

  Future<Either<Failure, SystemConfig>> call() async {
    return repository.getSystemConfig();
  }
}
