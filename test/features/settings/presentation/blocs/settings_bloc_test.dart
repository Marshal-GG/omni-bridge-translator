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
import 'package:omni_bridge/features/settings/domain/usecases/load_devices_usecase.dart';
import 'package:omni_bridge/features/settings/domain/usecases/observe_audio_levels_usecase.dart';
import 'package:omni_bridge/features/settings/domain/usecases/log_event_usecase.dart';

class MockGetAppSettingsUseCase extends Mock implements GetAppSettingsUseCase {}
class MockUpdateAppSettingsUseCase extends Mock implements UpdateAppSettingsUseCase {}
class MockGetGoogleCredentialsUseCase extends Mock implements GetGoogleCredentialsUseCase {}
class MockLoadDevicesUseCase extends Mock implements LoadDevicesUseCase {}
class MockObserveAudioLevelsUseCase extends Mock implements ObserveAudioLevelsUseCase {}
class MockLogEventUseCase extends Mock implements LogEventUseCase {}

void main() {
  late SettingsBloc settingsBloc;
  late MockGetAppSettingsUseCase mockGetAppSettingsUseCase;
  late MockUpdateAppSettingsUseCase mockUpdateAppSettingsUseCase;
  late MockGetGoogleCredentialsUseCase mockGetGoogleCredentialsUseCase;
  late MockLoadDevicesUseCase mockLoadDevicesUseCase;
  late MockObserveAudioLevelsUseCase mockObserveAudioLevelsUseCase;
  late MockLogEventUseCase mockLogEventUseCase;

  setUp(() {
    mockGetAppSettingsUseCase = MockGetAppSettingsUseCase();
    mockUpdateAppSettingsUseCase = MockUpdateAppSettingsUseCase();
    mockGetGoogleCredentialsUseCase = MockGetGoogleCredentialsUseCase();
    mockLoadDevicesUseCase = MockLoadDevicesUseCase();
    mockObserveAudioLevelsUseCase = MockObserveAudioLevelsUseCase();
    mockLogEventUseCase = MockLogEventUseCase();

    settingsBloc = SettingsBloc(
      getAppSettingsUseCase: mockGetAppSettingsUseCase,
      updateAppSettingsUseCase: mockUpdateAppSettingsUseCase,
      getGoogleCredentialsUseCase: mockGetGoogleCredentialsUseCase,
      loadDevicesUseCase: mockLoadDevicesUseCase,
      observeAudioLevelsUseCase: mockObserveAudioLevelsUseCase,
      logEventUseCase: mockLogEventUseCase,
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
        when(() => mockLoadDevicesUseCase()).thenAnswer((_) async => {
          'input': [{'name': 'Mic1', 'index': 1}],
          'output': [{'name': 'Speaker1', 'index': 2}],
          'default_input_name': 'Mic1',
          'default_output_name': 'Speaker1',
        });
        return settingsBloc;
      },
      act: (bloc) => bloc.add(LoadDevicesEvent()),
      expect: () => [
        SettingsState.initial().copyWith(devicesLoading: true),
        SettingsState.initial().copyWith(
          devicesLoading: false,
          inputDevices: [{'name': 'Mic1', 'index': 1}],
          outputDevices: [{'name': 'Speaker1', 'index': 2}],
          defaultInputDeviceName: 'Mic1',
          defaultOutputDeviceName: 'Speaker1',
        ),
      ],
    );

    blocTest<SettingsBloc, SettingsState>(
      'UpdateAudioLevelsEvent updates current volumes',
      build: () => settingsBloc,
      act: (bloc) => bloc.add(UpdateAudioLevelsEvent(0.5, 0.8)),
      expect: () => [
        SettingsState.initial().copyWith(
          currentInputVolume: 0.5,
          currentOutputVolume: 0.8,
        ),
      ],
    );

    blocTest<SettingsBloc, SettingsState>(
      'UpdateTempSettingEvent emits new settings',
      build: () => settingsBloc,
      act: (bloc) => bloc.add(UpdateTempSettingEvent(fontSize: 24.0, useMic: true)),
      expect: () => [
        SettingsState.initial().copyWith(
          settings: AppSettings.initial().copyWith(fontSize: 24.0, useMic: true),
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
  });
}
