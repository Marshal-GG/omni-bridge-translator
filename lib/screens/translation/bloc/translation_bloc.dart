import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:window_manager/window_manager.dart';
import 'translation_event.dart';
import 'translation_state.dart';
import '../../../core/services/asr_ws_client.dart';

class TranslationBloc extends Bloc<TranslationEvent, TranslationState> {
  final AsrWebSocketClient asrClient;
  StreamSubscription? _captionSub;

  TranslationBloc({required this.asrClient})
    : super(TranslationState.initial()) {
    on<ToggleSettingsEvent>(_onToggleSettings);
    on<ToggleShrinkEvent>(_onToggleShrink);
    on<UpdateTempSettingEvent>(_onUpdateTempSetting);
    on<SaveSettingsEvent>(_onSaveSettings);
    on<LoadDevicesEvent>(_onLoadDevices);
    on<SourceLangOverrideEvent>(_onSourceLangOverride);
    on<SyncTempSettingsEvent>(_onSyncTempSettings);

    _initAsr();
  }

  void _initAsr() {
    asrClient.start(
      sourceLang: state.activeSourceLang,
      targetLang: state.activeTargetLang,
      useMic: state.activeUseMic,
      inputDeviceIndex: state.activeInputDeviceIndex,
      outputDeviceIndex: state.activeOutputDeviceIndex,
    );

    _captionSub = asrClient.captions?.listen((msg) {
      if (msg.sourceLangOverride != null && !isClosed) {
        add(SourceLangOverrideEvent(msg.sourceLangOverride!));
      }
    });
  }

  void _onSourceLangOverride(
    SourceLangOverrideEvent event,
    Emitter<TranslationState> emit,
  ) {
    emit(state.copyWith(activeSourceLang: event.sourceLang));
  }

  void _onSyncTempSettings(
    SyncTempSettingsEvent event,
    Emitter<TranslationState> emit,
  ) {
    // When preparing to open the settings window, copy the "active" config into the "temp" config.
    emit(
      state.copyWith(
        tempTargetLang: state.activeTargetLang,
        tempSourceLang: state.activeSourceLang,
        tempUseMic: state.activeUseMic,
        tempFontSize: state.activeFontSize,
        tempIsBold: state.activeIsBold,
        tempOpacity: state.activeOpacity,
        tempInputDeviceIndex: state.activeInputDeviceIndex,
        tempOutputDeviceIndex: state.activeOutputDeviceIndex,
      ),
    );
  }

  Future<void> _onToggleSettings(
    ToggleSettingsEvent event,
    Emitter<TranslationState> emit,
  ) async {
    final bool willOpen = !state.isSettingsOpen;
    emit(state.copyWith(isSettingsOpen: willOpen));

    if (willOpen) {
      // Un-shrink if we are opening settings from a shrunk state
      if (state.isShrunk) {
        emit(state.copyWith(isShrunk: false));
      }

      // Keep temporary config strictly synced to active initially
      add(SyncTempSettingsEvent());
      add(LoadDevicesEvent()); // Fetch audio devices lazily

      appWindow.minSize = const Size(600, 300);
      await windowManager.setMinimumSize(const Size(600, 300));
      await windowManager.setSize(const Size(600, 700));
      appWindow.alignment = Alignment.center;
    } else {
      // Closing settings manually (without saving) just resizes window back down.
      // The old temp states will be naturally overridden by `SyncTempSettingsEvent` next time settings are opened.
      appWindow.minSize = const Size(300, 150);
      await windowManager.setMinimumSize(const Size(400, 150));
      await windowManager.setSize(const Size(730, 150));
      appWindow.alignment = Alignment.bottomCenter;
    }
  }

  Future<void> _onToggleShrink(
    ToggleShrinkEvent event,
    Emitter<TranslationState> emit,
  ) async {
    final bool willShrink = !state.isShrunk;
    emit(state.copyWith(isShrunk: willShrink));

    if (willShrink) {
      appWindow.minSize = const Size(100, 20);
      await windowManager.setMinimumSize(const Size(100, 20));
      await windowManager.setSize(const Size(730, 80));
    } else {
      appWindow.minSize = const Size(300, 150);
      await windowManager.setMinimumSize(const Size(400, 150));
      await windowManager.setSize(const Size(730, 150));
    }
  }

  void _onUpdateTempSetting(
    UpdateTempSettingEvent event,
    Emitter<TranslationState> emit,
  ) {
    emit(
      state.copyWith(
        tempTargetLang: event.targetLang,
        tempSourceLang: event.sourceLang,
        tempUseMic: event.useMic,
        tempFontSize: event.fontSize,
        tempIsBold: event.isBold,
        tempOpacity: event.opacity,
        // If the flag asks to clear it, override with null, else check if an int was provided
        tempInputDeviceIndex: event.clearInputDevice
            ? null
            : (event.inputDeviceIndex ?? state.tempInputDeviceIndex),
        tempOutputDeviceIndex: event.clearOutputDevice
            ? null
            : (event.outputDeviceIndex ?? state.tempOutputDeviceIndex),
      ),
    );
  }

  Future<void> _onSaveSettings(
    SaveSettingsEvent event,
    Emitter<TranslationState> emit,
  ) async {
    // 1. Flush temp into active
    emit(
      state.copyWith(
        activeTargetLang: state.tempTargetLang,
        activeSourceLang: state.tempSourceLang,
        activeUseMic: state.tempUseMic,
        activeFontSize: state.tempFontSize,
        activeIsBold: state.tempIsBold,
        activeOpacity: state.tempOpacity,
        activeInputDeviceIndex: state.tempInputDeviceIndex,
        activeOutputDeviceIndex: state.tempOutputDeviceIndex,
      ),
    );

    // 2. Notify Python Backend
    asrClient.updateSettings(
      targetLang: state.activeTargetLang,
      sourceLang: state.activeSourceLang,
      useMic: state.activeUseMic,
      inputDeviceIndex: state.activeInputDeviceIndex,
      outputDeviceIndex: state.activeOutputDeviceIndex,
    );

    // 3. Close the settings UI and revert bounds by dispatching a toggle
    // Notice this fires the toggle event to close, since `isSettingsOpen` is true
    add(ToggleSettingsEvent());
  }

  Future<void> _onLoadDevices(
    LoadDevicesEvent event,
    Emitter<TranslationState> emit,
  ) async {
    emit(state.copyWith(devicesLoading: true));
    final result = await asrClient.loadDevices();
    emit(
      state.copyWith(
        inputDevices:
            (result['input'] as List?)?.cast<Map<String, dynamic>>() ?? [],
        outputDevices:
            (result['output'] as List?)?.cast<Map<String, dynamic>>() ?? [],
        devicesLoading: false,
      ),
    );
  }

  @override
  Future<void> close() {
    _captionSub?.cancel();
    asrClient.stop();
    return super.close();
  }
}
