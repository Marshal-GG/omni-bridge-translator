import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omni_bridge/features/settings/domain/usecases/get_app_settings_usecase.dart';
import 'package:omni_bridge/features/settings/domain/usecases/update_app_settings_usecase.dart';
import 'package:omni_bridge/features/settings/domain/usecases/get_google_credentials_usecase.dart';
import 'package:omni_bridge/features/settings/domain/usecases/load_devices_usecase.dart';
import 'package:omni_bridge/features/settings/domain/usecases/observe_audio_levels_usecase.dart';
import 'package:omni_bridge/features/settings/domain/usecases/log_event_usecase.dart';
import 'package:omni_bridge/features/settings/domain/entities/app_settings.dart';
import 'package:omni_bridge/core/constants/model_language_support.dart';
import 'package:omni_bridge/features/subscription/domain/usecases/get_subscription_status.dart';
import 'package:omni_bridge/features/subscription/data/datasources/subscription_remote_datasource.dart';
import 'settings_event.dart';
import 'settings_state.dart';
import 'dart:async';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final GetAppSettingsUseCase getAppSettingsUseCase;
  final UpdateAppSettingsUseCase updateAppSettingsUseCase;
  final GetGoogleCredentialsUseCase getGoogleCredentialsUseCase;
  final LoadDevicesUseCase loadDevicesUseCase;
  final ObserveAudioLevelsUseCase observeAudioLevelsUseCase;
  final LogEventUseCase logEventUseCase;
  final GetSubscriptionStatus getSubscriptionStatus;
  StreamSubscription? _subscriptionStatusSubscription;

  SettingsBloc({
    required this.getAppSettingsUseCase,
    required this.updateAppSettingsUseCase,
    required this.getGoogleCredentialsUseCase,
    required this.loadDevicesUseCase,
    required this.observeAudioLevelsUseCase,
    required this.logEventUseCase,
    required this.getSubscriptionStatus,
  }) : super(SettingsState.initial()) {
    on<UpdateTempSettingEvent>(_onUpdateTempSetting);
    on<SyncTempSettingsEvent>(_onSyncTempSettings);
    on<LoadDevicesEvent>(_onLoadDevices);
    on<UpdateAudioLevelsEvent>(_onUpdateAudioLevels);
    on<ResetIODefaultsEvent>(_onResetIODefaults);
    on<SaveSettingsEvent>(_onSaveSettings);
    on<SubscriptionStatusChangedEvent>(_onSubscriptionStatusChanged);

    _subscriptionStatusSubscription = getSubscriptionStatus().listen((status) {
      add(SubscriptionStatusChangedEvent(status));
    });

    observeAudioLevelsUseCase((inputLevel, outputLevel) {
      if (!isClosed) {
        add(UpdateAudioLevelsEvent(inputLevel, outputLevel));
      }
    });
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
      nvidiaNimKey: event.nvidiaNimKey,
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
    emit(
      state.copyWith(
        settings: newSettings,
        translationCompatibilityError: error,
        clearCompatibilityError: error == null,
      ),
    );
  }

  void _onUpdateTempSetting(
    UpdateTempSettingEvent event,
    Emitter<SettingsState> emit,
  ) {
    String newSource = event.sourceLang ?? state.settings.sourceLang;
    String newTarget = event.targetLang ?? state.settings.targetLang;

    final newSettings = state.settings.copyWith(
      targetLang: newTarget,
      sourceLang: newSource,
      useMic: event.useMic,
      fontSize: event.fontSize,
      isBold: event.isBold,
      opacity: event.opacity,
      translationModel: event.translationModel,
      nvidiaNimKey: event.nvidiaNimKey,
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
    emit(
      state.copyWith(
        settings: newSettings,
        translationCompatibilityError: error,
        clearCompatibilityError: error == null,
      ),
    );
  }

  Future<void> _onLoadDevices(
    LoadDevicesEvent event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(devicesLoading: true));
    final result = await loadDevicesUseCase();

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

  Future<void> _onSubscriptionStatusChanged(
    SubscriptionStatusChangedEvent event,
    Emitter<SettingsState> emit,
  ) async {
    final status = event.status;
    final currentSettings = state.settings;

    bool needsTranslationReset = !SubscriptionRemoteDataSource.instance
        .allowedTranslationModels(status.tier)
        .contains(currentSettings.translationModel);

    bool needsTranscriptionReset = !SubscriptionRemoteDataSource.instance
        .allowedTranscriptionModels(status.tier)
        .contains(currentSettings.transcriptionModel);

    if (needsTranslationReset || needsTranscriptionReset) {
      final initialSettings = AppSettings.initial();
      final newSettings = currentSettings.copyWith(
        translationModel: needsTranslationReset
            ? initialSettings.translationModel
            : currentSettings.translationModel,
        transcriptionModel: needsTranscriptionReset
            ? initialSettings.transcriptionModel
            : currentSettings.transcriptionModel,
      );

      emit(state.copyWith(settings: newSettings));

      // Persist the changes so they stick after app restart
      await updateAppSettingsUseCase(newSettings.toJson());

      logEventUseCase(
        'subscription_downgrade_model_reset',
        parameters: {
          'tier': status.tier,
          'was_translation_reset': needsTranslationReset,
          'was_transcription_reset': needsTranscriptionReset,
        },
      );
    }
  }

  @override
  Future<void> close() {
    _subscriptionStatusSubscription?.cancel();
    return super.close();
  }
}
