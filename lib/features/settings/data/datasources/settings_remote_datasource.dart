import 'package:omni_bridge/features/subscription/data/datasources/tracking_remote_datasource.dart';

abstract class ISettingsRemoteDataSource {
  Future<String> getGoogleCredentials();
  Future<void> syncSettings(Map<String, dynamic> settings);
  Future<Map<String, dynamic>?> getSettings();
  Future<void> logEvent(String name, {Map<String, dynamic>? parameters});
}

class SettingsRemoteDataSourceImpl implements ISettingsRemoteDataSource {
  final TrackingRemoteDataSource _trackingService;

  SettingsRemoteDataSourceImpl(this._trackingService);

  @override
  Future<String> getGoogleCredentials() =>
      _trackingService.getGoogleCredentials();

  @override
  Future<void> syncSettings(Map<String, dynamic> settings) =>
      _trackingService.syncSettings(settings);

  @override
  Future<Map<String, dynamic>?> getSettings() => _trackingService.getSettings();

  @override
  Future<void> logEvent(String eventName, {Map<String, dynamic>? parameters}) {
    return _trackingService.logEvent(eventName, parameters);
  }
}
