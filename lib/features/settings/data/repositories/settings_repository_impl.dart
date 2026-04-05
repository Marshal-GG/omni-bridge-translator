import 'package:dartz/dartz.dart';
import 'package:omni_bridge/core/error/failures.dart';
import 'package:omni_bridge/features/settings/data/datasources/settings_remote_datasource.dart';
import 'package:omni_bridge/features/settings/domain/entities/app_settings.dart';
import 'package:omni_bridge/features/settings/domain/entities/system_config.dart';
import 'package:omni_bridge/features/settings/domain/repositories/i_settings_repository.dart';
import 'package:omni_bridge/core/interfaces/i_engine_selection_source.dart';

class SettingsRepositoryImpl implements ISettingsRepository, IEngineSelectionSource {
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

  @override
  Future<String> getSelectedTranslationEngine() async {
    final result = await getSettings();
    return result.fold((_) => 'google', (s) => s?.translationModel ?? 'google');
  }

  @override
  Future<String> getSelectedTranscriptionEngine() async {
    final result = await getSettings();
    return result.fold((_) => 'online', (s) => s?.transcriptionModel ?? 'online');
  }
}
