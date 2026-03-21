import 'package:get_it/get_it.dart';
import 'package:omni_bridge/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:omni_bridge/data/repositories/settings_repository_impl.dart';
import 'package:omni_bridge/data/repositories/translation_repository_impl.dart';
import 'package:omni_bridge/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:omni_bridge/data/services/firebase/subscription_service.dart';
import 'package:omni_bridge/data/services/firebase/tracking_service.dart';
import 'package:omni_bridge/data/services/server/asr_ws_client.dart';
import 'package:omni_bridge/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:omni_bridge/domain/repositories/settings_repository.dart';
import 'package:omni_bridge/domain/repositories/translation_repository.dart';
import 'package:omni_bridge/presentation/screens/settings/bloc/settings_bloc.dart';
import 'package:omni_bridge/presentation/screens/translation/bloc/translation_bloc.dart';

final sl = GetIt.instance;

Future<void> setupInjection() async {
  // BLoCs
  sl.registerFactory(() => TranslationBloc(
        translationRepo: sl<ITranslationRepository>(),
        authRepo: sl<IAuthRepository>(),
        settingsRepo: sl<ISettingsRepository>(),
      ));

  sl.registerFactory(() => SettingsBloc(
        settingsRepo: sl<ISettingsRepository>(),
        translationRepo: sl<ITranslationRepository>(),
      ));

  // Repositories
  sl.registerLazySingleton<IAuthRepository>(() => AuthRepositoryImpl(sl()));
  sl.registerLazySingleton<ISettingsRepository>(
      () => SettingsRepositoryImpl(sl()));
  sl.registerLazySingleton<ITranslationRepository>(
      () => TranslationRepositoryImpl(sl(), sl()));

  // Services
  sl.registerLazySingleton(() => AuthRemoteDataSource.instance);
  sl.registerLazySingleton(() => TrackingService.instance);
  sl.registerLazySingleton(() => AsrWebSocketClient());
  sl.registerLazySingleton(() => SubscriptionService.instance);
}




