import 'package:omni_bridge/features/settings/domain/repositories/i_settings_repository.dart';
import 'package:omni_bridge/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:get_it/get_it.dart';
import 'package:omni_bridge/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:omni_bridge/features/translation/data/repositories/translation_repository_impl.dart';
import 'package:omni_bridge/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:omni_bridge/data/services/firebase/subscription_service.dart';
import 'package:omni_bridge/data/services/firebase/tracking_service.dart';
import 'package:omni_bridge/features/translation/data/datasources/asr_websocket_datasource.dart';
import 'package:omni_bridge/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:omni_bridge/features/settings/domain/usecases/get_app_settings_usecase.dart';
import 'package:omni_bridge/features/settings/domain/usecases/update_app_settings_usecase.dart';
import 'package:omni_bridge/features/settings/domain/usecases/get_google_credentials_usecase.dart';
import 'package:omni_bridge/features/settings/data/datasources/settings_remote_datasource.dart';
import 'package:omni_bridge/features/settings/presentation/blocs/settings_bloc.dart';
import 'package:omni_bridge/features/translation/domain/repositories/i_translation_repository.dart';
import 'package:omni_bridge/features/translation/presentation/blocs/translation_bloc.dart';
import 'package:omni_bridge/features/translation/domain/usecases/start_translation_usecase.dart';
import 'package:omni_bridge/features/translation/domain/usecases/stop_translation_usecase.dart';
import 'package:omni_bridge/features/translation/domain/usecases/update_volume_usecase.dart';
import 'package:omni_bridge/features/translation/domain/usecases/get_model_status_usecase.dart';
import 'package:omni_bridge/features/translation/data/datasources/translation_rest_datasource.dart';
import 'package:omni_bridge/features/history/data/datasources/history_local_datasource.dart';
import 'package:omni_bridge/features/history/data/repositories/history_repository_impl.dart';
import 'package:omni_bridge/features/history/domain/repositories/i_history_repository.dart';
import 'package:omni_bridge/features/history/domain/usecases/add_history_entry_usecase.dart';
import 'package:omni_bridge/features/history/domain/usecases/clear_history_usecase.dart';
import 'package:omni_bridge/features/history/domain/usecases/get_chunked_history_usecase.dart';
import 'package:omni_bridge/features/history/domain/usecases/get_live_history_usecase.dart';
import 'package:omni_bridge/features/history/domain/usecases/configure_history_usecase.dart';

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
        getAppSettingsUseCase: sl(),
        updateAppSettingsUseCase: sl(),
        getGoogleCredentialsUseCase: sl(),
        translationRepo: sl(),
      ));

  // Repositories
  sl.registerLazySingleton<IAuthRepository>(() => AuthRepositoryImpl(sl()));
  // Features - Settings
  sl.registerLazySingleton<ISettingsRemoteDataSource>(
      () => SettingsRemoteDataSourceImpl(sl<TrackingService>()));
  sl.registerLazySingleton<ISettingsRepository>(
      () => SettingsRepositoryImpl(sl()));
  sl.registerLazySingleton<ITranslationRepository>(
      () => TranslationRepositoryImpl(sl(), sl(), sl()));

  // Use Cases
  sl.registerLazySingleton(() => StartTranslationUseCase(sl()));
  sl.registerLazySingleton(() => StopTranslationUseCase(sl()));
  sl.registerLazySingleton(() => UpdateVolumeUseCase(sl()));
  sl.registerLazySingleton(() => GetModelStatusUseCase(sl()));
  sl.registerLazySingleton(() => GetAppSettingsUseCase(sl()));
  sl.registerLazySingleton(() => UpdateAppSettingsUseCase(sl()));
  sl.registerLazySingleton(() => GetGoogleCredentialsUseCase(sl()));

  // Services / Datasources
  sl.registerLazySingleton(() => AuthRemoteDataSource.instance);
  sl.registerLazySingleton(() => TrackingService.instance);
  sl.registerLazySingleton(() => AsrWebSocketClient(
        addHistoryEntry: sl(),
        configureHistory: sl(),
      ));
  sl.registerLazySingleton(() => TranslationRestDatasource());
  sl.registerLazySingleton(() => SubscriptionService.instance);

  // History Dependencies
  sl.registerLazySingleton<HistoryLocalDataSource>(() => HistoryLocalDataSource());
  sl.registerLazySingleton<IHistoryRepository>(() => HistoryRepositoryImpl(localDataSource: sl()));
  
  sl.registerLazySingleton(() => AddHistoryEntryUseCase(repository: sl()));
  sl.registerLazySingleton(() => ClearHistoryUseCase(repository: sl()));
  sl.registerLazySingleton(() => ConfigureHistoryUseCase(repository: sl()));
  sl.registerLazySingleton(() => GetLiveHistoryUseCase(repository: sl()));
  sl.registerLazySingleton(() => GetChunkedHistoryUseCase(repository: sl()));
}




