import 'package:dartz/dartz.dart';
import 'package:omni_bridge/core/error/failures.dart';
import 'package:omni_bridge/features/settings/domain/entities/app_settings.dart';
import 'package:omni_bridge/features/settings/domain/entities/system_config.dart';

abstract class ISettingsRepository {
  Future<Either<Failure, dynamic>> getGoogleCredentials();
  Future<Either<Failure, void>> syncSettings(Map<String, dynamic> settings);
  Future<Either<Failure, void>> logEvent(
    String name, {
    Map<String, dynamic>? parameters,
  });
  Future<Either<Failure, AppSettings?>> getSettings();
  Future<Either<Failure, SystemConfig>> getSystemConfig();
}

