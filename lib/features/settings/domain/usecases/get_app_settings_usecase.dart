import 'package:dartz/dartz.dart';
import 'package:omni_bridge/core/error/failures.dart';
import 'package:omni_bridge/features/settings/domain/entities/app_settings.dart';
import 'package:omni_bridge/features/settings/domain/repositories/i_settings_repository.dart';

class GetAppSettingsUseCase {
  final ISettingsRepository repository;

  GetAppSettingsUseCase(this.repository);

  Future<Either<Failure, AppSettings?>> call() {
    return repository.getSettings();
  }
}
