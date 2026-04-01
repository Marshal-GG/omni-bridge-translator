import 'package:firebase_storage/firebase_storage.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:omni_bridge/core/data/core_data.dart';
import 'package:omni_bridge/core/network/rtdb_client.dart';
import 'package:omni_bridge/features/auth/auth.dart';
import 'package:omni_bridge/features/translation/translation.dart';
import 'package:omni_bridge/features/settings/settings.dart';
import 'package:omni_bridge/features/support/support.dart';
import 'package:omni_bridge/features/history/history.dart';
import 'package:omni_bridge/features/subscription/subscription.dart';
import 'package:omni_bridge/features/usage/usage.dart';
import 'package:omni_bridge/features/startup/startup.dart';
import 'package:omni_bridge/core/di/injection.dart';

void initDataSourceDI() {
  // Services / Datasources
  sl.registerLazySingleton(() => AuthRemoteDataSource.instance);
  sl.registerLazySingleton(
    () => AsrWebSocketClient(addHistoryEntry: sl(), configureHistory: sl()),
  );
  sl.registerLazySingleton(() => TranslationRestDatasource());
  sl.registerLazySingleton(() => SubscriptionRemoteDataSource.instance);
  sl.registerLazySingleton(() => UpdateRemoteDataSource.instance);
  sl.registerLazySingleton(() => SessionRemoteDataSource.instance);
  sl.registerLazySingleton(() => UsageMetricsRemoteDataSource.instance);
  sl.registerLazySingleton(() => UsageRemoteDataSource.instance);
  sl.registerLazySingleton(() => DataMaintenanceRemoteDataSource.instance);
  sl.registerLazySingleton(() => LiveCaptionSyncDataSource.instance);
  sl.registerLazySingleton(() => TranscriptionRemoteDataSource.instance);
  sl.registerLazySingleton(() => RTDBClient.instance);
  sl.registerLazySingleton<ISettingsRemoteDataSource>(
    () => SettingsRemoteDataSourceImpl(),
  );
  sl.registerLazySingleton<HistoryLocalDataSource>(
    () => HistoryLocalDataSource(),
  );

  // --- Resettable Components (for Logout Cleanup) ---
  sl.registerLazySingleton<IResettable>(
    () => AuthRemoteDataSource.instance,
    instanceName: 'auth_reset',
  );
  sl.registerLazySingleton<IResettable>(
    () => SubscriptionRemoteDataSource.instance,
    instanceName: 'sub_reset',
  );
  sl.registerLazySingleton<IResettable>(
    () => SessionRemoteDataSource.instance,
    instanceName: 'session_reset',
  );
  sl.registerLazySingleton<IResettable>(
    () => UsageMetricsRemoteDataSource.instance,
    instanceName: 'metrics_reset',
  );
  sl.registerLazySingleton<IResettable>(
    () => UsageRemoteDataSource.instance,
    instanceName: 'usage_reset',
  );
  sl.registerLazySingleton<IResettable>(
    () => sl<ISettingsRemoteDataSource>() as IResettable,
    instanceName: 'settings_reset',
  );
  sl.registerLazySingleton<IResettable>(
    () => TranscriptionRemoteDataSource.instance,
    instanceName: 'transcription_reset',
  );
  sl.registerLazySingleton<IResettable>(
    () => RTDBClient.instance,
    instanceName: 'rtdb_reset',
  );
  sl.registerLazySingleton<IResettable>(
    () => sl<HistoryLocalDataSource>(),
    instanceName: 'history_reset',
  );
  sl.registerLazySingleton<IResettable>(
    () => sl<ISupportLocalDataSource>() as IResettable,
    instanceName: 'support_local_reset',
  );
  sl.registerLazySingleton<IResettable>(
    () => sl<ITranslationRepository>(),
    instanceName: 'translation_reset',
  );
  sl.registerLazySingleton<IResettable>(
    () => sl<LiveCaptionSyncDataSource>(),
    instanceName: 'live_caption_reset',
  );

  sl.registerLazySingleton<ISupportLocalDataSource>(
    () => SupportLocalDataSourceImpl(),
  );
  sl.registerLazySingleton<ISupportRemoteDataSource>(
    () => SupportRemoteDataSourceImpl(firestore: sl(), storage: sl()),
  );

  // External
  sl.registerLazySingleton(() => FirebaseStorage.instance);
  sl.registerLazySingleton(() => AuthRemoteDataSource.instance.auth);
  sl.registerLazySingleton(() => AuthRemoteDataSource.instance.firestore);
  sl.registerLazySingleton(() => DeviceInfoPlugin());
}
