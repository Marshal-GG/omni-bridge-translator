import 'package:omni_bridge/core/di/injection.dart';
import 'package:omni_bridge/features/auth/auth.dart';
import 'package:omni_bridge/features/translation/translation.dart';
import 'package:omni_bridge/features/settings/settings.dart';
import 'package:omni_bridge/features/support/support.dart';
import 'package:omni_bridge/features/history/history.dart';
import 'package:omni_bridge/features/subscription/subscription.dart';
import 'package:omni_bridge/features/usage/usage.dart';
import 'package:omni_bridge/features/about/about.dart';

void initRepositoryDI() {
  sl.registerLazySingleton<IAuthRepository>(() => AuthRepositoryImpl(sl()));
  sl.registerLazySingleton<ISettingsRepository>(
    () => SettingsRepositoryImpl(sl()),
  );
  sl.registerLazySingleton<ITranslationRepository>(
    () => TranslationRepositoryImpl(sl(), sl(), sl()),
  );
  sl.registerLazySingleton<IAudioDeviceRepository>(
    () => AudioDeviceRepositoryImpl(sl<AsrWebSocketClient>()),
  );
  sl.registerLazySingleton<ISubscriptionRepository>(
    () => SubscriptionRepositoryImpl(service: sl()),
  );
  sl.registerLazySingleton<IUpdateRepository>(() => UpdateRepositoryImpl(sl()));
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
