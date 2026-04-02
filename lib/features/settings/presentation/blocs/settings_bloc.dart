import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omni_bridge/features/settings/domain/usecases/get_app_settings_usecase.dart';
import 'package:omni_bridge/features/settings/domain/usecases/update_app_settings_usecase.dart';
import 'package:omni_bridge/features/settings/domain/usecases/get_google_credentials_usecase.dart';
import 'package:omni_bridge/features/settings/domain/usecases/live_device_update_usecase.dart';
import 'package:omni_bridge/features/settings/domain/usecases/live_mic_toggle_usecase.dart';
import 'package:omni_bridge/features/settings/domain/usecases/load_devices_usecase.dart';
import 'package:omni_bridge/features/settings/domain/usecases/log_event_usecase.dart';
import 'package:omni_bridge/features/settings/domain/usecases/update_volume_usecase.dart';
import 'package:omni_bridge/features/settings/domain/entities/app_settings.dart';
import 'package:omni_bridge/core/constants/model_language_support.dart';
import 'package:omni_bridge/features/subscription/domain/usecases/get_subscription_status.dart';
import 'package:omni_bridge/features/subscription/data/datasources/subscription_remote_datasource.dart';
import 'package:omni_bridge/features/usage/domain/entities/quota_status.dart';
import 'settings_event.dart';
import 'settings_state.dart';
import 'dart:async';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final GetAppSettingsUseCase getAppSettingsUseCase;
  final UpdateAppSettingsUseCase updateAppSettingsUseCase;
  final GetGoogleCredentialsUseCase getGoogleCredentialsUseCase;
  final LoadDevicesUseCase loadDevicesUseCase;
  final LogEventUseCase logEventUseCase;
  final GetSubscriptionStatus getSubscriptionStatus;
  final UpdateVolumeUseCase updateVolumeUseCase;
  final LiveDeviceUpdateUseCase liveDeviceUpdateUseCase;
  final LiveMicToggleUseCase liveMicToggleUseCase;
  StreamSubscription<QuotaStatus>? _subscriptionStatusSubscription;

  SettingsBloc({
    required this.getAppSettingsUseCase,
    required this.updateAppSettingsUseCase,
    required this.getGoogleCredentialsUseCase,
    required this.loadDevicesUseCase,
    required this.logEventUseCase,
    required this.getSubscriptionStatus,
    required this.updateVolumeUseCase,
    required this.liveDeviceUpdateUseCase,
    required this.liveMicToggleUseCase,
  }) : super(SettingsState.initial()) {
    on<UpdateTempSettingEvent>(_onUpdateTempSetting);
    on<LoadDevicesEvent>(_onLoadDevices);
    on<ResetIODefaultsEvent>(_onResetIODefaults);
    on<SaveSettingsEvent>(_onSaveSettings);
    on<SubscriptionStatusChangedEvent>(_onSubscriptionStatusChanged);
    on<InitializeSettingsEvent>(_onInitializeSettings);
    on<SettingsTabIndexChanged>(_onSettingsTabIndexChanged);
    on<LiveVolumeUpdateEvent>(_onLiveVolumeUpdate);
    on<LiveDeviceUpdateEvent>(_onLiveDeviceUpdate);
    on<LiveMicToggleEvent>(_onLiveMicToggle);

    _subscriptionStatusSubscription = getSubscriptionStatus().listen((status) {
      add(SubscriptionStatusChangedEvent(status));
    });
  }

  Future<void> _onInitializeSettings(
    InitializeSettingsEvent event,
    Emitter<SettingsState> emit,
  ) async {
    if (state.isInitialized) return;

    AppSettings settings = AppSettings.initial();
    final result = await getAppSettingsUseCase();
    result.fold(
      (failure) {},
      (loaded) { if (loaded != null) settings = loaded; },
    );

    final error = translationCompatibilityError(
      settings.translationModel,
      settings.sourceLang,
      settings.targetLang,
    );
    emit(
      state.copyWith(
        settings: settings,
        translationCompatibilityError: error,
        clearCompatibilityError: error == null,
        activeTabIndex: event.initialTabIndex,
        modelStatuses: event.modelStatuses,
        isInitialized: true,
      ),
    );
    add(LoadDevicesEvent());
  }

  void _onSettingsTabIndexChanged(
    SettingsTabIndexChanged event,
    Emitter<SettingsState> emit,
  ) {
    emit(state.copyWith(activeTabIndex: event.index));
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
        inputDevices: result.inputDevices,
        outputDevices: result.outputDevices,
        defaultInputDeviceName: result.defaultInputName,
        defaultOutputDeviceName: result.defaultOutputName,
        devicesLoading: false,
      ),
    );
  }

  Future<void> _onSaveSettings(
    SaveSettingsEvent event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(isSaving: true));
    final result = await updateAppSettingsUseCase(state.settings.toJson());
    result.fold(
      (failure) => logEventUseCase(
        'settings_save_failed',
        parameters: {'error': failure.message},
      ),
      (_) {},
    );
    emit(state.copyWith(isSaving: false));
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

  void _onLiveVolumeUpdate(
    LiveVolumeUpdateEvent event,
    Emitter<SettingsState> emit,
  ) {
    updateVolumeUseCase(
      desktopVolume: event.desktopVolume,
      micVolume: event.micVolume,
    );
  }

  void _onLiveDeviceUpdate(
    LiveDeviceUpdateEvent event,
    Emitter<SettingsState> emit,
  ) {
    liveDeviceUpdateUseCase(
      inputDeviceIndex: event.inputDeviceIndex,
      outputDeviceIndex: event.outputDeviceIndex,
    );
  }

  void _onLiveMicToggle(
    LiveMicToggleEvent event,
    Emitter<SettingsState> emit,
  ) {
    liveMicToggleUseCase(event.useMic);
  }

  @override
  Future<void> close() {
    _subscriptionStatusSubscription?.cancel();
    return super.close();
  }
}
