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
    on<SourceLangOverrideEvent>(_onSourceLangOverride);
    on<ApplySettingsEvent>(_onApplySettings);
    on<LangErrorEvent>(_onLangError);

    _initAsr();
  }

  void _initAsr() {
    asrClient.attachBloc(this);
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

  void _onLangError(LangErrorEvent event, Emitter<TranslationState> emit) {
    emit(state.copyWith(autoDetectWarning: event.message));
    emit(state.copyWith(autoDetectWarning: null));
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

      appWindow.minSize = const Size(600, 300);
      await windowManager.setMinimumSize(const Size(600, 300));
      await windowManager.setSize(const Size(600, 700));
      appWindow.alignment = Alignment.center;
    } else {
      // Closing settings manually (without saving) just resizes window back down.
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

  Future<void> _onApplySettings(
    ApplySettingsEvent event,
    Emitter<TranslationState> emit,
  ) async {
    // 1. Flush temp into active
    emit(
      state.copyWith(
        activeTargetLang: event.targetLang,
        activeSourceLang: event.sourceLang,
        activeUseMic: event.useMic,
        activeFontSize: event.fontSize,
        activeIsBold: event.isBold,
        activeOpacity: event.opacity,
        activeInputDeviceIndex: event.inputDeviceIndex,
        activeOutputDeviceIndex: event.outputDeviceIndex,
        activeDesktopVolume: event.desktopVolume,
        activeMicVolume: event.micVolume,
      ),
    );

    asrClient.updateSettings(
      targetLang: event.targetLang,
      sourceLang: event.sourceLang,
      useMic: event.useMic,
      inputDeviceIndex: event.inputDeviceIndex,
      outputDeviceIndex: event.outputDeviceIndex,
      desktopVolume: event.desktopVolume,
      micVolume: event.micVolume,
    );

    add(ToggleSettingsEvent());
  }

  @override
  Future<void> close() {
    _captionSub?.cancel();
    asrClient.stop();
    return super.close();
  }
}
