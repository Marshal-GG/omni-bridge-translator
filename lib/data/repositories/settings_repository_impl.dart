import 'package:dartz/dartz.dart';
import 'package:omni_bridge/core/error/failures.dart';
import 'package:omni_bridge/data/models/app_settings.dart';
import 'package:omni_bridge/data/services/firebase/tracking_service.dart';
import 'package:omni_bridge/domain/repositories/settings_repository.dart';

class SettingsRepositoryImpl implements ISettingsRepository {
  final TrackingService _trackingService;

  SettingsRepositoryImpl(this._trackingService);

  @override
  Future<Either<Failure, String>> getGoogleCredentials() async {
    try {
      final jsonStr = await _trackingService.getGoogleCredentials();
      return Right(jsonStr);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> syncSettings(Map<String, dynamic> settings) async {
    try {
      await _trackingService.syncSettings(settings);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, AppSettings?>> getSettings() async {
    try {
      final settingsMap = await _trackingService.getSettings();
      if (settingsMap == null) return const Right(null);
      return Right(AppSettings.fromJson(settingsMap));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> logEvent(String name, {Map<String, dynamic>? parameters}) async {
    try {
      await _trackingService.logEvent(name, parameters);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
