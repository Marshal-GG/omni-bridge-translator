import 'package:get_it/get_it.dart';
import 'package:omni_bridge/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:omni_bridge/data/repositories/settings_repository_impl.dart';
import 'package:omni_bridge/features/translation/data/repositories/translation_repository_impl.dart';
import 'package:omni_bridge/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:omni_bridge/data/services/firebase/subscription_service.dart';
import 'package:omni_bridge/data/services/firebase/tracking_service.dart';
import 'package:omni_bridge/features/translation/data/datasources/asr_websocket_datasource.dart';
import 'package:omni_bridge/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:omni_bridge/domain/repositories/settings_repository.dart';
import 'package:omni_bridge/features/translation/domain/repositories/i_translation_repository.dart';
import 'package:omni_bridge/presentation/screens/settings/bloc/settings_bloc.dart';
import 'package:omni_bridge/features/translation/presentation/blocs/translation_bloc.dart';
import 'package:omni_bridge/features/translation/domain/usecases/start_translation_usecase.dart';
import 'package:omni_bridge/features/translation/domain/usecases/stop_translation_usecase.dart';
import 'package:omni_bridge/features/translation/domain/usecases/update_volume_usecase.dart';
import 'package:omni_bridge/features/translation/domain/usecases/get_model_status_usecase.dart';
import 'package:omni_bridge/features/translation/data/datasources/translation_rest_datasource.dart';

final sl = GetIt.instance;

Future<void> setupInjection() async {
  // BLoCs
  sl.registerFactory(() => TranslationBloc(
        translationRepo: sl<ITranslationRepository>(),
        authRepo: sl<IAuthRepository>(),
        settingsRepo: sl<ISettingsRepository>(),
        startTranslationUseCase: sl<StartTranslationUseCase>(),
        stopTranslationUseCase: sl<StopTranslationUseCase>(),
        updateVolumeUseCase: sl<UpdateVolumeUseCase>(),
        getModelStatusUseCase: sl<GetModelStatusUseCase>(),
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
      () => TranslationRepositoryImpl(sl(), sl(), sl()));

  // Use Cases
  sl.registerLazySingleton(() => StartTranslationUseCase(sl()));
  sl.registerLazySingleton(() => StopTranslationUseCase(sl()));
  sl.registerLazySingleton(() => UpdateVolumeUseCase(sl()));
  sl.registerLazySingleton(() => GetModelStatusUseCase(sl()));

  // Services / Datasources
  sl.registerLazySingleton(() => AuthRemoteDataSource.instance);
  sl.registerLazySingleton(() => TrackingService.instance);
  sl.registerLazySingleton(() => AsrWebSocketClient());
  sl.registerLazySingleton(() => TranslationRestDatasource());
  sl.registerLazySingleton(() => SubscriptionService.instance);
}




