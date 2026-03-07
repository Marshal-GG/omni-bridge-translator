import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/services/asr_ws_client.dart';
import 'settings_event.dart';
import 'settings_state.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final AsrWebSocketClient asrClient;

  SettingsBloc({required this.asrClient}) : super(SettingsState.initial()) {
    on<UpdateTempSettingEvent>(_onUpdateTempSetting);
    on<SyncTempSettingsEvent>(_onSyncTempSettings);
    on<LoadDevicesEvent>(_onLoadDevices);
    on<UpdateAudioLevelsEvent>(_onUpdateAudioLevels);
    on<ResetIODefaultsEvent>(_onResetIODefaults);
    on<SaveSettingsEvent>(_onSaveSettings);

    asrClient.onAudioLevel = (inputLevel, outputLevel) {
      if (!isClosed) {
        add(UpdateAudioLevelsEvent(inputLevel, outputLevel));
      }
    };
  }

  void _onSyncTempSettings(
    SyncTempSettingsEvent event,
    Emitter<SettingsState> emit,
  ) {
    emit(
      state.copyWith(
        tempTargetLang: event.targetLang,
        tempSourceLang: event.sourceLang,
        tempUseMic: event.useMic,
        tempFontSize: event.fontSize,
        tempIsBold: event.isBold,
        tempOpacity: event.opacity,
        tempTranslationModel: event.translationModel,
        tempApiKey: event.apiKey ?? state.tempApiKey,
        tempTranscriptionModel:
            event.transcriptionModel ?? state.tempTranscriptionModel,
        tempInputDeviceIndex: event.inputDeviceIndex,
        tempOutputDeviceIndex: event.outputDeviceIndex,
        tempDesktopVolume: event.desktopVolume,
        tempMicVolume: event.micVolume,
      ),
    );
  }

  void _onUpdateTempSetting(
    UpdateTempSettingEvent event,
    Emitter<SettingsState> emit,
  ) {
    emit(
      state.copyWith(
        tempTargetLang: event.targetLang,
        tempSourceLang: event.sourceLang,
        tempUseMic: event.useMic,
        tempFontSize: event.fontSize,
        tempIsBold: event.isBold,
        tempOpacity: event.opacity,
        tempTranslationModel: event.translationModel,
        tempApiKey: event.apiKey ?? state.tempApiKey,
        tempTranscriptionModel:
            event.transcriptionModel ?? state.tempTranscriptionModel,
        clearInputDevice: event.clearInputDevice,
        tempInputDeviceIndex: event.inputDeviceIndex,
        clearOutputDevice: event.clearOutputDevice,
        tempOutputDeviceIndex: event.outputDeviceIndex,
        tempDesktopVolume: event.desktopVolume,
        tempMicVolume: event.micVolume,
      ),
    );
  }

  Future<void> _onLoadDevices(
    LoadDevicesEvent event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(devicesLoading: true));
    final result = await asrClient.loadDevices();
    emit(
      state.copyWith(
        inputDevices:
            (result['input'] as List?)?.cast<Map<String, dynamic>>() ?? [],
        outputDevices:
            (result['output'] as List?)?.cast<Map<String, dynamic>>() ?? [],
        defaultInputDeviceName:
            result['default_input_name'] as String? ?? 'Default',
        defaultOutputDeviceName:
            result['default_output_name'] as String? ?? 'Default',
        devicesLoading: false,
      ),
    );
  }

  void _onUpdateAudioLevels(
    UpdateAudioLevelsEvent event,
    Emitter<SettingsState> emit,
  ) {
    emit(
      state.copyWith(
        currentInputVolume: event.inputVolume,
        currentOutputVolume: event.outputVolume,
      ),
    );
  }

  Future<void> _onSaveSettings(
    SaveSettingsEvent event,
    Emitter<SettingsState> emit,
  ) async {
    // handled elsewhere by syncing to TranslationBloc using BlocListener or by letting TranslationBloc handle save directly
  }

  void _onResetIODefaults(
    ResetIODefaultsEvent event,
    Emitter<SettingsState> emit,
  ) {
    emit(
      state.copyWith(
        tempUseMic: false, // Default is mic off
        tempMicVolume: 1.0,
        tempDesktopVolume: 1.0,
        clearInputDevice: true,
        clearOutputDevice: true,
      ),
    );
  }
}
