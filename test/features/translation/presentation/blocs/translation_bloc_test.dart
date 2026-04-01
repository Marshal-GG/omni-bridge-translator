import 'package:omni_bridge/features/translation/data/datasources/translation_rest_datasource.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:omni_bridge/features/translation/presentation/blocs/translation_bloc.dart';
import 'package:omni_bridge/features/translation/presentation/blocs/translation_event.dart';
import 'package:omni_bridge/features/translation/presentation/blocs/translation_state.dart';
import 'package:omni_bridge/features/translation/domain/usecases/start_translation_usecase.dart';
import 'package:omni_bridge/features/translation/domain/usecases/stop_translation_usecase.dart';
import 'package:omni_bridge/features/translation/domain/usecases/update_volume_usecase.dart';
import 'package:omni_bridge/features/translation/domain/usecases/get_model_status_usecase.dart';
import 'package:omni_bridge/features/translation/domain/usecases/observe_captions_usecase.dart';
import 'package:omni_bridge/features/translation/domain/usecases/observe_quota_status_usecase.dart';
import 'package:omni_bridge/features/translation/domain/usecases/get_initial_quota_status_usecase.dart';
import 'package:omni_bridge/features/translation/domain/usecases/get_default_tier_usecase.dart';
import 'package:omni_bridge/features/translation/domain/usecases/update_translation_settings_usecase.dart';
import 'package:omni_bridge/features/translation/domain/usecases/live_device_update_usecase.dart';
import 'package:omni_bridge/features/translation/domain/usecases/live_mic_toggle_usecase.dart';
import 'package:omni_bridge/features/translation/domain/usecases/check_server_health_usecase.dart';
import 'package:omni_bridge/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:omni_bridge/features/auth/domain/usecases/observe_auth_changes_usecase.dart';
import 'package:omni_bridge/features/settings/domain/usecases/get_app_settings_usecase.dart';
import 'package:omni_bridge/features/settings/domain/usecases/get_google_credentials_usecase.dart';
import 'package:omni_bridge/features/settings/domain/usecases/sync_settings_usecase.dart';
import 'package:omni_bridge/features/settings/domain/usecases/get_system_config_usecase.dart';
import 'package:omni_bridge/features/settings/domain/usecases/log_event_usecase.dart';
import 'package:omni_bridge/features/settings/domain/entities/system_config.dart';
import 'package:omni_bridge/features/auth/domain/usecases/logout_usecase.dart';
import 'package:omni_bridge/features/subscription/data/datasources/subscription_remote_datasource.dart';
import 'package:omni_bridge/features/usage/domain/entities/quota_status.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:omni_bridge/features/settings/domain/entities/app_settings.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter_test/flutter_test.dart';

class MockStartTranslationUseCase extends Mock implements StartTranslationUseCase {}
class MockStopTranslationUseCase extends Mock implements StopTranslationUseCase {}
class MockUpdateVolumeUseCase extends Mock implements UpdateVolumeUseCase {}
class MockGetModelStatusUseCase extends Mock implements GetModelStatusUseCase {}
class MockObserveCaptionsUseCase extends Mock implements ObserveCaptionsUseCase {}
class MockObserveQuotaStatusUseCase extends Mock implements ObserveQuotaStatusUseCase {}
class MockGetInitialQuotaStatusUseCase extends Mock implements GetInitialQuotaStatusUseCase {}
class MockGetDefaultTierUseCase extends Mock implements GetDefaultTierUseCase {}
class MockUpdateTranslationSettingsUseCase extends Mock implements UpdateTranslationSettingsUseCase {}
class MockCheckServerHealthUseCase extends Mock implements CheckServerHealthUseCase {}
class MockGetCurrentUserUseCase extends Mock implements GetCurrentUserUseCase {}
class MockObserveAuthChangesUseCase extends Mock implements ObserveAuthChangesUseCase {}
class MockGetAppSettingsUseCase extends Mock implements GetAppSettingsUseCase {}
class MockGetGoogleCredentialsUseCase extends Mock implements GetGoogleCredentialsUseCase {}
class MockSyncSettingsUseCase extends Mock implements SyncSettingsUseCase {}
class MockLogEventUseCase extends Mock implements LogEventUseCase {}
class MockLogoutUseCase extends Mock implements LogoutUseCase {}
class MockGetSystemConfigUseCase extends Mock implements GetSystemConfigUseCase {}
class MockSubscriptionRemoteDataSource extends Mock implements SubscriptionRemoteDataSource {}
class MockTranslationRestDatasource extends Mock implements TranslationRestDatasource {}
class MockLiveDeviceUpdateUseCase extends Mock implements LiveDeviceUpdateUseCase {}
class MockLiveMicToggleUseCase extends Mock implements LiveMicToggleUseCase {}

void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(QuotaStatus(
      tier: 'free',
      dailyTokensUsed: 0,
      weeklyTokensUsed: 0,
      monthlyTokensUsed: 0,
      lifetimeTokensUsed: 0,
      dailyLimit: 0,
      dailyResetAt: DateTime.now(),
    ));
  });

  late MockStartTranslationUseCase mockStartTranslationUseCase;
  late MockStopTranslationUseCase mockStopTranslationUseCase;
  late MockUpdateVolumeUseCase mockUpdateVolumeUseCase;
  late MockGetModelStatusUseCase mockGetModelStatusUseCase;
  late MockObserveCaptionsUseCase mockObserveCaptionsUseCase;
  late MockObserveQuotaStatusUseCase mockObserveQuotaStatusUseCase;
  late MockGetInitialQuotaStatusUseCase mockGetInitialQuotaStatusUseCase;
  late MockGetDefaultTierUseCase mockGetDefaultTierUseCase;
  late MockUpdateTranslationSettingsUseCase mockUpdateTranslationSettingsUseCase;
  late MockCheckServerHealthUseCase mockCheckServerHealthUseCase;
  late MockGetCurrentUserUseCase mockGetCurrentUserUseCase;
  late MockObserveAuthChangesUseCase mockObserveAuthChangesUseCase;
  late MockGetAppSettingsUseCase mockGetAppSettingsUseCase;
  late MockGetGoogleCredentialsUseCase mockGetGoogleCredentialsUseCase;
  late MockSyncSettingsUseCase mockSyncSettingsUseCase;
  late MockLogEventUseCase mockLogEventUseCase;
  late MockLogoutUseCase mockLogoutUseCase;
  late MockGetSystemConfigUseCase mockGetSystemConfigUseCase;
  late MockSubscriptionRemoteDataSource mockSubscriptionDataSource;
  late MockTranslationRestDatasource mockTranslationRestDatasource;
  late MockLiveDeviceUpdateUseCase mockLiveDeviceUpdateUseCase;
  late MockLiveMicToggleUseCase mockLiveMicToggleUseCase;

  setUp(() {
    mockStartTranslationUseCase = MockStartTranslationUseCase();
    mockStopTranslationUseCase = MockStopTranslationUseCase();
    mockUpdateVolumeUseCase = MockUpdateVolumeUseCase();
    mockGetModelStatusUseCase = MockGetModelStatusUseCase();
    mockObserveCaptionsUseCase = MockObserveCaptionsUseCase();
    mockObserveQuotaStatusUseCase = MockObserveQuotaStatusUseCase();
    mockGetInitialQuotaStatusUseCase = MockGetInitialQuotaStatusUseCase();
    mockGetDefaultTierUseCase = MockGetDefaultTierUseCase();
    mockUpdateTranslationSettingsUseCase = MockUpdateTranslationSettingsUseCase();
    mockCheckServerHealthUseCase = MockCheckServerHealthUseCase();
    mockGetCurrentUserUseCase = MockGetCurrentUserUseCase();
    mockObserveAuthChangesUseCase = MockObserveAuthChangesUseCase();
    mockGetAppSettingsUseCase = MockGetAppSettingsUseCase();
    mockGetGoogleCredentialsUseCase = MockGetGoogleCredentialsUseCase();
    mockSyncSettingsUseCase = MockSyncSettingsUseCase();
    mockLogEventUseCase = MockLogEventUseCase();
    mockLogoutUseCase = MockLogoutUseCase();
    mockGetSystemConfigUseCase = MockGetSystemConfigUseCase();
    mockSubscriptionDataSource = MockSubscriptionRemoteDataSource();
    mockTranslationRestDatasource = MockTranslationRestDatasource();
    mockLiveDeviceUpdateUseCase = MockLiveDeviceUpdateUseCase();
    mockLiveMicToggleUseCase = MockLiveMicToggleUseCase();

    // Default stubs
    when(() => mockGetInitialQuotaStatusUseCase.call()).thenReturn(null);
    when(() => mockGetDefaultTierUseCase.call()).thenReturn('free');
    when(() => mockObserveQuotaStatusUseCase.call()).thenAnswer((_) => Stream.empty());
    when(() => mockObserveCaptionsUseCase.call()).thenAnswer((_) => Stream.empty());
    when(() => mockGetCurrentUserUseCase.call()).thenReturn(ValueNotifier<auth.User?>(null));
    when(() => mockGetModelStatusUseCase.call()).thenAnswer((_) async => []);
    when(() => mockGetAppSettingsUseCase.call()).thenAnswer((_) async => const Right(null));
    when(() => mockGetGoogleCredentialsUseCase.call()).thenAnswer((_) async => const Right(''));
    when(() => mockObserveAuthChangesUseCase.call()).thenAnswer((_) => Stream.empty());
    when(() => mockTranslationRestDatasource.unloadModel()).thenAnswer((_) async => true);
    when(() => mockCheckServerHealthUseCase.call()).thenAnswer((_) async => true);
    when(() => mockGetSystemConfigUseCase.call()).thenAnswer((_) async => Right(SystemConfig.initial()));
  });

  TranslationBloc createBloc() {
    return TranslationBloc(
      startTranslationUseCase: mockStartTranslationUseCase,
      stopTranslationUseCase: mockStopTranslationUseCase,
      updateVolumeUseCase: mockUpdateVolumeUseCase,
      getModelStatusUseCase: mockGetModelStatusUseCase,
      observeCaptionsUseCase: mockObserveCaptionsUseCase,
      observeQuotaStatusUseCase: mockObserveQuotaStatusUseCase,
      getInitialQuotaStatusUseCase: mockGetInitialQuotaStatusUseCase,
      getDefaultTierUseCase: mockGetDefaultTierUseCase,
      updateTranslationSettingsUseCase: mockUpdateTranslationSettingsUseCase,
      checkServerHealthUseCase: mockCheckServerHealthUseCase,
      getCurrentUserUseCase: mockGetCurrentUserUseCase,
      observeAuthChangesUseCase: mockObserveAuthChangesUseCase,
      getAppSettingsUseCase: mockGetAppSettingsUseCase,
      getGoogleCredentialsUseCase: mockGetGoogleCredentialsUseCase,
      syncSettingsUseCase: mockSyncSettingsUseCase,
      logEventUseCase: mockLogEventUseCase,
      logoutUseCase: mockLogoutUseCase,
      getSystemConfigUseCase: mockGetSystemConfigUseCase,
      subscriptionDataSource: mockSubscriptionDataSource,
      translationRestDatasource: mockTranslationRestDatasource,
      liveDeviceUpdateUseCase: mockLiveDeviceUpdateUseCase,
      liveMicToggleUseCase: mockLiveMicToggleUseCase,
    );
  }

  group('Initialization', () {
    blocTest<TranslationBloc, TranslationState>(
      'emits initial states during construction',
      build: () {
        when(() => mockSubscriptionDataSource.allowedTranslationModels(any()))
            .thenReturn(['google', 'mymemory']);
        when(() => mockSubscriptionDataSource.allowedTranscriptionModels(any()))
            .thenReturn(['online']);
        return createBloc();
      },
      expect: () => [
        isA<TranslationState>().having((s) => s.isSettingsLoading, 'isSettingsLoading', true),
        isA<TranslationState>(), // UpdateQuotaEvent
        isA<TranslationState>().having((s) => s.isSettingsLoading, 'isSettingsLoading', false),
      ],
    );
  });

  group('ToggleRunningEvent', () {
    blocTest<TranslationBloc, TranslationState>(
      'starts translation when toggled from stopped state',
      build: () {
        when(() => mockSubscriptionDataSource.allowedTranslationModels(any()))
            .thenReturn(['google', 'mymemory']);
        when(() => mockSubscriptionDataSource.allowedTranscriptionModels(any()))
            .thenReturn(['online']);
        when(() => mockStartTranslationUseCase.call(
              sourceLang: any(named: 'sourceLang'),
              targetLang: any(named: 'targetLang'),
              useMic: any(named: 'useMic'),
              inputDeviceIndex: any(named: 'inputDeviceIndex'),
              outputDeviceIndex: any(named: 'outputDeviceIndex'),
              translationModel: any(named: 'translationModel'),
              nvidiaNimKey: any(named: 'nvidiaNimKey'),
              googleCredentials: any(named: 'googleCredentials'),
              transcriptionModel: any(named: 'transcriptionModel'),
            )).thenReturn(null);

        return createBloc();
      },
      act: (bloc) => bloc.add(ToggleRunningEvent()),
      skip: 3,
      expect: () => [
        isA<TranslationState>().having((s) => s.isRunning, 'isRunning', true),
      ],
    );

    blocTest<TranslationBloc, TranslationState>(
      'stops translation when toggled from running state',
      build: () {
        when(() => mockSubscriptionDataSource.allowedTranslationModels(any()))
            .thenReturn(['google', 'mymemory']);
        when(() => mockSubscriptionDataSource.allowedTranscriptionModels(any()))
            .thenReturn(['online']);
        when(() => mockStopTranslationUseCase.call()).thenAnswer((_) async {});
        when(() => mockStartTranslationUseCase.call(
              sourceLang: any(named: 'sourceLang'),
              targetLang: any(named: 'targetLang'),
              useMic: any(named: 'useMic'),
              inputDeviceIndex: any(named: 'inputDeviceIndex'),
              outputDeviceIndex: any(named: 'outputDeviceIndex'),
              translationModel: any(named: 'translationModel'),
              nvidiaNimKey: any(named: 'nvidiaNimKey'),
              googleCredentials: any(named: 'googleCredentials'),
              transcriptionModel: any(named: 'transcriptionModel'),
            )).thenReturn(null);

        return createBloc();
      },
      act: (bloc) async {
        bloc.add(ToggleRunningEvent());
        await Future.delayed(Duration.zero);
        bloc.add(ToggleRunningEvent());
      },
      skip: 4,
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
        verifyNever(() => mockStartTranslationUseCase.call(
              sourceLang: any(named: 'sourceLang'),
              targetLang: any(named: 'targetLang'),
              useMic: any(named: 'useMic'),
              inputDeviceIndex: any(named: 'inputDeviceIndex'),
              outputDeviceIndex: any(named: 'outputDeviceIndex'),
              translationModel: any(named: 'translationModel'),
              nvidiaNimKey: any(named: 'nvidiaNimKey'),
              googleCredentials: any(named: 'googleCredentials'),
              transcriptionModel: any(named: 'transcriptionModel'),
            ));
      },
    );
  });

  group('UpdateServerConnectionEvent', () {
    blocTest<TranslationBloc, TranslationState>(
      'updates isServerConnected when UpdateServerConnectionEvent is added',
      build: () => createBloc(),
      act: (bloc) => bloc.add(const UpdateServerConnectionEvent(isConnected: false)),
      skip: 3, // Skip init events
      expect: () => [
        isA<TranslationState>().having((s) => s.isServerConnected, 'isServerConnected', false),
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
        when(() => mockGetInitialQuotaStatusUseCase.call()).thenReturn(proStatus);
        when(() => mockSubscriptionDataSource.allowedTranslationModels('free'))
            .thenReturn(['google']);
        when(() => mockSubscriptionDataSource.allowedTranscriptionModels('free'))
            .thenReturn(['online']);
        when(() => mockTranslationRestDatasource.unloadModel()).thenAnswer((_) async => true);
        when(() => mockStopTranslationUseCase.call()).thenAnswer((_) async {});
        when(() => mockUpdateTranslationSettingsUseCase.call(
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
            )).thenReturn(null);
        
        // Return llama/whisper first, then defaults on subsequent calls
        var callCount = 0;
        when(() => mockGetAppSettingsUseCase.call()).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) {
            return Right(AppSettings.initial().copyWith(
              translationModel: 'llama',
              transcriptionModel: 'whisper',
            ));
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
      skip: 4, 
      expect: () => [
        // 1. Quota update only (tier changed to free)
        isA<TranslationState>()
            .having((s) => s.quotaStatus?.tier, 'new tier', 'free')
            .having((s) => s.activeTranslationModel, 'still llama', 'llama'),
        // 2. Internal reset (isRunning: false, models: google/online)
        isA<TranslationState>()
            .having((s) => s.isRunning, 'isRunning', false)
            .having((s) => s.activeTranslationModel, 'activeTranslationModel', 'google')
            .having((s) => s.activeTranscriptionModel, 'activeTranscriptionModel', 'online'),
        // 3. LoadSettingsEvent start
        isA<TranslationState>().having((s) => s.isSettingsLoading, 'isSettingsLoading', true),
        // 4. LoadSettingsEvent finish (should remain google/online if we mock it right)
        isA<TranslationState>().having((s) => s.isSettingsLoading, 'isSettingsLoading', false),
        // 5. ApplySettingsEvent (triggered by LoadSettingsEvent) start
        isA<TranslationState>().having((s) => s.isSettingsSaving, 'isSettingsSaving', true),
        // 6. ApplySettingsEvent finish
        isA<TranslationState>().having((s) => s.isSettingsSaving, 'isSettingsSaving', false),
      ],
      verify: (_) {
        verify(() => mockStopTranslationUseCase.call()).called(2);
        verify(() => mockTranslationRestDatasource.unloadModel()).called(1);
        verify(() => mockUpdateTranslationSettingsUseCase.call(
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
        )).called(2);
      },
    );
  });
}
