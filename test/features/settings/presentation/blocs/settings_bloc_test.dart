import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:omni_bridge/features/settings/presentation/blocs/settings_bloc.dart';
import 'package:omni_bridge/features/settings/presentation/blocs/settings_event.dart';
import 'package:omni_bridge/features/settings/presentation/blocs/settings_state.dart';
import 'package:omni_bridge/features/settings/domain/entities/app_settings.dart';
import 'package:omni_bridge/features/settings/domain/usecases/get_app_settings_usecase.dart';
import 'package:omni_bridge/features/settings/domain/usecases/update_app_settings_usecase.dart';
import 'package:omni_bridge/features/settings/domain/usecases/get_google_credentials_usecase.dart';
import 'package:omni_bridge/features/settings/domain/usecases/live_device_update_usecase.dart';
import 'package:omni_bridge/features/settings/domain/usecases/live_mic_toggle_usecase.dart';
import 'package:omni_bridge/features/settings/domain/entities/audio_device.dart';
import 'package:omni_bridge/features/settings/domain/usecases/load_devices_usecase.dart';
import 'package:omni_bridge/features/settings/domain/usecases/log_event_usecase.dart';
import 'package:omni_bridge/features/settings/domain/usecases/update_volume_usecase.dart';
import 'package:omni_bridge/features/subscription/domain/usecases/get_subscription_status.dart';
import 'package:omni_bridge/features/usage/domain/entities/quota_status.dart';

class MockGetAppSettingsUseCase extends Mock implements GetAppSettingsUseCase {}

class MockUpdateAppSettingsUseCase extends Mock
    implements UpdateAppSettingsUseCase {}

class MockGetGoogleCredentialsUseCase extends Mock
    implements GetGoogleCredentialsUseCase {}

class MockLoadDevicesUseCase extends Mock implements LoadDevicesUseCase {}

class MockLogEventUseCase extends Mock implements LogEventUseCase {}

class MockGetSubscriptionStatus extends Mock implements GetSubscriptionStatus {}

class MockUpdateVolumeUseCase extends Mock implements UpdateVolumeUseCase {}

class MockLiveDeviceUpdateUseCase extends Mock
    implements LiveDeviceUpdateUseCase {}

class MockLiveMicToggleUseCase extends Mock implements LiveMicToggleUseCase {}

void main() {
  late SettingsBloc settingsBloc;
  late MockGetAppSettingsUseCase mockGetAppSettingsUseCase;
  late MockUpdateAppSettingsUseCase mockUpdateAppSettingsUseCase;
  late MockGetGoogleCredentialsUseCase mockGetGoogleCredentialsUseCase;
  late MockLoadDevicesUseCase mockLoadDevicesUseCase;
  late MockLogEventUseCase mockLogEventUseCase;
  late MockGetSubscriptionStatus mockGetSubscriptionStatus;
  late MockUpdateVolumeUseCase mockUpdateVolumeUseCase;
  late MockLiveDeviceUpdateUseCase mockLiveDeviceUpdateUseCase;
  late MockLiveMicToggleUseCase mockLiveMicToggleUseCase;

  setUp(() {
    mockGetAppSettingsUseCase = MockGetAppSettingsUseCase();
    mockUpdateAppSettingsUseCase = MockUpdateAppSettingsUseCase();
    mockGetGoogleCredentialsUseCase = MockGetGoogleCredentialsUseCase();
    mockLoadDevicesUseCase = MockLoadDevicesUseCase();
    mockLogEventUseCase = MockLogEventUseCase();
    mockGetSubscriptionStatus = MockGetSubscriptionStatus();
    mockUpdateVolumeUseCase = MockUpdateVolumeUseCase();
    mockLiveDeviceUpdateUseCase = MockLiveDeviceUpdateUseCase();
    mockLiveMicToggleUseCase = MockLiveMicToggleUseCase();

    when(() => mockGetSubscriptionStatus()).thenAnswer((_) => Stream.empty());

    settingsBloc = SettingsBloc(
      getAppSettingsUseCase: mockGetAppSettingsUseCase,
      updateAppSettingsUseCase: mockUpdateAppSettingsUseCase,
      getGoogleCredentialsUseCase: mockGetGoogleCredentialsUseCase,
      loadDevicesUseCase: mockLoadDevicesUseCase,
      logEventUseCase: mockLogEventUseCase,
      getSubscriptionStatus: mockGetSubscriptionStatus,
      updateVolumeUseCase: mockUpdateVolumeUseCase,
      liveDeviceUpdateUseCase: mockLiveDeviceUpdateUseCase,
      liveMicToggleUseCase: mockLiveMicToggleUseCase,
    );
  });

  tearDown(() {
    settingsBloc.close();
  });

  group('SettingsBloc', () {
    test('initial state has default AppSettings', () {
      expect(settingsBloc.state, SettingsState.initial());
    });

    blocTest<SettingsBloc, SettingsState>(
      'LoadDevicesEvent emits correct devices',
      build: () {
        when(() => mockLoadDevicesUseCase()).thenAnswer(
          (_) async => DeviceListResult(
            inputDevices: [const AudioDevice(name: 'Mic1', index: 1)],
            outputDevices: [const AudioDevice(name: 'Speaker1', index: 2)],
            defaultInputName: 'Mic1',
            defaultOutputName: 'Speaker1',
          ),
        );
        return settingsBloc;
      },
      act: (bloc) => bloc.add(LoadDevicesEvent()),
      expect: () => [
        SettingsState.initial().copyWith(devicesLoading: true),
        SettingsState.initial().copyWith(
          devicesLoading: false,
          inputDevices: [const AudioDevice(name: 'Mic1', index: 1)],
          outputDevices: [const AudioDevice(name: 'Speaker1', index: 2)],
          defaultInputDeviceName: 'Mic1',
          defaultOutputDeviceName: 'Speaker1',
        ),
      ],
    );

    blocTest<SettingsBloc, SettingsState>(
      'UpdateTempSettingEvent emits new settings',
      build: () => settingsBloc,
      act: (bloc) =>
          bloc.add(UpdateTempSettingEvent(fontSize: 24.0, useMic: true)),
      expect: () => [
        SettingsState.initial().copyWith(
          settings: AppSettings.initial().copyWith(
            fontSize: 24.0,
            useMic: true,
          ),
          clearCompatibilityError: true,
        ),
      ],
    );

    blocTest<SettingsBloc, SettingsState>(
      'ResetIODefaultsEvent emits default IO settings',
      build: () => settingsBloc,
      act: (bloc) => bloc.add(ResetIODefaultsEvent()),
      expect: () => [
        SettingsState.initial().copyWith(
          settings: AppSettings.initial().copyWith(
            useMic: false,
            micVolume: 1.0,
            desktopVolume: 1.0,
            clearInputDevice: true,
            clearOutputDevice: true,
          ),
        ),
      ],
    );

    blocTest<SettingsBloc, SettingsState>(
      'SubscriptionStatusChangedEvent resets models and PERSISTS if not supported by new tier',
      build: () {
        when(
          () => mockUpdateAppSettingsUseCase(any()),
        ).thenAnswer((_) async => const Right(null));
        when(
          () =>
              mockLogEventUseCase(any(), parameters: any(named: 'parameters')),
        ).thenAnswer((_) async => const Right(null));
        return settingsBloc;
      },
      seed: () => SettingsState.initial().copyWith(
        settings: AppSettings.initial().copyWith(
          translationModel: 'nvidia-riva',
          transcriptionModel: 'riva',
        ),
      ),
      act: (bloc) => bloc.add(
        SubscriptionStatusChangedEvent(
          QuotaStatus(
            tier: 'free',
            dailyTokensUsed: 0,
            weeklyTokensUsed: 0,
            monthlyTokensUsed: 0,
            lifetimeTokensUsed: 0,
            dailyLimit: 1000,
            dailyResetAt: DateTime.now(),
          ),
        ),
      ),
      expect: () => [
        SettingsState.initial().copyWith(
          settings: AppSettings.initial().copyWith(
            translationModel: 'google',
            transcriptionModel: 'online',
          ),
        ),
      ],
      verify: (_) {
        verify(() => mockUpdateAppSettingsUseCase(any())).called(1);
        verify(
          () => mockLogEventUseCase(
            'subscription_downgrade_model_reset',
            parameters: any(named: 'parameters'),
          ),
        ).called(1);
      },
    );
  });
}
