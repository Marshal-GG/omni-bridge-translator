import 'package:omni_bridge/features/settings/domain/repositories/i_settings_repository.dart';
import 'package:omni_bridge/features/about/presentation/blocs/about_bloc.dart';
import 'package:omni_bridge/features/startup/presentation/blocs/startup_bloc.dart';
import 'package:omni_bridge/features/auth/presentation/blocs/auth_bloc.dart';
import 'package:omni_bridge/features/history/presentation/blocs/history_bloc.dart';
import 'package:omni_bridge/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:get_it/get_it.dart';
import 'package:omni_bridge/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:omni_bridge/features/translation/data/repositories/translation_repository_impl.dart';
import 'package:omni_bridge/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:omni_bridge/features/subscription/data/datasources/subscription_remote_datasource.dart';
import 'package:omni_bridge/features/subscription/data/datasources/tracking_remote_datasource.dart';
import 'package:omni_bridge/features/translation/data/datasources/asr_websocket_datasource.dart';
import 'package:omni_bridge/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:omni_bridge/features/settings/domain/usecases/get_app_settings_usecase.dart';
import 'package:omni_bridge/features/settings/domain/usecases/update_app_settings_usecase.dart';
import 'package:omni_bridge/features/settings/domain/usecases/get_google_credentials_usecase.dart';
import 'package:omni_bridge/features/settings/domain/usecases/load_devices_usecase.dart';
import 'package:omni_bridge/features/settings/domain/usecases/observe_audio_levels_usecase.dart';
import 'package:omni_bridge/features/settings/domain/usecases/sync_settings_usecase.dart';
import 'package:omni_bridge/features/settings/domain/usecases/log_event_usecase.dart';
import 'package:omni_bridge/features/settings/data/datasources/settings_remote_datasource.dart';
import 'package:omni_bridge/features/settings/presentation/blocs/settings_bloc.dart';
import 'package:omni_bridge/features/translation/domain/repositories/i_translation_repository.dart';
import 'package:omni_bridge/features/translation/presentation/blocs/translation_bloc.dart';
import 'package:omni_bridge/features/translation/domain/usecases/start_translation_usecase.dart';
import 'package:omni_bridge/features/translation/domain/usecases/stop_translation_usecase.dart';
import 'package:omni_bridge/features/translation/domain/usecases/update_volume_usecase.dart';
import 'package:omni_bridge/features/translation/domain/usecases/get_model_status_usecase.dart';
import 'package:omni_bridge/features/translation/domain/usecases/observe_quota_status_usecase.dart';
import 'package:omni_bridge/features/translation/domain/usecases/get_initial_quota_status_usecase.dart';
import 'package:omni_bridge/features/translation/domain/usecases/get_default_tier_usecase.dart';
import 'package:omni_bridge/features/translation/domain/usecases/observe_captions_usecase.dart';
import 'package:omni_bridge/features/translation/domain/usecases/update_translation_settings_usecase.dart';
import 'package:omni_bridge/features/translation/data/datasources/translation_rest_datasource.dart';
import 'package:omni_bridge/features/auth/domain/usecases/login_with_google_usecase.dart';
import 'package:omni_bridge/features/auth/domain/usecases/logout_usecase.dart';
import 'package:omni_bridge/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:omni_bridge/features/auth/domain/usecases/observe_auth_changes_usecase.dart';
import 'package:omni_bridge/features/history/data/repositories/history_repository_impl.dart';
import 'package:omni_bridge/features/history/data/datasources/history_local_datasource.dart';
import 'package:omni_bridge/features/history/domain/repositories/i_history_repository.dart';
import 'package:omni_bridge/features/history/domain/usecases/add_history_entry_usecase.dart';
import 'package:omni_bridge/features/history/domain/usecases/clear_history_usecase.dart';
import 'package:omni_bridge/features/history/domain/usecases/get_chunked_history_usecase.dart';
import 'package:omni_bridge/features/history/domain/usecases/get_live_history_usecase.dart';
import 'package:omni_bridge/features/history/domain/usecases/configure_history_usecase.dart';
import 'package:omni_bridge/features/subscription/domain/repositories/i_subscription_repository.dart';
import 'package:omni_bridge/features/subscription/data/repositories/subscription_repository.dart';
import 'package:omni_bridge/features/subscription/domain/usecases/get_subscription_status.dart';
import 'package:omni_bridge/features/subscription/domain/usecases/get_available_plans.dart';
import 'package:omni_bridge/features/subscription/domain/usecases/activate_trial.dart';
import 'package:omni_bridge/features/subscription/domain/usecases/open_checkout.dart';
import 'package:omni_bridge/features/subscription/domain/usecases/has_used_trial.dart';
import 'package:omni_bridge/features/about/domain/repositories/i_update_repository.dart';
import 'package:omni_bridge/features/about/data/repositories/update_repository.dart';
import 'package:omni_bridge/features/about/domain/usecases/check_for_update.dart';
import 'package:omni_bridge/features/startup/data/datasources/update_remote_datasource.dart';

final sl = GetIt.instance;

Future<void> setupInjection() async {
  // BLoCs
  sl.registerFactory(
    () => TranslationBloc(
      startTranslationUseCase: sl(),
      stopTranslationUseCase: sl(),
      updateVolumeUseCase: sl(),
      getModelStatusUseCase: sl(),
      observeCaptionsUseCase: sl(),
      observeQuotaStatusUseCase: sl(),
      getInitialQuotaStatusUseCase: sl(),
      getDefaultTierUseCase: sl(),
      updateTranslationSettingsUseCase: sl(),
      getCurrentUserUseCase: sl(),
      observeAuthChangesUseCase: sl(),
      getAppSettingsUseCase: sl(),
      getGoogleCredentialsUseCase: sl(),
      syncSettingsUseCase: sl(),
      logEventUseCase: sl(),
      logoutUseCase: sl(),
    ),
  );

  sl.registerFactory(
    () => SettingsBloc(
      getAppSettingsUseCase: sl(),
      updateAppSettingsUseCase: sl(),
      getGoogleCredentialsUseCase: sl(),
      loadDevicesUseCase: sl(),
      observeAudioLevelsUseCase: sl(),
      logEventUseCase: sl(),
    ),
  );

  sl.registerFactory(
    () => AboutBloc(
      checkForUpdate: sl(),
    ),
  );

  sl.registerFactory(
    () => StartupBloc(authRepository: sl()),
  );

  sl.registerFactory(
    () => AuthBloc(authRepository: sl()),
  );

  sl.registerFactory(
    () => HistoryBloc(
      getLiveHistoryUseCase: sl(),
      getChunkedHistoryUseCase: sl(),
      clearHistoryUseCase: sl(),
      subscriptionDataSource: sl(),
    ),
  );

  // Repositories
  sl.registerLazySingleton<IAuthRepository>(() => AuthRepositoryImpl(sl()));
  // Features - Settings
  sl.registerLazySingleton<ISettingsRemoteDataSource>(
    () => SettingsRemoteDataSourceImpl(sl<TrackingRemoteDataSource>()),
  );
  sl.registerLazySingleton<ISettingsRepository>(
    () => SettingsRepositoryImpl(sl()),
  );
  sl.registerLazySingleton<ITranslationRepository>(
    () => TranslationRepositoryImpl(sl(), sl(), sl()),
  );
  sl.registerLazySingleton<ISubscriptionRepository>(
    () => SubscriptionRepositoryImpl(service: sl()),
  );
  sl.registerLazySingleton<IUpdateRepository>(
    () => UpdateRepositoryImpl(sl()),
  );
  sl.registerLazySingleton<HistoryLocalDataSource>(
    () => HistoryLocalDataSource(),
  );
  sl.registerLazySingleton<IHistoryRepository>(
    () => HistoryRepositoryImpl(localDataSource: sl()),
  );

  // Use Cases
  // Auth
  sl.registerLazySingleton(() => LoginWithGoogleUseCase(sl()));
  sl.registerLazySingleton(() => LogoutUseCase(sl()));
  sl.registerLazySingleton(() => GetCurrentUserUseCase(sl()));
  sl.registerLazySingleton(() => ObserveAuthChangesUseCase(sl()));

  // Settings
  sl.registerLazySingleton(() => GetAppSettingsUseCase(sl()));
  sl.registerLazySingleton(() => UpdateAppSettingsUseCase(sl()));
  sl.registerLazySingleton(() => GetGoogleCredentialsUseCase(sl()));
  sl.registerLazySingleton(() => LoadDevicesUseCase(sl()));
  sl.registerLazySingleton(() => ObserveAudioLevelsUseCase(sl()));
  sl.registerLazySingleton(() => SyncSettingsUseCase(sl()));
  sl.registerLazySingleton(() => LogEventUseCase(sl()));

  // History
  sl.registerLazySingleton(() => AddHistoryEntryUseCase(repository: sl()));
  sl.registerLazySingleton(() => ClearHistoryUseCase(repository: sl()));
  sl.registerLazySingleton(() => ConfigureHistoryUseCase(repository: sl()));
  sl.registerLazySingleton(() => GetLiveHistoryUseCase(repository: sl()));
  sl.registerLazySingleton(() => GetChunkedHistoryUseCase(repository: sl()));

  // Translation
  sl.registerLazySingleton(() => StartTranslationUseCase(sl()));
  sl.registerLazySingleton(() => StopTranslationUseCase(sl()));
  sl.registerLazySingleton(() => UpdateVolumeUseCase(sl()));
  sl.registerLazySingleton(() => GetModelStatusUseCase(sl()));
  sl.registerLazySingleton(() => ObserveQuotaStatusUseCase(sl()));
  sl.registerLazySingleton(() => GetInitialQuotaStatusUseCase(sl()));
  sl.registerLazySingleton(() => GetDefaultTierUseCase(sl()));
  sl.registerLazySingleton(() => ObserveCaptionsUseCase(sl()));
  sl.registerLazySingleton(() => UpdateTranslationSettingsUseCase(sl()));

  // Subscription
  sl.registerLazySingleton(() => GetSubscriptionStatus(sl()));
  sl.registerLazySingleton(() => GetAvailablePlans(sl()));
  sl.registerLazySingleton(() => ActivateTrial(sl()));
  sl.registerLazySingleton(() => OpenCheckout(sl()));
  sl.registerLazySingleton(() => HasUsedTrial(sl()));

  // About
  sl.registerLazySingleton(() => CheckForUpdate(sl()));

  // Services / Datasources
  sl.registerLazySingleton(() => AuthRemoteDataSource.instance);
  sl.registerLazySingleton(() => TrackingRemoteDataSource.instance);
  sl.registerLazySingleton(
    () => AsrWebSocketClient(addHistoryEntry: sl(), configureHistory: sl()),
  );
  sl.registerLazySingleton(() => TranslationRestDatasource());
  sl.registerLazySingleton(() => SubscriptionRemoteDataSource.instance);
  sl.registerLazySingleton(() => UpdateRemoteDataSource.instance);
}
