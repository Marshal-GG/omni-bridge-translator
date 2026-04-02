import 'package:omni_bridge/features/translation/data/datasources/translation_rest_datasource.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:omni_bridge/features/translation/presentation/blocs/translation_bloc.dart';
import 'package:omni_bridge/features/translation/presentation/blocs/translation_event.dart';
import 'package:omni_bridge/features/translation/presentation/blocs/translation_state.dart';
import 'package:omni_bridge/features/translation/domain/usecases/start_translation_usecase.dart';
import 'package:omni_bridge/features/translation/domain/usecases/stop_translation_usecase.dart';
import 'package:omni_bridge/features/translation/domain/usecases/get_model_status_usecase.dart';
import 'package:omni_bridge/features/translation/domain/usecases/observe_captions_usecase.dart';
import 'package:omni_bridge/features/translation/domain/usecases/observe_quota_status_usecase.dart';
import 'package:omni_bridge/features/translation/domain/usecases/get_initial_quota_status_usecase.dart';
import 'package:omni_bridge/features/translation/domain/usecases/update_translation_settings_usecase.dart';
import 'package:omni_bridge/features/settings/domain/usecases/log_event_usecase.dart';
import 'package:omni_bridge/features/translation/domain/usecases/unload_model_usecase.dart';
import 'package:omni_bridge/features/subscription/domain/usecases/check_model_access_usecase.dart';
import 'package:omni_bridge/features/subscription/domain/usecases/check_engine_limit_usecase.dart';
import 'package:omni_bridge/features/translation/domain/usecases/check_server_health_usecase.dart';
import 'package:omni_bridge/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:omni_bridge/features/settings/domain/usecases/get_app_settings_usecase.dart';
import 'package:omni_bridge/features/settings/domain/usecases/get_google_credentials_usecase.dart';
import 'package:omni_bridge/features/settings/domain/usecases/sync_settings_usecase.dart';
import 'package:omni_bridge/features/settings/domain/usecases/get_system_config_usecase.dart';
import 'package:omni_bridge/features/settings/domain/entities/system_config.dart';
import 'package:omni_bridge/features/subscription/data/datasources/subscription_remote_datasource.dart';
import 'package:omni_bridge/features/usage/domain/entities/quota_status.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:omni_bridge/features/settings/domain/entities/app_settings.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter_test/flutter_test.dart';

class MockStartTranslationUseCase extends Mock
    implements StartTranslationUseCase {}

class MockStopTranslationUseCase extends Mock
    implements StopTranslationUseCase {}

class MockGetModelStatusUseCase extends Mock implements GetModelStatusUseCase {}

class MockObserveCaptionsUseCase extends Mock
    implements ObserveCaptionsUseCase {}

class MockObserveQuotaStatusUseCase extends Mock
    implements ObserveQuotaStatusUseCase {}

class MockGetInitialQuotaStatusUseCase extends Mock
    implements GetInitialQuotaStatusUseCase {}

class MockUpdateTranslationSettingsUseCase extends Mock
    implements UpdateTranslationSettingsUseCase {}

class MockCheckServerHealthUseCase extends Mock
    implements CheckServerHealthUseCase {}

class MockGetCurrentUserUseCase extends Mock implements GetCurrentUserUseCase {}

class MockGetAppSettingsUseCase extends Mock implements GetAppSettingsUseCase {}

class MockGetGoogleCredentialsUseCase extends Mock
    implements GetGoogleCredentialsUseCase {}

class MockSyncSettingsUseCase extends Mock implements SyncSettingsUseCase {}

class MockLogEventUseCase extends Mock implements LogEventUseCase {}

class MockGetSystemConfigUseCase extends Mock
    implements GetSystemConfigUseCase {}

class MockSubscriptionRemoteDataSource extends Mock
    implements SubscriptionRemoteDataSource {}

class MockTranslationRestDatasource extends Mock
    implements TranslationRestDatasource {}

class MockUnloadModelUseCase extends Mock implements UnloadModelUseCase {}

class MockCheckModelAccessUseCase extends Mock
    implements CheckModelAccessUseCase {}

class MockCheckEngineLimitUseCase extends Mock
    implements CheckEngineLimitUseCase {}

void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(
      QuotaStatus(
        tier: 'free',
        dailyTokensUsed: 0,
        weeklyTokensUsed: 0,
        monthlyTokensUsed: 0,
        lifetimeTokensUsed: 0,
        dailyLimit: 0,
        dailyResetAt: DateTime.now(),
      ),
    );
  });

  late MockStartTranslationUseCase mockStartTranslationUseCase;
  late MockStopTranslationUseCase mockStopTranslationUseCase;
  late MockGetModelStatusUseCase mockGetModelStatusUseCase;
  late MockObserveCaptionsUseCase mockObserveCaptionsUseCase;
  late MockObserveQuotaStatusUseCase mockObserveQuotaStatusUseCase;
  late MockGetInitialQuotaStatusUseCase mockGetInitialQuotaStatusUseCase;
  late MockUpdateTranslationSettingsUseCase
  mockUpdateTranslationSettingsUseCase;
  late MockCheckServerHealthUseCase mockCheckServerHealthUseCase;
  late MockGetCurrentUserUseCase mockGetCurrentUserUseCase;
  late MockGetAppSettingsUseCase mockGetAppSettingsUseCase;
  late MockGetGoogleCredentialsUseCase mockGetGoogleCredentialsUseCase;
  late MockSyncSettingsUseCase mockSyncSettingsUseCase;
  late MockLogEventUseCase mockLogEventUseCase;
  late MockGetSystemConfigUseCase mockGetSystemConfigUseCase;
  late MockSubscriptionRemoteDataSource mockSubscriptionDataSource;

  late MockUnloadModelUseCase mockUnloadModelUseCase;
  late MockCheckModelAccessUseCase mockCheckModelAccessUseCase;
  late MockCheckEngineLimitUseCase mockCheckEngineLimitUseCase;

  setUp(() {
    mockStartTranslationUseCase = MockStartTranslationUseCase();
    mockStopTranslationUseCase = MockStopTranslationUseCase();
    mockGetModelStatusUseCase = MockGetModelStatusUseCase();
    mockObserveCaptionsUseCase = MockObserveCaptionsUseCase();
    mockObserveQuotaStatusUseCase = MockObserveQuotaStatusUseCase();
    mockGetInitialQuotaStatusUseCase = MockGetInitialQuotaStatusUseCase();
    mockUpdateTranslationSettingsUseCase =
        MockUpdateTranslationSettingsUseCase();
    mockCheckServerHealthUseCase = MockCheckServerHealthUseCase();
    mockGetCurrentUserUseCase = MockGetCurrentUserUseCase();
    mockGetAppSettingsUseCase = MockGetAppSettingsUseCase();
    mockGetGoogleCredentialsUseCase = MockGetGoogleCredentialsUseCase();
    mockSyncSettingsUseCase = MockSyncSettingsUseCase();
    mockLogEventUseCase = MockLogEventUseCase();
    mockGetSystemConfigUseCase = MockGetSystemConfigUseCase();
    mockSubscriptionDataSource = MockSubscriptionRemoteDataSource();

    mockUnloadModelUseCase = MockUnloadModelUseCase();
    mockCheckModelAccessUseCase = MockCheckModelAccessUseCase();
    mockCheckEngineLimitUseCase = MockCheckEngineLimitUseCase();

    when(() => mockGetInitialQuotaStatusUseCase.call()).thenReturn(null);
    when(() => mockStopTranslationUseCase.call()).thenAnswer((_) async {});
    when(
      () => mockStartTranslationUseCase.call(
        sourceLang: any(named: 'sourceLang'),
        targetLang: any(named: 'targetLang'),
        useMic: any(named: 'useMic'),
        inputDeviceIndex: any(named: 'inputDeviceIndex'),
        outputDeviceIndex: any(named: 'outputDeviceIndex'),
        translationModel: any(named: 'translationModel'),
        nvidiaNimKey: any(named: 'nvidiaNimKey'),
        googleCredentials: any(named: 'googleCredentials'),
        transcriptionModel: any(named: 'transcriptionModel'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockObserveQuotaStatusUseCase.call(),
    ).thenAnswer((_) => Stream.empty());
    when(
      () => mockObserveCaptionsUseCase.call(),
    ).thenAnswer((_) => Stream.empty());
    when(
      () => mockGetCurrentUserUseCase.call(),
    ).thenReturn(ValueNotifier<auth.User?>(null));
    when(() => mockGetModelStatusUseCase.call()).thenAnswer((_) async => []);
    when(
      () => mockGetAppSettingsUseCase.call(),
    ).thenAnswer((_) async => const Right(null));
    when(
      () => mockGetGoogleCredentialsUseCase.call(),
    ).thenAnswer((_) async => const Right(''));
    when(
      () => mockUnloadModelUseCase.call(),
    ).thenAnswer((_) async => true);
    when(
      () => mockCheckServerHealthUseCase.call(),
    ).thenAnswer((_) async => true);
    when(
      () => mockGetSystemConfigUseCase.call(),
    ).thenAnswer((_) async => Right(SystemConfig.initial()));
    when(
      () => mockCheckModelAccessUseCase.isTranslationModelAllowed(any(), any()),
    ).thenReturn(true);
    when(
      () => mockCheckModelAccessUseCase.isTranscriptionModelAllowed(any(), any()),
    ).thenReturn(true);
    when(
      () => mockCheckEngineLimitUseCase.shouldShowNotice(any()),
    ).thenReturn(false);
    when(
      () => mockSubscriptionDataSource.allowedTranslationModels(any()),
    ).thenReturn(['google']);
    when(
      () => mockSubscriptionDataSource.allowedTranscriptionModels(any()),
    ).thenReturn(['online']);
  });

  TranslationBloc createBloc() {
    return TranslationBloc(
      startTranslationUseCase: mockStartTranslationUseCase,
      stopTranslationUseCase: mockStopTranslationUseCase,
      getModelStatusUseCase: mockGetModelStatusUseCase,
      observeCaptionsUseCase: mockObserveCaptionsUseCase,
      observeQuotaStatusUseCase: mockObserveQuotaStatusUseCase,
      getInitialQuotaStatusUseCase: mockGetInitialQuotaStatusUseCase,
      updateTranslationSettingsUseCase: mockUpdateTranslationSettingsUseCase,
      checkServerHealthUseCase: mockCheckServerHealthUseCase,
      getCurrentUserUseCase: mockGetCurrentUserUseCase,
      getAppSettingsUseCase: mockGetAppSettingsUseCase,
      getGoogleCredentialsUseCase: mockGetGoogleCredentialsUseCase,
      syncSettingsUseCase: mockSyncSettingsUseCase,
      logEventUseCase: mockLogEventUseCase,
      getSystemConfigUseCase: mockGetSystemConfigUseCase,
      unloadModelUseCase: mockUnloadModelUseCase,
      checkModelAccessUseCase: mockCheckModelAccessUseCase,
      checkEngineLimitUseCase: mockCheckEngineLimitUseCase,
    );
  }

  group('Initialization', () {
    blocTest<TranslationBloc, TranslationState>(
      'emits states during initialization',
      build: () {
        when(
          () => mockSubscriptionDataSource.allowedTranslationModels(any()),
        ).thenReturn(['google', 'mymemory']);
        when(
          () => mockSubscriptionDataSource.allowedTranscriptionModels(any()),
        ).thenReturn(['online']);
        when(
          () => mockObserveQuotaStatusUseCase.call(),
        ).thenAnswer((_) => Stream.empty());
        when(
          () => mockObserveCaptionsUseCase.call(),
        ).thenAnswer((_) => Stream.empty());
        return createBloc();
      },
      act: (bloc) => bloc.add(InitializeEvent()),
      expect: () => [
        // UpdateQuotaEvent
        isA<TranslationState>().having((s) => s.quotaStatus, 'quotaStatus', isNotNull),
      ],
    );
  });

  group('ToggleRunningEvent', () {
    blocTest<TranslationBloc, TranslationState>(
      'starts translation when toggled from stopped state',
      build: () {
        when(
          () => mockSubscriptionDataSource.allowedTranslationModels(any()),
        ).thenReturn(['google', 'mymemory']);
        when(
          () => mockSubscriptionDataSource.allowedTranscriptionModels(any()),
        ).thenReturn(['online']);
        when(
          () => mockStartTranslationUseCase.call(
            sourceLang: any(named: 'sourceLang'),
            targetLang: any(named: 'targetLang'),
            useMic: any(named: 'useMic'),
            inputDeviceIndex: any(named: 'inputDeviceIndex'),
            outputDeviceIndex: any(named: 'outputDeviceIndex'),
            translationModel: any(named: 'translationModel'),
            nvidiaNimKey: any(named: 'nvidiaNimKey'),
            googleCredentials: any(named: 'googleCredentials'),
            transcriptionModel: any(named: 'transcriptionModel'),
          ),
        ).thenAnswer((_) async {});

        return createBloc();
      },
      act: (bloc) => bloc.add(ToggleRunningEvent()),
      expect: () => [
        isA<TranslationState>().having((s) => s.isRunning, 'isRunning', true),
      ],
    );

    blocTest<TranslationBloc, TranslationState>(
      'stops translation when toggled from running state',
      build: () {
        when(
          () => mockSubscriptionDataSource.allowedTranslationModels(any()),
        ).thenReturn(['google', 'mymemory']);
        when(
          () => mockSubscriptionDataSource.allowedTranscriptionModels(any()),
        ).thenReturn(['online']);
        when(() => mockStopTranslationUseCase.call()).thenAnswer((_) async {});
        when(
          () => mockStartTranslationUseCase.call(
            sourceLang: any(named: 'sourceLang'),
            targetLang: any(named: 'targetLang'),
            useMic: any(named: 'useMic'),
            inputDeviceIndex: any(named: 'inputDeviceIndex'),
            outputDeviceIndex: any(named: 'outputDeviceIndex'),
            translationModel: any(named: 'translationModel'),
            nvidiaNimKey: any(named: 'nvidiaNimKey'),
            googleCredentials: any(named: 'googleCredentials'),
            transcriptionModel: any(named: 'transcriptionModel'),
          ),
        ).thenAnswer((_) async {});

        return createBloc();
      },
      seed: () => TranslationState.initial().copyWith(isRunning: true),
      act: (bloc) => bloc.add(ToggleRunningEvent()),
      expect: () => [
        isA<TranslationState>().having((s) => s.isRunning, 'isRunning', false),
      ],
    );

    blocTest<TranslationBloc, TranslationState>(
      'ignores ToggleRunningEvent when not running and server is disconnected',
      build: () {
        return createBloc();
      },
      seed: () => TranslationState.initial().copyWith(
        isRunning: false,
        isServerConnected: false,
      ),
      act: (bloc) => bloc.add(ToggleRunningEvent()),
      expect: () => [],
      verify: (_) {
        verifyNever(
          () => mockStartTranslationUseCase.call(
            sourceLang: any(named: 'sourceLang'),
            targetLang: any(named: 'targetLang'),
            useMic: any(named: 'useMic'),
            inputDeviceIndex: any(named: 'inputDeviceIndex'),
            outputDeviceIndex: any(named: 'outputDeviceIndex'),
            translationModel: any(named: 'translationModel'),
            nvidiaNimKey: any(named: 'nvidiaNimKey'),
            googleCredentials: any(named: 'googleCredentials'),
            transcriptionModel: any(named: 'transcriptionModel'),
          ),
        );
      },
    );
  });

  group('UpdateServerConnectionEvent', () {
    blocTest<TranslationBloc, TranslationState>(
      'updates isServerConnected when UpdateServerConnectionEvent is added',
      build: () => createBloc(),
      act: (bloc) =>
          bloc.add(const UpdateServerConnectionEvent(isConnected: false)),
      expect: () => [
        isA<TranslationState>().having(
          (s) => s.isServerConnected,
          'isServerConnected',
          false,
        ),
      ],
    );
  });

  group('UpdateQuotaEvent', () {
    final proStatus = QuotaStatus(
      tier: 'pro',
      dailyTokensUsed: 0,
      weeklyTokensUsed: 0,
      monthlyTokensUsed: 0,
      lifetimeTokensUsed: 0,
      dailyLimit: 1000,
      dailyResetAt: DateTime(2025),
    );

    final freeStatus = QuotaStatus(
      tier: 'free',
      dailyTokensUsed: 0,
      weeklyTokensUsed: 0,
      monthlyTokensUsed: 0,
      lifetimeTokensUsed: 0,
      dailyLimit: 1000, // Not exceeded
      dailyResetAt: DateTime(2025),
    );

    blocTest<TranslationBloc, TranslationState>(
      'unloads models and resets settings on tier downgrade if current models not allowed',
      build: () {
        when(
          () => mockGetInitialQuotaStatusUseCase.call(),
        ).thenReturn(proStatus);
        when(
          () => mockSubscriptionDataSource.allowedTranslationModels('free'),
        ).thenReturn(['google']);
        when(
          () => mockSubscriptionDataSource.allowedTranscriptionModels('free'),
        ).thenReturn(['online']);
        when(
          () => mockUnloadModelUseCase.call(),
        ).thenAnswer((_) async => true);
        when(() => mockStopTranslationUseCase.call()).thenAnswer((_) async {});
        when(
          () => mockObserveQuotaStatusUseCase.call(),
        ).thenAnswer((_) => Stream.empty());
        when(
          () => mockObserveCaptionsUseCase.call(),
        ).thenAnswer((_) => Stream.empty());
        when(
          () => mockUpdateTranslationSettingsUseCase.call(
            targetLang: any(named: 'targetLang'),
            sourceLang: any(named: 'sourceLang'),
            useMic: any(named: 'useMic'),
            inputDeviceIndex: any(named: 'inputDeviceIndex'),
            outputDeviceIndex: any(named: 'outputDeviceIndex'),
            desktopVolume: any(named: 'desktopVolume'),
            micVolume: any(named: 'micVolume'),
            translationModel: any(named: 'translationModel'),
            nvidiaNimKey: any(named: 'nvidiaNimKey'),
            googleCredentials: any(named: 'googleCredentials'),
            transcriptionModel: any(named: 'transcriptionModel'),
          ),
        ).thenAnswer((_) async {});

        // Return llama/whisper first, then defaults on subsequent calls
        var callCount = 0;
        when(() => mockGetAppSettingsUseCase.call()).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) {
            return Right(
              AppSettings.initial().copyWith(
                translationModel: 'llama',
                transcriptionModel: 'whisper',
              ),
            );
          }
          return Right(AppSettings.initial());
        });

        return createBloc();
      },
      seed: () => TranslationState.initial().copyWith(
        quotaStatus: proStatus,
        activeTranslationModel: 'llama',
        activeTranscriptionModel: 'whisper',
        isRunning: true,
      ),
      act: (bloc) async {
        await Future.delayed(const Duration(milliseconds: 100));
        bloc.add(UpdateQuotaEvent(freeStatus));
      },
      wait: const Duration(milliseconds: 200),
      expect: () => [
        // 1. Quota update only (tier changed to free)
        isA<TranslationState>()
            .having((s) => s.quotaStatus?.tier, 'new tier', 'free')
            .having((s) => s.activeTranslationModel, 'still llama', 'llama'),
        // 2. Internal reset (isRunning: false, models: google/online)
        isA<TranslationState>()
            .having((s) => s.isRunning, 'isRunning', false)
            .having(
              (s) => s.activeTranslationModel,
              'activeTranslationModel',
              'google',
            )
            .having(
              (s) => s.activeTranscriptionModel,
              'activeTranscriptionModel',
              'online',
            ),
        // 3. LoadSettingsEvent start
        isA<TranslationState>().having(
          (s) => s.isSettingsLoading,
          'isSettingsLoading',
          true,
        ),
        // 4. LoadSettingsEvent finish (should remain google/online if we mock it right)
        isA<TranslationState>().having(
          (s) => s.isSettingsLoading,
          'isSettingsLoading',
          false,
        ),
        // 5. ApplySettingsEvent (triggered by LoadSettingsEvent) start
        isA<TranslationState>().having(
          (s) => s.isSettingsSaving,
          'isSettingsSaving',
          true,
        ),
        // 6. ApplySettingsEvent finish
        isA<TranslationState>().having(
          (s) => s.isSettingsSaving,
          'isSettingsSaving',
          false,
        ),
      ],
      verify: (_) {
        verify(() => mockStopTranslationUseCase.call()).called(2);
        verify(() => mockUnloadModelUseCase.call()).called(1);
        verify(
          () => mockUpdateTranslationSettingsUseCase.call(
            targetLang: any(named: 'targetLang'),
            sourceLang: any(named: 'sourceLang'),
            useMic: any(named: 'useMic'),
            inputDeviceIndex: any(named: 'inputDeviceIndex'),
            outputDeviceIndex: any(named: 'outputDeviceIndex'),
            desktopVolume: any(named: 'desktopVolume'),
            micVolume: any(named: 'micVolume'),
            translationModel: 'google',
            nvidiaNimKey: any(named: 'nvidiaNimKey'),
            googleCredentials: '',
            transcriptionModel: 'online',
          ),
        ).called(2);
      },
    );
  });
}
