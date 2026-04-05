import 'package:omni_bridge/core/di/injection.dart';
import 'package:omni_bridge/core/routes/my_nav_observer.dart';
import 'package:omni_bridge/core/navigation/route_change_notifier.dart';
import 'package:omni_bridge/features/auth/auth.dart';
import 'package:omni_bridge/features/translation/translation.dart';
import 'package:omni_bridge/features/settings/settings.dart';
import 'package:omni_bridge/features/support/support.dart';
import 'package:omni_bridge/features/history/history.dart';
import 'package:omni_bridge/features/subscription/subscription.dart';
import 'package:omni_bridge/features/usage/usage.dart';
import 'package:omni_bridge/features/startup/startup.dart';
import 'package:omni_bridge/features/about/about.dart';
import 'package:omni_bridge/features/shell/presentation/blocs/app_shell_bloc.dart';

void initBlocDI() {
  // BLoCs
  sl.registerFactory(
    () => TranslationBloc(
      startTranslationUseCase: sl(),
      stopTranslationUseCase: sl(),
      getModelStatusUseCase: sl(),
      observeCaptionsUseCase: sl(),
      observeQuotaStatusUseCase: sl(),
      getInitialQuotaStatusUseCase: sl(),
      updateTranslationSettingsUseCase: sl(),
      checkServerHealthUseCase: sl(),
      getCurrentUserUseCase: sl(),
      getAppSettingsUseCase: sl(),
      getGoogleCredentialsUseCase: sl(),
      syncSettingsUseCase: sl(),
      logEventUseCase: sl(),
      getSystemConfigUseCase: sl(),
      unloadModelUseCase: sl(),
      checkModelAccessUseCase: sl(),
      checkEngineLimitUseCase: sl(),
    ),
  );

  sl.registerFactory(
    () => SettingsBloc(
      getAppSettingsUseCase: sl(),
      updateAppSettingsUseCase: sl(),
      getGoogleCredentialsUseCase: sl(),
      loadDevicesUseCase: sl(),
      logEventUseCase: sl(),
      getSubscriptionStatus: sl(),
      updateVolumeUseCase: sl(),
      liveDeviceUpdateUseCase: sl(),
      liveMicToggleUseCase: sl(),
    ),
  );

  sl.registerFactory(() => AudioLevelCubit(observeAudioLevelsUseCase: sl()));

  sl.registerFactory(() => AboutBloc(checkForUpdate: sl()));

  sl.registerFactory(() => StartupBloc(authRepository: sl()));

  sl.registerFactory(() => AuthBloc(authRepository: sl()));

  sl.registerLazySingleton(
    () => AppShellBloc(
      getCurrentUser: sl(),
      observeAuthChanges: sl(),
      getSubscriptionStatus: sl(),
    ),
  );

  // Register the abstract RouteChangeNotifier pointing to AppShellBloc
  sl.registerLazySingleton<RouteChangeNotifier>(() => sl<AppShellBloc>());

  sl.registerFactory(
    () => SubscriptionBloc(
      getStatus: sl(),
      getPlans: sl(),
      activateTrial: sl(),
      openCheckout: sl(),
      hasUsedTrial: sl(),
    ),
  );

  sl.registerFactory(
    () => HistoryBloc(
      getLiveHistoryUseCase: sl(),
      getChunkedHistoryUseCase: sl(),
      clearHistoryUseCase: sl(),
      subscriptionDataSource: sl(),
    ),
  );

  sl.registerFactory(
    () => SupportBloc(
      getSupportLinks: sl(),
      getSystemSnapshot: sl(),
      submitFeedback: sl(),
      getTicketHistory: sl(),
      getTicketMessages: sl(),
      sendSupportMessage: sl(),
    ),
  );

  sl.registerFactory(
    () => UsageBloc(
      getUsageStats: sl(),
      getUsageHistory: sl(),
      getQuotaStatus: sl(),
      checkUsageRollover: sl(),
      getSelectedEngines: sl(),
    ),
  );

  // Navigation Observer (singleton so its route stream persists)
  sl.registerLazySingleton(() => MyNavigatorObserver());
}
