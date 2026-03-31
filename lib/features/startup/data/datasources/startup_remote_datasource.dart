import 'dart:async';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:omni_bridge/core/di/injection.dart';
import 'package:omni_bridge/core/utils/app_logger.dart';
import 'package:omni_bridge/features/subscription/data/datasources/subscription_remote_datasource.dart';
import 'package:omni_bridge/features/translation/data/datasources/transcription_remote_datasource.dart';

class StartupRemoteDataSource {
  StartupRemoteDataSource._();
  static final StartupRemoteDataSource instance = StartupRemoteDataSource._();

  Future<void> initializeServices() async {
    AppLogger.i('[Startup] Initializing remote services...', tag: 'Startup');

    // Auth-independent services via DI
    sl<TranscriptionRemoteDataSource>().init();
    sl<SubscriptionRemoteDataSource>().init();

    // Session tracking moved to AuthRepositoryImpl

    final info = await PackageInfo.fromPlatform();
    AppLogger.i('[Startup] App Version: ${info.version}+${info.buildNumber}',
        tag: 'Startup');
  }
}
