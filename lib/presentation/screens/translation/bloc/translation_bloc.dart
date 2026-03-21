import 'dart:async';
import 'package:flutter/material.dart';
import 'package:omni_bridge/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:omni_bridge/domain/repositories/settings_repository.dart';
import 'package:omni_bridge/domain/repositories/translation_repository.dart';
import 'package:omni_bridge/data/models/subscription_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:window_manager/window_manager.dart';
import 'package:omni_bridge/presentation/screens/translation/bloc/translation_event.dart';
import 'package:omni_bridge/presentation/screens/translation/bloc/translation_state.dart';
import 'package:omni_bridge/core/device/asr_text_controller.dart';
import 'package:omni_bridge/data/services/translation/whisper_service.dart';

class TranslationBloc extends Bloc<TranslationEvent, TranslationState> {
  final ITranslationRepository translationRepo;
  final IAuthRepository authRepo;
  final ISettingsRepository settingsRepo;

  StreamSubscription? _captionSub;
  StreamSubscription? _statusSub;
  int _lastLineCount = 0;
  final WhisperService _whisperService = WhisperService();

  TranslationBloc({
    required this.translationRepo,
    required this.authRepo,
    required this.settingsRepo,
  }) : super(
          TranslationState.initial().copyWith(
            quotaStatus: translationRepo.currentQuotaStatus,
            isQuotaExceeded:
                translationRepo.currentQuotaStatus?.isExceeded ?? false,
          ),
        ) {
    on<UpdateQuotaEvent>(_onUpdateQuota);
    on<QuotaExceededEvent>(_onQuotaExceeded);
    on<ToggleShrinkEvent>(_onToggleShrink);
    on<ToggleRunningEvent>(_onToggleRunning);
    on<CaptionTextChangedEvent>(_onCaptionTextChanged);
    on<SourceLangOverrideEvent>(_onSourceLangOverride);
    on<ModelStatusChangedEvent>(_onModelStatusChanged);
    on<ApplySettingsEvent>(_onApplySettings);
    on<LoadSettingsEvent>(_onLoadSettings);
    on<LangErrorEvent>(_onLangError);

    // Initial load of model statuses
    _fetchInitialModelStatuses();

    _initAsr();
    _initQuotaListener();
    _initAuthListener();
  }

  Future<void> _fetchInitialModelStatuses() async {
    try {
      final statuses = await _whisperService.getModelStatuses();
      add(ModelStatusChangedEvent(statuses));
    } catch (e) {
      debugPrint('Error fetching initial model statuses: $e');
    }
  }

  void _initAuthListener() {
    // Re-load settings whenever the user signs in
    authRepo.currentUser.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    if (authRepo.currentUser.value != null && !isClosed) {
      debugPrint('[TranslationBloc] Auth detected, reloading settings...');
      add(LoadSettingsEvent());
    }
  }

  void _initQuotaListener() {
    final initialStatus = translationRepo.currentQuotaStatus;
    if (initialStatus != null) {
      add(UpdateQuotaEvent(initialStatus));
    } else {
      add(
        UpdateQuotaEvent(
          SubscriptionStatus(
            tier: translationRepo.defaultTier,
            dailyTokensUsed: 0,
            weeklyTokensUsed: 0,
            monthlyTokensUsed: 0,
            lifetimeTokensUsed: 0,
            dailyLimit: 10000,
            dailyResetAt: DateTime.now(),
          ),
        ),
      );
    }

    _statusSub = translationRepo.quotaStatusStream.listen((status) {
      add(UpdateQuotaEvent(status));
    });
  }

  void _initAsr() {
    add(LoadSettingsEvent());

    _captionSub = translationRepo.captions?.listen((msg) {
      final override = msg.sourceLangOverride;
      if (override != null && !isClosed) {
        add(SourceLangOverrideEvent(override));
      }

      if (msg.modelStatuses != null) {
        add(ModelStatusChangedEvent(msg.modelStatuses!));
      }
      
      if (msg.usageStats != null) {
        debugPrint('Received usageStats from ASR client: ${msg.usageStats}');
      }

      final text = msg.text;
      if (text.trim().isNotEmpty) {
        settingsRepo.logEvent('live_caption', parameters: {
          'original': msg.original,
          'text': text,
          'source_lang': override ?? state.activeSourceLang,
          'target_lang': state.activeTargetLang,
          'is_final': msg.isFinal,
          'model': state.activeTranslationModel,
        });
      }
    });
  }

  void _onSourceLangOverride(
    SourceLangOverrideEvent event,
    Emitter<TranslationState> emit,
  ) {
    emit(state.copyWith(activeSourceLang: event.sourceLang));
  }

  void _onModelStatusChanged(
      ModelStatusChangedEvent event, Emitter<TranslationState> emit) {
    final newStatuses = Map<String, dynamic>.from(state.modelStatuses);
    for (final status in event.statuses) {
      if (status is Map<String, dynamic> && status.containsKey('name')) {
        newStatuses[status['name']] = status;
      }
    }
    emit(state.copyWith(modelStatuses: newStatuses));
  }

  Future<void> _onToggleRunning(
    ToggleRunningEvent event,
    Emitter<TranslationState> emit,
  ) async {
    if (state.isRunning) {
      translationRepo.stop();
      emit(state.copyWith(isRunning: false));
    } else {
      if (state.isQuotaExceeded) {
        emit(
          state.copyWith(
            navToSubscriptionTrigger: state.navToSubscriptionTrigger + 1,
          ),
        );
        add(QuotaExceededEvent());
        return;
      }
      
      final result = await settingsRepo.getGoogleCredentials();
      final googleCredentialsJson = state.activeTranslationModel == 'google_api'
          ? result.getOrElse(() => '')
          : '';

      translationRepo.start(
        sourceLang: state.activeSourceLang,
        targetLang: state.activeTargetLang,
        useMic: state.activeUseMic,
        inputDeviceIndex: state.activeInputDeviceIndex,
        outputDeviceIndex: state.activeOutputDeviceIndex,
        translationModel: state.activeTranslationModel,
        apiKey: state.activeApiKey,
        googleCredentialsJson: googleCredentialsJson,
        transcriptionModel: state.activeTranscriptionModel,
      );
      emit(state.copyWith(isRunning: true));
    }
  }

  void _onUpdateQuota(UpdateQuotaEvent event, Emitter<TranslationState> emit) {
    final bool exceeded = event.status.isExceeded;
    emit(state.copyWith(quotaStatus: event.status, isQuotaExceeded: exceeded));

    if (exceeded && state.isRunning) {
      translationRepo.stop();
      emit(
        state.copyWith(
          isRunning: false,
          navToSubscriptionTrigger: state.navToSubscriptionTrigger + 1,
        ),
      );
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
    emit(state.copyWith(isSettingsLoading: true));
    try {
      final result = await settingsRepo.getSettings();
      result.fold(
        (failure) => debugPrint('Error loading settings: ${failure.message}'),
        (settings) {
          if (settings != null) {
            emit(state.copyWith(
              activeTargetLang: settings.targetLang,
              activeSourceLang: settings.sourceLang,
              activeUseMic: settings.useMic,
              activeFontSize: settings.fontSize,
              activeIsBold: settings.isBold,
              activeOpacity: settings.opacity,
              activeInputDeviceIndex: settings.inputDeviceIndex,
              activeOutputDeviceIndex: settings.outputDeviceIndex,
              activeDesktopVolume: settings.desktopVolume,
              activeMicVolume: settings.micVolume,
              activeTranslationModel: settings.translationModel,
              activeApiKey: settings.apiKey,
              activeTranscriptionModel: settings.transcriptionModel,
            ));
          }
        },
      );
    } catch (e) {
      debugPrint('Error loading settings: $e');
    } finally {
      emit(state.copyWith(isSettingsLoading: false));
    }
  }

  void liveVolumeUpdate({
    required double desktopVolume,
    required double micVolume,
  }) {
    translationRepo.liveVolumeUpdate(
      desktopVolume: desktopVolume,
      micVolume: micVolume,
    );
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

    if (state.isShrunk) {
      final displayLineCount = lineCount.clamp(1, 2);
      if (displayLineCount != _lastLineCount) {
        _lastLineCount = displayLineCount;
        final newHeight = (state.activeFontSize * displayLineCount * 1.6 + vPad)
            .clamp(minHeight, 300.0);
        await windowManager.setSize(Size(event.windowWidth, newHeight));
      }
    }

    if (lineCount > 2) {
      final firstLineEnd = painter
          .getLineBoundary(const TextPosition(offset: 0))
          .end;
      if (firstLineEnd > 0) {
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

      await windowManager.setAlwaysOnTop(true);
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
        isSettingsSaving: true,
      ),
    );

    if (state.isShrunk) {
      double shrinkHeight = event.fontSize * 3 + 30;
      if (shrinkHeight < 70) shrinkHeight = 70;
      await windowManager.setSize(Size(730, shrinkHeight));
    }

    try {
      final result = await settingsRepo.getGoogleCredentials();
      final googleCredentialsJsonOnApply = event.translationModel == 'google_api'
          ? result.getOrElse(() => '')
          : '';

      translationRepo.updateSettings(
        targetLang: event.targetLang,
        sourceLang: event.sourceLang,
        useMic: event.useMic,
        inputDeviceIndex: event.inputDeviceIndex,
        outputDeviceIndex: event.outputDeviceIndex,
        desktopVolume: event.desktopVolume,
        micVolume: event.micVolume,
        translationModel: event.translationModel,
        apiKey: event.apiKey,
        googleCredentialsJson: googleCredentialsJsonOnApply,
        transcriptionModel: event.transcriptionModel,
      );

      await settingsRepo.syncSettings({
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
    } finally {
      emit(state.copyWith(isSettingsSaving: false));
    }
  }

  @override
  Future<void> close() {
    authRepo.currentUser.removeListener(_onAuthChanged);
    _captionSub?.cancel();
    _statusSub?.cancel();
    translationRepo.stop();
    return super.close();
  }
}

