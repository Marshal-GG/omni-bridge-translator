import 'package:omni_bridge/core/di/injection.dart';
import 'package:omni_bridge/features/auth/auth.dart';
import 'package:omni_bridge/features/translation/translation.dart';
import 'package:omni_bridge/features/settings/settings.dart';
import 'package:omni_bridge/features/support/support.dart';
import 'package:omni_bridge/features/history/history.dart';
import 'package:omni_bridge/features/subscription/subscription.dart';
import 'package:omni_bridge/features/usage/usage.dart';
import 'package:omni_bridge/features/about/about.dart';
import 'package:omni_bridge/features/startup/startup.dart' as startup_feature;

void initRepositoryDI() {
  sl.registerLazySingleton<IAuthRepository>(() => AuthRepositoryImpl(sl()));
  sl.registerLazySingleton<ISettingsRepository>(
    () => SettingsRepositoryImpl(sl()),
  );
  sl.registerLazySingleton<IEngineSelectionSource>(
    () => sl<ISettingsRepository>() as SettingsRepositoryImpl,
  );
  sl.registerLazySingleton<ITranslationRepository>(
    () => TranslationRepositoryImpl(sl(), sl(), sl<ISubscriptionRepository>()),
  );
  sl.registerLazySingleton<IAudioDeviceRepository>(
    () => AudioDeviceRepositoryImpl(sl<AsrWebSocketClient>()),
  );
  sl.registerLazySingleton<ISubscriptionRepository>(
    () => SubscriptionRepositoryImpl(service: sl<SubscriptionRemoteDataSource>()),
  );
  // Startup repositories
  sl.registerLazySingleton<startup_feature.IStartupRepository>(
    () => startup_feature.StartupRepositoryImpl(sl()),
  );
  sl.registerLazySingleton<startup_feature.IUpdateRepository>(
    () => startup_feature.UpdateRepositoryImpl(sl()),
  );

  // About's IUpdateRepository wraps startup's via the domain seam
  sl.registerLazySingleton<IUpdateRepository>(
    () => UpdateRepositoryImpl(sl<startup_feature.IUpdateRepository>()),
  );
  sl.registerLazySingleton<IHistoryRepository>(
    () => HistoryRepositoryImpl(localDataSource: sl()),
  );
  sl.registerLazySingleton<UsageRepository>(
    () => UsageRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<ISupportRepository>(
    () => SupportRepositoryImpl(
      localDataSource: sl(),
      remoteDataSource: sl(),
      usageRepository: sl(),
      firebaseAuth: sl(),
      deviceInfo: sl(),
    ),
  );
}
