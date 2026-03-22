import 'dart:async';
import 'package:flutter/material.dart';
import 'package:omni_bridge/features/subscription/data/models/subscription_dto.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:window_manager/window_manager.dart';
import 'package:omni_bridge/features/translation/presentation/blocs/translation_event.dart';
import 'package:omni_bridge/features/translation/presentation/blocs/translation_state.dart';
import 'package:omni_bridge/core/device/asr_text_controller.dart';
import 'package:omni_bridge/features/translation/domain/usecases/get_model_status_usecase.dart';
import 'package:omni_bridge/features/translation/domain/usecases/start_translation_usecase.dart';
import 'package:omni_bridge/features/translation/domain/usecases/stop_translation_usecase.dart';
import 'package:omni_bridge/features/translation/domain/usecases/update_volume_usecase.dart';
import 'package:omni_bridge/features/translation/domain/usecases/observe_captions_usecase.dart';
import 'package:omni_bridge/features/translation/domain/usecases/observe_quota_status_usecase.dart';
import 'package:omni_bridge/features/translation/domain/usecases/get_initial_quota_status_usecase.dart';
import 'package:omni_bridge/features/translation/domain/usecases/get_default_tier_usecase.dart';
import 'package:omni_bridge/features/translation/domain/usecases/update_translation_settings_usecase.dart';
import 'package:omni_bridge/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:omni_bridge/features/auth/domain/usecases/observe_auth_changes_usecase.dart';
import 'package:omni_bridge/features/settings/domain/usecases/get_app_settings_usecase.dart';
import 'package:omni_bridge/features/settings/domain/usecases/get_google_credentials_usecase.dart';
import 'package:omni_bridge/features/settings/domain/usecases/sync_settings_usecase.dart';
import 'package:omni_bridge/features/settings/domain/usecases/log_event_usecase.dart';
import 'package:omni_bridge/features/auth/domain/usecases/logout_usecase.dart';

class TranslationBloc extends Bloc<TranslationEvent, TranslationState> {
  final StartTranslationUseCase startTranslationUseCase;
  final StopTranslationUseCase stopTranslationUseCase;
  final UpdateVolumeUseCase updateVolumeUseCase;
  final GetModelStatusUseCase getModelStatusUseCase;
  final ObserveCaptionsUseCase observeCaptionsUseCase;
  final ObserveQuotaStatusUseCase observeQuotaStatusUseCase;
  final GetInitialQuotaStatusUseCase getInitialQuotaStatusUseCase;
  final GetDefaultTierUseCase getDefaultTierUseCase;
  final UpdateTranslationSettingsUseCase updateTranslationSettingsUseCase;
  final GetCurrentUserUseCase getCurrentUserUseCase;
  final ObserveAuthChangesUseCase observeAuthChangesUseCase;
  final GetAppSettingsUseCase getAppSettingsUseCase;
  final GetGoogleCredentialsUseCase getGoogleCredentialsUseCase;
  final SyncSettingsUseCase syncSettingsUseCase;
  final LogEventUseCase logEventUseCase;
  final LogoutUseCase logoutUseCase;

  StreamSubscription? _captionSub;
  StreamSubscription? _statusSub;
  int _lastLineCount = 0;

  TranslationBloc({
    required this.startTranslationUseCase,
    required this.stopTranslationUseCase,
    required this.updateVolumeUseCase,
    required this.getModelStatusUseCase,
    required this.observeCaptionsUseCase,
    required this.observeQuotaStatusUseCase,
    required this.getInitialQuotaStatusUseCase,
    required this.getDefaultTierUseCase,
    required this.updateTranslationSettingsUseCase,
    required this.getCurrentUserUseCase,
    required this.observeAuthChangesUseCase,
    required this.getAppSettingsUseCase,
    required this.getGoogleCredentialsUseCase,
    required this.syncSettingsUseCase,
    required this.logEventUseCase,
    required this.logoutUseCase,
  }) : super(
         TranslationState.initial().copyWith(
           quotaStatus: getInitialQuotaStatusUseCase(),
           isQuotaExceeded: getInitialQuotaStatusUseCase()?.isExceeded ?? false,
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
      final statuses = await getModelStatusUseCase();
      add(ModelStatusChangedEvent(statuses));
    } catch (e) {
      debugPrint('Error fetching initial model statuses: $e');
    }
  }

  void _initAuthListener() {
    // Re-load settings whenever the user signs in
    getCurrentUserUseCase().addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    if (getCurrentUserUseCase().value != null && !isClosed) {
      debugPrint('[TranslationBloc] Auth detected, reloading settings...');
      add(LoadSettingsEvent());
    }
  }

  void _initQuotaListener() {
    final initialStatus = getInitialQuotaStatusUseCase();
    if (initialStatus != null) {
      add(UpdateQuotaEvent(initialStatus));
    } else {
      add(
        UpdateQuotaEvent(
          SubscriptionStatus(
            tier: getDefaultTierUseCase(),
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

    _statusSub = observeQuotaStatusUseCase().listen((status) {
      add(UpdateQuotaEvent(status));
    });
  }

  void _initAsr() {
    add(LoadSettingsEvent());

    _captionSub = observeCaptionsUseCase()?.listen((msg) {
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
        logEventUseCase(
          'live_caption',
          parameters: {
            'original': msg.original,
            'text': text,
            'source_lang': override ?? state.activeSourceLang,
            'target_lang': state.activeTargetLang,
            'is_final': msg.isFinal,
            'model': state.activeTranslationModel,
          },
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

  void _onModelStatusChanged(
    ModelStatusChangedEvent event,
    Emitter<TranslationState> emit,
  ) {
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
      stopTranslationUseCase();
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

      final result = await getGoogleCredentialsUseCase();
      final googleCredentialsJson = state.activeTranslationModel == 'google_api'
          ? result.getOrElse(() => '')
          : '';

      startTranslationUseCase(
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
    final bool exceeded = event.status?.isExceeded ?? false;
    emit(state.copyWith(quotaStatus: event.status, isQuotaExceeded: exceeded));

    if (exceeded && state.isRunning) {
      stopTranslationUseCase();
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
      final result = await getAppSettingsUseCase();
      result.fold(
        (failure) => debugPrint('Error loading settings: ${failure.message}'),
        (settings) async {
          if (settings != null) {
            emit(
              state.copyWith(
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
              ),
            );

            // Trigger status update in backend
            add(
              ApplySettingsEvent(
                targetLang: settings.targetLang,
                sourceLang: settings.sourceLang,
                useMic: settings.useMic,
                fontSize: settings.fontSize,
                isBold: settings.isBold,
                opacity: settings.opacity,
                inputDeviceIndex: settings.inputDeviceIndex,
                outputDeviceIndex: settings.outputDeviceIndex,
                desktopVolume: settings.desktopVolume,
                micVolume: settings.micVolume,
                translationModel: settings.translationModel,
                apiKey: settings.apiKey,
                transcriptionModel: settings.transcriptionModel,
              ),
            );
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
    updateVolumeUseCase(desktopVolume: desktopVolume, micVolume: micVolume);
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
      final result = await getGoogleCredentialsUseCase();
      final googleCredentialsJsonOnApply =
          event.translationModel == 'google_api'
          ? result.getOrElse(() => '')
          : '';

      updateTranslationSettingsUseCase(
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

      await syncSettingsUseCase({
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
    getCurrentUserUseCase().removeListener(_onAuthChanged);
    _captionSub?.cancel();
    _statusSub?.cancel();
    stopTranslationUseCase();
    return super.close();
  }
}
