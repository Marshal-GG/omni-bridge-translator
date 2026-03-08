import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:window_manager/window_manager.dart';
import 'translation_event.dart';
import 'translation_state.dart';
import '../../../core/services/asr_ws_client.dart';
import '../../../core/services/tracking_service.dart';
import '../../../core/services/asr_text_controller.dart';
import '../../../core/services/subscription_service.dart';
import '../../../core/window_manager.dart';

class TranslationBloc extends Bloc<TranslationEvent, TranslationState> {
  final AsrWebSocketClient asrClient;
  StreamSubscription? _captionSub;
  StreamSubscription? _statusSub;
  int _lastLineCount = 0;

  TranslationBloc({required this.asrClient})
    : super(TranslationState.initial()) {
    on<UpdateQuotaEvent>(_onUpdateQuota);
    on<QuotaExceededEvent>(_onQuotaExceeded);
    on<ToggleSettingsEvent>(_onToggleSettings);
    on<ToggleShrinkEvent>(_onToggleShrink);
    on<ToggleRunningEvent>(_onToggleRunning);
    on<CaptionTextChangedEvent>(_onCaptionTextChanged);
    on<SourceLangOverrideEvent>(_onSourceLangOverride);
    on<ApplySettingsEvent>(_onApplySettings);
    on<LoadSettingsEvent>(_onLoadSettings);
    on<LangErrorEvent>(_onLangError);

    _initAsr();
    _initQuotaListener();
  }

  void _initQuotaListener() {
    _statusSub = SubscriptionService.instance.statusStream.listen((status) {
      add(UpdateQuotaEvent(status));
    });
  }

  void _initAsr() {
    add(LoadSettingsEvent());

    if (state.isRunning && !state.isQuotaExceeded) {
      asrClient.start(
        sourceLang: state.activeSourceLang,
        targetLang: state.activeTargetLang,
        useMic: state.activeUseMic,
        inputDeviceIndex: state.activeInputDeviceIndex,
        outputDeviceIndex: state.activeOutputDeviceIndex,
        translationModel: state.activeTranslationModel,
        apiKey: state.activeApiKey,
        transcriptionModel: state.activeTranscriptionModel,
      );
    }

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
          state.activeTranslationModel,
        );

        if (msg.isFinal && msg.text.trim().isNotEmpty) {
          if (state.activeApiKey.isEmpty) {
            SubscriptionService.instance.incrementChars(msg.text.length);
          }
        }
      }
    });
  }

  void _onSourceLangOverride(
    SourceLangOverrideEvent event,
    Emitter<TranslationState> emit,
  ) {
    emit(state.copyWith(activeSourceLang: event.sourceLang));
  }

  void _onToggleRunning(
    ToggleRunningEvent event,
    Emitter<TranslationState> emit,
  ) {
    if (state.isRunning) {
      asrClient.stop();
      emit(state.copyWith(isRunning: false));
    } else {
      if (state.isQuotaExceeded && state.activeApiKey.isEmpty) {
        add(QuotaExceededEvent());
        return;
      }
      asrClient.start(
        sourceLang: state.activeSourceLang,
        targetLang: state.activeTargetLang,
        useMic: state.activeUseMic,
        inputDeviceIndex: state.activeInputDeviceIndex,
        outputDeviceIndex: state.activeOutputDeviceIndex,
        translationModel: state.activeTranslationModel,
        apiKey: state.activeApiKey,
        transcriptionModel: state.activeTranscriptionModel,
      );
      emit(state.copyWith(isRunning: true));
    }
  }

  void _onUpdateQuota(UpdateQuotaEvent event, Emitter<TranslationState> emit) {
    final bool exceeded = event.status.isExceeded;
    emit(state.copyWith(quotaStatus: event.status, isQuotaExceeded: exceeded));

    if (exceeded && state.isRunning && state.activeApiKey.isEmpty) {
      asrClient.stop();
      emit(state.copyWith(isRunning: false));
      add(QuotaExceededEvent());
    }
  }

  void _onQuotaExceeded(
    QuotaExceededEvent event,
    Emitter<TranslationState> emit,
  ) {
    // Handled by UI layers/listeners
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
      final translationModel =
          settings['translationModel'] as String? ??
          settings['aiEngine'] as String? ??
          state.activeTranslationModel;
      final apiKey = settings['apiKey'] as String? ?? '';
      var transcriptionModel =
          settings['transcriptionModel'] as String? ??
          settings['transcriptionEngine'] as String? ??
          'online';

      if (transcriptionModel == 'whisper') {
        transcriptionModel = 'whisper-base';
      }

      // Update BLoC state natively
      emit(
        state.copyWith(
          activeTargetLang: targetLang,
          activeSourceLang: sourceLang,
          activeUseMic: useMic,
          activeFontSize: fontSize,
          activeIsBold: isBold,
          activeOpacity: opacity,
          activeTranslationModel: translationModel,
          activeApiKey: apiKey,
          activeTranscriptionModel: transcriptionModel,
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
        translationModel: translationModel,
        apiKey: apiKey,
        transcriptionModel: transcriptionModel,
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
    )..layout(maxWidth: availableWidth);

    final metrics = painter.computeLineMetrics();
    final lineCount = metrics.length;

    // 1. Handle window resizing for SHRUNK mode
    if (state.isShrunk) {
      final displayLineCount = lineCount.clamp(1, 2);
      if (displayLineCount != _lastLineCount) {
        _lastLineCount = displayLineCount;
        final newHeight = (state.activeFontSize * displayLineCount * 1.6 + vPad)
            .clamp(minHeight, 300.0);
        await windowManager.setSize(Size(event.windowWidth, newHeight));
      }
    }

    // 2. Handle line shifting/trimming if total lines > 2
    if (lineCount > 2) {
      // Find the end index of the first line to trim it
      final firstLineEnd = painter
          .getLineBoundary(const TextPosition(offset: 0))
          .end;
      if (firstLineEnd > 0) {
        // We trim by adding 1 to account for the space separator in the controller
        asrTextController.trimBy(firstLineEnd + 1);
      }
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

      // bitsdojo_window alignment
      // Removed forced alignment to keep window where it was
      await windowManager.setAlwaysOnTop(true);
      appWindow.minSize = const Size(100, 20);
      await windowManager.setMinimumSize(const Size(100, 20));
      await windowManager.setSize(Size(730, shrinkHeight));
    } else {
      appWindow.minSize = const Size(
        300,
        150,
      ); // Increased width, consistent height
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
        activeTranslationModel: event.translationModel,
        activeApiKey: event.apiKey,
        activeTranscriptionModel: event.transcriptionModel,
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
      translationModel: event.translationModel,
      apiKey: event.apiKey,
      transcriptionModel: event.transcriptionModel,
    );

    // Sync settings to Firestore
    TrackingService.instance.syncSettings({
      'targetLang': event.targetLang,
      'sourceLang': event.sourceLang,
      'useMic': event.useMic,
      'fontSize': event.fontSize,
      'isBold': event.isBold,
      'opacity': event.opacity,
      'translationModel': event.translationModel,
      'apiKey': event.apiKey,
      'transcriptionModel': event.transcriptionModel,
    });
  }

  @override
  Future<void> close() {
    _captionSub?.cancel();
    _statusSub?.cancel();
    asrClient.stop();
    return super.close();
  }
}
