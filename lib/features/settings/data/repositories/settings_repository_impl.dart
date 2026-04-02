import 'package:dartz/dartz.dart';
import 'package:omni_bridge/core/error/failures.dart';
import 'package:omni_bridge/features/settings/data/datasources/settings_remote_datasource.dart';
import 'package:omni_bridge/features/settings/domain/entities/app_settings.dart';
import 'package:omni_bridge/features/settings/domain/entities/system_config.dart';
import 'package:omni_bridge/features/settings/domain/repositories/i_settings_repository.dart';

class SettingsRepositoryImpl implements ISettingsRepository {
  final ISettingsRemoteDataSource _remoteDataSource;

  SettingsRepositoryImpl(this._remoteDataSource);

  @override
  Future<Either<Failure, Object?>> getGoogleCredentials() async {
    try {
      final credentials = await _remoteDataSource.getGoogleCredentials();
      return Right(credentials);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> syncSettings(
    Map<String, dynamic> settings,
  ) async {
    try {
      await _remoteDataSource.syncSettings(settings);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, AppSettings?>> getSettings() async {
    try {
      final settingsMap = await _remoteDataSource.getSettings();
      if (settingsMap == null) return const Right(null);
      return Right(AppSettings.fromJson(settingsMap));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, SystemConfig>> getSystemConfig() async {
    try {
      final configMap = await _remoteDataSource.getSystemConfig();
      return Right(SystemConfig.fromMap(configMap));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> logEvent(
    String name, {
    Map<String, dynamic>? parameters,
  }) async {
    try {
      await _remoteDataSource.logEvent(name, parameters: parameters);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
