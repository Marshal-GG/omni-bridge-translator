import 'dart:async';
import 'package:flutter/material.dart';

import 'package:omni_bridge/features/translation/domain/usecases/unload_model_usecase.dart';
import 'package:omni_bridge/features/subscription/domain/usecases/check_model_access_usecase.dart';
import 'package:omni_bridge/features/subscription/domain/usecases/check_engine_limit_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:window_manager/window_manager.dart';
import 'package:omni_bridge/features/translation/presentation/blocs/translation_event.dart';
import 'package:omni_bridge/features/translation/presentation/blocs/translation_state.dart';
import 'package:omni_bridge/core/device/asr_text_controller.dart';
import 'package:omni_bridge/features/translation/domain/usecases/get_model_status_usecase.dart';
import 'package:omni_bridge/features/translation/domain/usecases/start_translation_usecase.dart';
import 'package:omni_bridge/features/translation/domain/usecases/stop_translation_usecase.dart';
import 'package:omni_bridge/features/translation/domain/usecases/observe_captions_usecase.dart';
import 'package:omni_bridge/features/translation/domain/usecases/observe_quota_status_usecase.dart';
import 'package:omni_bridge/features/translation/domain/usecases/get_initial_quota_status_usecase.dart';
import 'package:omni_bridge/features/translation/domain/usecases/update_translation_settings_usecase.dart';
import 'package:omni_bridge/features/translation/domain/usecases/check_server_health_usecase.dart';
import 'package:omni_bridge/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:omni_bridge/features/settings/domain/entities/app_settings.dart';
import 'package:omni_bridge/features/settings/domain/usecases/get_app_settings_usecase.dart';
import 'package:omni_bridge/features/settings/domain/usecases/get_google_credentials_usecase.dart';
import 'package:omni_bridge/features/settings/domain/usecases/sync_settings_usecase.dart';
import 'package:omni_bridge/features/settings/domain/usecases/log_event_usecase.dart';
import 'package:omni_bridge/features/settings/domain/usecases/get_system_config_usecase.dart';
import 'package:omni_bridge/features/settings/domain/entities/system_config.dart';
import 'package:omni_bridge/core/utils/app_logger.dart';
import 'package:omni_bridge/core/infrastructure/python_server_manager.dart';

class TranslationBloc extends Bloc<TranslationEvent, TranslationState> {
  final StartTranslationUseCase startTranslationUseCase;
  final StopTranslationUseCase stopTranslationUseCase;
  final GetModelStatusUseCase getModelStatusUseCase;
  final ObserveCaptionsUseCase observeCaptionsUseCase;
  final ObserveQuotaStatusUseCase observeQuotaStatusUseCase;
  final GetInitialQuotaStatusUseCase getInitialQuotaStatusUseCase;
  final UpdateTranslationSettingsUseCase updateTranslationSettingsUseCase;
  final CheckServerHealthUseCase checkServerHealthUseCase;
  final GetCurrentUserUseCase getCurrentUserUseCase;
  final GetAppSettingsUseCase getAppSettingsUseCase;
  final GetGoogleCredentialsUseCase getGoogleCredentialsUseCase;
  final SyncSettingsUseCase syncSettingsUseCase;
  final LogEventUseCase logEventUseCase;
  final GetSystemConfigUseCase getSystemConfigUseCase;
  final UnloadModelUseCase unloadModelUseCase;
  final CheckModelAccessUseCase checkModelAccessUseCase;
  final CheckEngineLimitUseCase checkEngineLimitUseCase;

  StreamSubscription? _captionSub;
  StreamSubscription? _statusSub;
  Timer? _healthCheckTimer;
  int _lastLineCount = 0;

  TranslationBloc({
    required this.startTranslationUseCase,
    required this.stopTranslationUseCase,
    required this.getModelStatusUseCase,
    required this.observeCaptionsUseCase,
    required this.observeQuotaStatusUseCase,
    required this.getInitialQuotaStatusUseCase,
    required this.updateTranslationSettingsUseCase,
    required this.checkServerHealthUseCase,
    required this.getCurrentUserUseCase,
    required this.getAppSettingsUseCase,
    required this.getGoogleCredentialsUseCase,
    required this.syncSettingsUseCase,
    required this.logEventUseCase,
    required this.getSystemConfigUseCase,
    required this.unloadModelUseCase,
    required this.checkModelAccessUseCase,
    required this.checkEngineLimitUseCase,
  }) : super(
         TranslationState.initial().copyWith(
           quotaStatus: getInitialQuotaStatusUseCase(),
           isQuotaExceeded: getInitialQuotaStatusUseCase()?.isExceeded ?? false,
         ),
       ) {
    on<InitializeEvent>(_onInitialize);
    on<UpdateQuotaEvent>(_onUpdateQuota);
    on<QuotaExceededEvent>(_onQuotaExceeded);
    on<ToggleShrinkEvent>(_onToggleShrink);
    on<ToggleRunningEvent>(_onToggleRunning);
    on<CaptionTextChangedEvent>(_onCaptionTextChanged);
    on<SourceLangOverrideEvent>(_onSourceLangOverride);
    on<ModelStatusChangedEvent>(_onModelStatusChanged);
    on<ApplySettingsEvent>(_onApplySettings, transformer: sequential());
    on<LoadSettingsEvent>(_onLoadSettings, transformer: droppable());
    on<ResetSettingsEvent>(_onResetSettings);
    on<LangErrorEvent>(_onLangError);
    on<UpdateServerConnectionEvent>(_onUpdateServerConnection);
    on<EngineLimitReachedEvent>(_onEngineLimitReached);
    on<SwitchToFallbackEngineEvent>(_onSwitchToFallbackEngine);
    on<RequestModelUnloadEvent>(_onRequestModelUnload);
  }

  void _onInitialize(
    InitializeEvent event,
    Emitter<TranslationState> emit,
  ) {
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
      AppLogger.e(
        'Error fetching initial model statuses',
        error: e,
        tag: 'TranslationBloc',
      );
    }
  }

  void _initAuthListener() {
    // Re-load settings whenever the user signs in
    getCurrentUserUseCase().addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    final user = getCurrentUserUseCase().value;
    if (user != null && !isClosed) {
      AppLogger.i(
        'Auth detected, reloading settings...',
        tag: 'TranslationBloc',
      );
      add(LoadSettingsEvent());
    } else if (user == null && !isClosed) {
      AppLogger.i(
        'Logout detected, resetting settings...',
        tag: 'TranslationBloc',
      );
      add(ResetSettingsEvent());
    }
  }

  void _initQuotaListener() {
    _statusSub = observeQuotaStatusUseCase().listen((status) {
      add(UpdateQuotaEvent(status));
    });
  }

  void _initAsr() {
    _captionSub = observeCaptionsUseCase()?.listen((msg) {
      if (msg.isQuotaExceeded && state.isRunning && !isClosed) {
        AppLogger.w(
          'Server quota_exceeded received. Stopping session.',
          tag: 'TranslationBloc',
        );
        add(ToggleRunningEvent());
      }

      if (msg.isDisconnect) {
        if (!isClosed) {
          add(UpdateServerConnectionEvent(isConnected: false));
        }
        if (state.isRunning && !isClosed) {
          AppLogger.i(
            'Server disconnect detected. Auto-pausing.',
            tag: 'TranslationBloc',
          );
          add(ToggleRunningEvent());
        }
      } else {
        // If we receive a normal message, we know the server is connected
        if (!state.isServerConnected && !isClosed) {
          add(const UpdateServerConnectionEvent(isConnected: true));
        }
      }

      final override = msg.sourceLangOverride;
      if (override != null && !isClosed) {
        add(SourceLangOverrideEvent(override));
      }

      if (msg.modelStatuses != null) {
        add(ModelStatusChangedEvent(msg.modelStatuses!));
      }

      if (msg.usageStats != null) {
        AppLogger.i(
          'Received usageStats from ASR client: ${msg.usageStats}',
          tag: 'TranslationBloc',
        );
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
    final newState = state.copyWith(modelStatuses: newStatuses);
    emit(newState);
  }

  Future<void> _onToggleRunning(
    ToggleRunningEvent event,
    Emitter<TranslationState> emit,
  ) async {
    // Prevent starting translation if server is not connected
    if (!state.isRunning && !state.isServerConnected) {
      AppLogger.w(
        'Prevented resume: Server is not connected.',
        tag: 'TranslationBloc',
      );
      return;
    }

    if (state.isRunning) {
      unawaited(stopTranslationUseCase());
      final newState = state.copyWith(isRunning: false);
      emit(newState);
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
      final googleCredentials = state.activeTranslationModel == 'google_api'
          ? result.getOrElse(() => '')
          : '';

      final systemConfigResult = await getSystemConfigUseCase();
      final systemConfig = systemConfigResult.getOrElse(
        () => SystemConfig.empty(),
      );

      startTranslationUseCase(
        sourceLang: state.activeSourceLang,
        targetLang: state.activeTargetLang,
        useMic: state.activeUseMic,
        inputDeviceIndex: state.activeInputDeviceIndex,
        outputDeviceIndex: state.activeOutputDeviceIndex,
        translationModel: state.activeTranslationModel,
        nvidiaNimKey: state.activeNvidiaNimKey,
        googleCredentials: googleCredentials,
        transcriptionModel: state.activeTranscriptionModel,
        rivaTranslationFunctionId: systemConfig.rivaTranslationFunctionId,
        rivaAsrParakeetFunctionId: systemConfig.rivaAsrParakeetFunctionId,
        rivaAsrCanaryFunctionId: systemConfig.rivaAsrCanaryFunctionId,
        quotaDailyUsed: state.quotaStatus?.dailyTokensUsed ?? 0,
        quotaDailyLimit: state.quotaStatus?.dailyLimit ?? -1,
      );
      final newState = state.copyWith(isRunning: true);
      emit(newState);
    }
  }

  Future<void> _onUpdateQuota(
    UpdateQuotaEvent event,
    Emitter<TranslationState> emit,
  ) async {
    if (event.status == null) return;

    final bool exceeded = event.status!.isExceeded;
    final String? oldTier = state.quotaStatus?.tier;
    final String newTier = event.status!.tier;

    final newState = state.copyWith(
      quotaStatus: event.status,
      isQuotaExceeded: exceeded,
    );
    if (newState != state) {
      AppLogger.i(
        '_onUpdateQuota: emitted state with tier $newTier, exceeded: $exceeded',
        tag: 'TranslationBloc',
      );
    }
    emit(newState);

    // Handle Quota Exhaustion
    if (exceeded && state.isRunning) {
      AppLogger.w(
        'Quota exceeded, stopping translation.',
        tag: 'TranslationBloc',
      );
      unawaited(stopTranslationUseCase());
      emit(
        state.copyWith(
          isRunning: false,
          navToSubscriptionTrigger: state.navToSubscriptionTrigger + 1,
        ),
      );
      add(QuotaExceededEvent());
      return;
    }

    // Handle Tier Change (Downgrade)
    if (oldTier != null && oldTier != newTier) {
      AppLogger.i(
        'Tier changed from $oldTier to $newTier',
        tag: 'TranslationBloc',
      );

      final bool isTranslationAllowed = checkModelAccessUseCase
          .isTranslationModelAllowed(state.activeTranslationModel, newTier);
      final bool isTranscriptionAllowed = checkModelAccessUseCase
          .isTranscriptionModelAllowed(state.activeTranscriptionModel, newTier);

      if (!isTranslationAllowed || !isTranscriptionAllowed) {
        if (state.isRunning) {
          await stopTranslationUseCase();
        }

        try {
          await unloadModelUseCase();
        } catch (e) {
          AppLogger.e(
            'Error unloading model',
            error: e,
            tag: 'TranslationBloc',
          );
        }

        // Clear model statuses for the unsupported models to update UI immediately
        final updatedStatuses = Map<String, dynamic>.from(state.modelStatuses);
        if (!isTranslationAllowed) {
          updatedStatuses.remove(state.activeTranslationModelStatusKey);
        }
        if (!isTranscriptionAllowed) {
          updatedStatuses.remove(state.activeTranscriptionModelStatusKey);
        }

        final defaults = AppSettings.initial();
        final newState = state.copyWith(
          isRunning: false,
          modelStatuses: updatedStatuses,
          activeTranslationModel: isTranslationAllowed
              ? state.activeTranslationModel
              : defaults.translationModel,
          activeTranscriptionModel: isTranscriptionAllowed
              ? state.activeTranscriptionModel
              : defaults.transcriptionModel,
        );
        emit(newState);

        // Immediately apply and persist the new default models to avoid race conditions
        add(
          ApplySettingsEvent(
            targetLang: state.activeTargetLang,
            sourceLang: state.activeSourceLang,
            useMic: state.activeUseMic,
            fontSize: state.activeFontSize,
            isBold: state.activeIsBold,
            opacity: state.activeOpacity,
            inputDeviceIndex: state.activeInputDeviceIndex,
            outputDeviceIndex: state.activeOutputDeviceIndex,
            desktopVolume: state.activeDesktopVolume,
            micVolume: state.activeMicVolume,
            translationModel: newState.activeTranslationModel,
            nvidiaNimKey: state.activeNvidiaNimKey,
            transcriptionModel: newState.activeTranscriptionModel,
          ),
        );
      }
    }
  }

  void _onQuotaExceeded(
    QuotaExceededEvent event,
    Emitter<TranslationState> emit,
  ) {
    // Handled by UI layers/listeners
  }

  // ── Per-Engine Limit Handlers ─────────────────────────────────────────────

  void _onEngineLimitReached(
    EngineLimitReachedEvent event,
    Emitter<TranslationState> emit,
  ) {
    final shouldShowDialog = checkEngineLimitUseCase.shouldShowNotice(
      event.engineId,
    );

    if (shouldShowDialog) {
      // First time this engine is exceeded in this session → show dialog
      AppLogger.i(
        'Engine "${event.engineId}" limit reached (first time), showing dialog.',
        tag: 'TranslationBloc',
      );
      if (state.isRunning) {
        stopTranslationUseCase();
      }
      emit(
        state.copyWith(isRunning: false, engineLimitReachedFor: event.engineId),
      );
    } else {
      // Repeat occurrence → silent fallback to google
      AppLogger.i(
        'Engine "${event.engineId}" limit reached again, silent fallback to google.',
        tag: 'TranslationBloc',
      );
      add(SwitchToFallbackEngineEvent());
    }
  }

  Future<void> _onRequestModelUnload(
    RequestModelUnloadEvent event,
    Emitter<TranslationState> emit,
  ) async {
    try {
      await unloadModelUseCase();
    } catch (e) {
      AppLogger.e('Error unloading model', error: e, tag: 'TranslationBloc');
    }
  }

  void _onSwitchToFallbackEngine(
    SwitchToFallbackEngineEvent event,
    Emitter<TranslationState> emit,
  ) {
    emit(
      state.copyWith(
        activeTranslationModel: 'google',
        engineLimitReachedFor: null,
        isUsingFallbackEngine: true,
      ),
    );
    // Re-apply settings with the fallback engine
    add(
      ApplySettingsEvent(
        targetLang: state.activeTargetLang,
        sourceLang: state.activeSourceLang,
        useMic: state.activeUseMic,
        fontSize: state.activeFontSize,
        isBold: state.activeIsBold,
        opacity: state.activeOpacity,
        inputDeviceIndex: state.activeInputDeviceIndex,
        outputDeviceIndex: state.activeOutputDeviceIndex,
        desktopVolume: state.activeDesktopVolume,
        micVolume: state.activeMicVolume,
        translationModel: 'google',
        nvidiaNimKey: state.activeNvidiaNimKey,
        transcriptionModel: state.activeTranscriptionModel,
      ),
    );
  }

  void _onLangError(LangErrorEvent event, Emitter<TranslationState> emit) {
    emit(state.copyWith(autoDetectWarning: event.message));
    emit(state.copyWith(autoDetectWarning: null));
  }

  void _onResetSettings(
    ResetSettingsEvent event,
    Emitter<TranslationState> emit,
  ) {
    emit(TranslationState.initial());
  }

  Future<void> _onLoadSettings(
    LoadSettingsEvent event,
    Emitter<TranslationState> emit,
  ) async {
    final loadingState = state.copyWith(isSettingsLoading: true);
    emit(loadingState);
    try {
      final result = await getAppSettingsUseCase();
      result.fold(
        (failure) => AppLogger.e(
          'Error loading settings',
          error: failure.message,
          tag: 'TranslationBloc',
        ),
        (settings) async {
          if (settings != null) {
            final loadedState = state.copyWith(
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
              activeNvidiaNimKey: settings.nvidiaNimKey,
              activeTranscriptionModel: settings.transcriptionModel,
            );
            emit(loadedState);

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
                nvidiaNimKey: settings.nvidiaNimKey,
                transcriptionModel: settings.transcriptionModel,
              ),
            );
          } else {
            final defaults = AppSettings.initial();
            final defaultState = state.copyWith(
              activeTargetLang: defaults.targetLang,
              activeSourceLang: defaults.sourceLang,
              activeUseMic: defaults.useMic,
              activeFontSize: defaults.fontSize,
              activeIsBold: defaults.isBold,
              activeOpacity: defaults.opacity,
              activeInputDeviceIndex: defaults.inputDeviceIndex,
              activeOutputDeviceIndex: defaults.outputDeviceIndex,
              activeDesktopVolume: defaults.desktopVolume,
              activeMicVolume: defaults.micVolume,
              activeTranslationModel: defaults.translationModel,
              activeNvidiaNimKey: defaults.nvidiaNimKey,
              activeTranscriptionModel: defaults.transcriptionModel,
            );
            if (defaultState != state) {
              AppLogger.i(
                '_onLoadSettings: emitted state with default settings',
                tag: 'TranslationBloc',
              );
            }
            emit(defaultState);
          }
        },
      );
    } catch (e) {
      AppLogger.e('Error loading settings', error: e, tag: 'TranslationBloc');
    } finally {
      final finishedState = state.copyWith(isSettingsLoading: false);
      emit(finishedState);
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
    final wasRunning = state.isRunning;
    final previousNimKey = state.activeNvidiaNimKey;

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
        activeNvidiaNimKey: event.nvidiaNimKey,
        activeTranscriptionModel: event.transcriptionModel,
        isSettingsSaving: event.isUserInitiated,
      ),
    );

    if (state.isShrunk) {
      double shrinkHeight = event.fontSize * 3 + 30;
      if (shrinkHeight < 70) shrinkHeight = 70;
      await windowManager.setSize(Size(730, shrinkHeight));
    }

    try {
      final result = await getGoogleCredentialsUseCase();
      final googleCredentialsOnApply = event.translationModel == 'google_api'
          ? result.getOrElse(() => '')
          : '';

      // Only pass the NIM key when an NVIDIA model is actually selected
      // (either NIM translation or Riva ASR transcription).
      // Sending it unconditionally causes the backend to validate the key
      // on every settings update, including at startup.
      final needsNimKey = event.translationModel == 'nvidia-nim' ||
          event.transcriptionModel == 'riva-asr';
      final nimKeyOnApply = needsNimKey ? event.nvidiaNimKey : '';

      final systemConfigResult = await getSystemConfigUseCase();
      final systemConfig = systemConfigResult.getOrElse(
        () => SystemConfig.empty(),
      );

      updateTranslationSettingsUseCase(
        targetLang: event.targetLang,
        sourceLang: event.sourceLang,
        useMic: event.useMic,
        inputDeviceIndex: event.inputDeviceIndex,
        outputDeviceIndex: event.outputDeviceIndex,
        desktopVolume: event.desktopVolume,
        micVolume: event.micVolume,
        translationModel: event.translationModel,
        nvidiaNimKey: nimKeyOnApply,
        googleCredentials: googleCredentialsOnApply,
        transcriptionModel: event.transcriptionModel,
        rivaTranslationFunctionId: systemConfig.rivaTranslationFunctionId,
        rivaAsrParakeetFunctionId: systemConfig.rivaAsrParakeetFunctionId,
        rivaAsrCanaryFunctionId: systemConfig.rivaAsrCanaryFunctionId,
      );

      await syncSettingsUseCase({
        'targetLang': event.targetLang,
        'sourceLang': event.sourceLang,
        'useMic': event.useMic,
        'fontSize': event.fontSize,
        'isBold': event.isBold,
        'opacity': event.opacity,
        'translationModel': event.translationModel,
        'nvidiaNimKey': event.nvidiaNimKey,
        'transcriptionModel': event.transcriptionModel,
      });

      // If the NIM key was entered or changed while translation is running,
      // the backend needs a full stop+start to reinitialize the NIM client.
      final nimKeyChanged = nimKeyOnApply.isNotEmpty &&
          nimKeyOnApply != previousNimKey;
      if (nimKeyChanged && wasRunning) {
        unawaited(stopTranslationUseCase());
        startTranslationUseCase(
          sourceLang: event.sourceLang,
          targetLang: event.targetLang,
          useMic: event.useMic,
          inputDeviceIndex: event.inputDeviceIndex,
          outputDeviceIndex: event.outputDeviceIndex,
          translationModel: event.translationModel,
          nvidiaNimKey: nimKeyOnApply,
          googleCredentials: googleCredentialsOnApply,
          transcriptionModel: event.transcriptionModel,
          rivaTranslationFunctionId: systemConfig.rivaTranslationFunctionId,
          rivaAsrParakeetFunctionId: systemConfig.rivaAsrParakeetFunctionId,
          rivaAsrCanaryFunctionId: systemConfig.rivaAsrCanaryFunctionId,
          quotaDailyUsed: state.quotaStatus?.dailyTokensUsed ?? 0,
          quotaDailyLimit: state.quotaStatus?.dailyLimit ?? -1,
        );
      }
    } finally {
      emit(state.copyWith(isSettingsSaving: false));
    }
  }

  void _onUpdateServerConnection(
    UpdateServerConnectionEvent event,
    Emitter<TranslationState> emit,
  ) {
    if (event.isConnected) {
      emit(state.copyWith(isServerConnected: true));
      _stopHealthCheck();
      _fetchInitialModelStatuses(); // Refresh statuses on reconnect
    } else {
      emit(
        state.copyWith(
          isServerConnected: false,
          modelStatuses: {}, // Clear statuses when disconnected
        ),
      );
      _startHealthCheck();
    }
  }

  void _startHealthCheck() {
    if (_healthCheckTimer != null) return;
    // Check immediately, then every 3s — avoids waiting up to 5s after a
    // settings-update-triggered backend reload which typically takes 2-5s.
    _checkHealthOnce();
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 3), (
      timer,
    ) async {
      await _checkHealthOnce();
    });
  }

  Future<void> _checkHealthOnce() async {
    final isHealthy = await checkServerHealthUseCase();
    if (isClosed) return;
    if (isHealthy) {
      add(const UpdateServerConnectionEvent(isConnected: true));
    } else {
      // Server is not responding — attempt to restart the bundled process.
      // PythonServerManager guards against concurrent/redundant starts internally.
      unawaited(PythonServerManager.startServer());
    }
  }

  void _stopHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
  }

  @override
  Future<void> close() {
    _stopHealthCheck();
    getCurrentUserUseCase().removeListener(_onAuthChanged);
    _captionSub?.cancel();
    _statusSub?.cancel();
    stopTranslationUseCase();
    return super.close();
  }
}
