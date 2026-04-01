import 'package:omni_bridge/core/di/injection.dart';
import 'package:omni_bridge/features/auth/auth.dart';
import 'package:omni_bridge/features/translation/translation.dart';
import 'package:omni_bridge/features/settings/settings.dart';
import 'package:omni_bridge/features/support/support.dart';
import 'package:omni_bridge/features/history/history.dart';
import 'package:omni_bridge/features/subscription/subscription.dart';
import 'package:omni_bridge/features/usage/usage.dart';
import 'package:omni_bridge/features/about/about.dart';

void initUseCaseDI() {
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
  sl.registerLazySingleton(() => GetSystemConfigUseCase(sl()));
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
  sl.registerLazySingleton(() => CheckServerHealthUseCase(sl()));
  sl.registerLazySingleton(() => LiveDeviceUpdateUseCase(sl()));
  sl.registerLazySingleton(() => LiveMicToggleUseCase(sl()));

  // Subscription
  sl.registerLazySingleton(() => GetSubscriptionStatus(sl()));
  sl.registerLazySingleton(() => GetAvailablePlans(sl()));
  sl.registerLazySingleton(() => ActivateTrial(sl()));
  sl.registerLazySingleton(() => OpenCheckout(sl()));
  sl.registerLazySingleton(() => HasUsedTrial(sl()));

  // About
  sl.registerLazySingleton(() => CheckForUpdate(sl()));

  // Support
  sl.registerLazySingleton(() => GetSupportLinksUseCase(sl()));
  sl.registerLazySingleton(() => GetSystemSnapshotUseCase(sl()));
  sl.registerLazySingleton(() => SubmitFeedbackUseCase(sl()));
  sl.registerLazySingleton(() => GetTicketHistoryUseCase(sl()));
  sl.registerLazySingleton(() => GetTicketMessagesUseCase(sl()));
  sl.registerLazySingleton(() => SendSupportMessageUseCase(sl()));

  // Usage
  sl.registerLazySingleton(
    () => GetUsageStats(sl(), sl<ISubscriptionRepository>()),
  );
  sl.registerLazySingleton(() => GetUsageHistory(sl()));
  sl.registerLazySingleton(() => GetQuotaStatus(sl()));
  sl.registerLazySingleton(() => CheckUsageRollover(sl(), sl()));
}
