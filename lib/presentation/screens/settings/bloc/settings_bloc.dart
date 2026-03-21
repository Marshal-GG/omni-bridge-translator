import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omni_bridge/domain/repositories/settings_repository.dart';
import 'package:omni_bridge/features/translation/domain/repositories/i_translation_repository.dart';
import 'package:omni_bridge/core/constants/model_language_support.dart';
import 'package:omni_bridge/presentation/screens/settings/bloc/settings_event.dart';
import 'package:omni_bridge/presentation/screens/settings/bloc/settings_state.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final ISettingsRepository settingsRepo;
  final ITranslationRepository translationRepo;

  SettingsBloc({
    required this.settingsRepo,
    required this.translationRepo,
  }) : super(SettingsState.initial()) {
    on<UpdateTempSettingEvent>(_onUpdateTempSetting);
    on<SyncTempSettingsEvent>(_onSyncTempSettings);
    on<LoadDevicesEvent>(_onLoadDevices);
    on<UpdateAudioLevelsEvent>(_onUpdateAudioLevels);
    on<ResetIODefaultsEvent>(_onResetIODefaults);
    on<SaveSettingsEvent>(_onSaveSettings);

    translationRepo.onAudioLevel = (inputLevel, outputLevel) {
      if (!isClosed) {
        add(UpdateAudioLevelsEvent(inputLevel, outputLevel));
      }
    };
  }


  void _onSyncTempSettings(
    SyncTempSettingsEvent event,
    Emitter<SettingsState> emit,
  ) {
    final newSettings = state.settings.copyWith(
      targetLang: event.targetLang,
      sourceLang: event.sourceLang,
      useMic: event.useMic,
      fontSize: event.fontSize,
      isBold: event.isBold,
      opacity: event.opacity,
      translationModel: event.translationModel,
      apiKey: event.apiKey,
      transcriptionModel: event.transcriptionModel,
      inputDeviceIndex: event.inputDeviceIndex,
      outputDeviceIndex: event.outputDeviceIndex,
      desktopVolume: event.desktopVolume,
      micVolume: event.micVolume,
    );
    final error = translationCompatibilityError(
      newSettings.translationModel,
      newSettings.sourceLang,
      newSettings.targetLang,
    );
    emit(state.copyWith(
      settings: newSettings,
      translationCompatibilityError: error,
      clearCompatibilityError: error == null,
    ));
  }

  void _onUpdateTempSetting(
    UpdateTempSettingEvent event,
    Emitter<SettingsState> emit,
  ) {
    final newSettings = state.settings.copyWith(
      targetLang: event.targetLang,
      sourceLang: event.sourceLang,
      useMic: event.useMic,
      fontSize: event.fontSize,
      isBold: event.isBold,
      opacity: event.opacity,
      translationModel: event.translationModel,
      apiKey: event.apiKey,
      transcriptionModel: event.transcriptionModel,
      clearInputDevice: event.clearInputDevice,
      inputDeviceIndex: event.inputDeviceIndex,
      clearOutputDevice: event.clearOutputDevice,
      outputDeviceIndex: event.outputDeviceIndex,
      desktopVolume: event.desktopVolume,
      micVolume: event.micVolume,
    );
    final error = translationCompatibilityError(
      newSettings.translationModel,
      newSettings.sourceLang,
      newSettings.targetLang,
    );
    emit(state.copyWith(
      settings: newSettings,
      translationCompatibilityError: error,
      clearCompatibilityError: error == null,
    ));
  }

  Future<void> _onLoadDevices(
    LoadDevicesEvent event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(devicesLoading: true));
    final result = await translationRepo.loadDevices();

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
        settings: state.settings.copyWith(
          useMic: false, // Default is mic off
          micVolume: 1.0,
          desktopVolume: 1.0,
          clearInputDevice: true,
          clearOutputDevice: true,
        ),
      ),
    );
  }
}
