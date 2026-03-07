import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:window_manager/window_manager.dart';
import 'translation_event.dart';
import 'translation_state.dart';
import '../../../core/services/asr_ws_client.dart';
import '../../../core/services/tracking_service.dart';
import '../../../core/window_manager.dart';

class TranslationBloc extends Bloc<TranslationEvent, TranslationState> {
  final AsrWebSocketClient asrClient;
  StreamSubscription? _captionSub;
  int _lastLineCount = 0;

  TranslationBloc({required this.asrClient})
    : super(TranslationState.initial()) {
    on<ToggleSettingsEvent>(_onToggleSettings);
    on<ToggleShrinkEvent>(_onToggleShrink);
    on<CaptionTextChangedEvent>(_onCaptionTextChanged);
    on<SourceLangOverrideEvent>(_onSourceLangOverride);
    on<ApplySettingsEvent>(_onApplySettings);
    on<LoadSettingsEvent>(_onLoadSettings);
    on<LangErrorEvent>(_onLangError);

    _initAsr();
  }

  void _initAsr() {
    add(LoadSettingsEvent());
    asrClient.attachBloc(this);
    asrClient.start(
      sourceLang: state.activeSourceLang,
      targetLang: state.activeTargetLang,
      useMic: state.activeUseMic,
      inputDeviceIndex: state.activeInputDeviceIndex,
      outputDeviceIndex: state.activeOutputDeviceIndex,
      aiEngine: state.activeAiEngine,
      apiKey: state.activeApiKey,
      transcriptionEngine: state.activeTranscriptionEngine,
    );

    _captionSub = asrClient.captions?.listen((msg) {
      if (msg.sourceLangOverride != null && !isClosed) {
        add(SourceLangOverrideEvent(msg.sourceLangOverride!));
      }
      if (msg.text.trim().isNotEmpty) {
        TrackingService.instance.syncLiveCaption(
          msg.original,
          msg.text,
          msg.sourceLangOverride ?? state.activeSourceLang,
          state.activeTargetLang,
          msg.isFinal,
          state.activeAiEngine,
        );
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

  Future<void> _onLoadSettings(
    LoadSettingsEvent event,
    Emitter<TranslationState> emit,
  ) async {
    final settings = await TrackingService.instance.getSettings();
    if (settings != null) {
      final targetLang =
          settings['targetLang'] as String? ?? state.activeTargetLang;
      final sourceLang =
          settings['sourceLang'] as String? ?? state.activeSourceLang;
      final useMic = settings['useMic'] as bool? ?? state.activeUseMic;
      final fontSize =
          (settings['fontSize'] as num?)?.toDouble() ?? state.activeFontSize;
      final isBold = settings['isBold'] as bool? ?? state.activeIsBold;
      final opacity =
          (settings['opacity'] as num?)?.toDouble() ?? state.activeOpacity;
      final aiEngine = settings['aiEngine'] as String? ?? state.activeAiEngine;
      final apiKey = settings['apiKey'] as String? ?? '';
      final transcriptionEngine =
          settings['transcriptionEngine'] as String? ?? 'online';

      // Update BLoC state natively
      emit(
        state.copyWith(
          activeTargetLang: targetLang,
          activeSourceLang: sourceLang,
          activeUseMic: useMic,
          activeFontSize: fontSize,
          activeIsBold: isBold,
          activeOpacity: opacity,
          activeAiEngine: aiEngine,
          activeApiKey: apiKey,
          activeTranscriptionEngine: transcriptionEngine,
        ),
      );

      // Tell underlying ASR engine we changed things on init load
      asrClient.updateSettings(
        targetLang: targetLang,
        sourceLang: sourceLang,
        useMic: useMic,
        inputDeviceIndex: state.activeInputDeviceIndex,
        outputDeviceIndex: state.activeOutputDeviceIndex,
        desktopVolume: state.activeDesktopVolume,
        micVolume: state.activeMicVolume,
        aiEngine: aiEngine,
        apiKey: apiKey,
        transcriptionEngine: transcriptionEngine,
      );
    }
  }

  Future<void> _onToggleSettings(
    ToggleSettingsEvent event,
    Emitter<TranslationState> emit,
  ) async {
    final bool willOpen = !state.isSettingsOpen;
    emit(state.copyWith(isSettingsOpen: willOpen));

    if (willOpen) {
      if (state.isShrunk) {
        emit(state.copyWith(isShrunk: false));
      }
      await setToSettingsPosition();
    } else {
      await setToTranslationPosition();
    }
  }

  Future<void> _onCaptionTextChanged(
    CaptionTextChangedEvent event,
    Emitter<TranslationState> emit,
  ) async {
    if (!state.isShrunk) return;

    const double hPad = 16 * 2;
    const double vPad = 20;
    const double minHeight = 60.0;

    final availableWidth = (event.windowWidth - hPad).clamp(100.0, 10000.0);

    final painter = TextPainter(
      text: TextSpan(
        text: event.text.isEmpty ? 'Listening...' : event.text,
        style: TextStyle(
          fontSize: state.activeFontSize,
          fontWeight: state.activeIsBold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
    )..layout(maxWidth: availableWidth);

    final lineCount = painter.computeLineMetrics().length.clamp(1, 2);

    if (lineCount != _lastLineCount) {
      _lastLineCount = lineCount;
      final newHeight = (state.activeFontSize * lineCount * 1.6 + vPad).clamp(
        minHeight,
        300.0,
      );
      await windowManager.setSize(Size(event.windowWidth, newHeight));
    }
  }

  Future<void> _onToggleShrink(
    ToggleShrinkEvent event,
    Emitter<TranslationState> emit,
  ) async {
    final bool willShrink = !state.isShrunk;
    emit(state.copyWith(isShrunk: willShrink));

    if (willShrink) {
      double shrinkHeight = state.activeFontSize * 3 + 30;
      if (shrinkHeight < 70) shrinkHeight = 70;

      appWindow.minSize = const Size(100, 20);
      await windowManager.setMinimumSize(const Size(100, 20));
      await windowManager.setSize(Size(730, shrinkHeight));
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
        activeAiEngine: event.aiEngine,
        activeApiKey: event.apiKey,
        activeTranscriptionEngine: event.transcriptionEngine,
      ),
    );

    // 2. If already shrunk, resize to match the new font size
    if (state.isShrunk) {
      double shrinkHeight = event.fontSize * 3 + 30;
      if (shrinkHeight < 70) shrinkHeight = 70;
      await windowManager.setSize(Size(730, shrinkHeight));
    }

    asrClient.updateSettings(
      targetLang: event.targetLang,
      sourceLang: event.sourceLang,
      useMic: event.useMic,
      inputDeviceIndex: event.inputDeviceIndex,
      outputDeviceIndex: event.outputDeviceIndex,
      desktopVolume: event.desktopVolume,
      micVolume: event.micVolume,
      aiEngine: event.aiEngine,
      apiKey: event.apiKey,
      transcriptionEngine: event.transcriptionEngine,
    );

    // Sync settings to Firestore
    TrackingService.instance.syncSettings({
      'targetLang': event.targetLang,
      'sourceLang': event.sourceLang,
      'useMic': event.useMic,
      'fontSize': event.fontSize,
      'isBold': event.isBold,
      'opacity': event.opacity,
      'aiEngine': event.aiEngine,
      'apiKey': event.apiKey,
      'transcriptionEngine': event.transcriptionEngine,
    });

    add(ToggleSettingsEvent());
  }

  @override
  Future<void> close() {
    _captionSub?.cancel();
    asrClient.stop();
    return super.close();
  }
}
