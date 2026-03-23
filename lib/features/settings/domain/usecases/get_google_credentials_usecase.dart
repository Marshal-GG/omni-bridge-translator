import 'package:dartz/dartz.dart';
import 'package:omni_bridge/core/error/failures.dart';
import 'package:omni_bridge/features/settings/domain/repositories/i_settings_repository.dart';

class GetGoogleCredentialsUseCase {
  final ISettingsRepository repository;

  GetGoogleCredentialsUseCase(this.repository);

  Future<Either<Failure, dynamic>> call() {
    return repository.getGoogleCredentials();
  }
}
