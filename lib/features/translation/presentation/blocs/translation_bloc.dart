import 'dart:async';
import 'package:flutter/material.dart';
import 'package:omni_bridge/features/subscription/data/models/subscription_dto.dart';
import 'package:omni_bridge/features/subscription/data/datasources/subscription_remote_datasource.dart';
import 'package:omni_bridge/features/translation/data/datasources/translation_rest_datasource.dart';
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
import 'package:omni_bridge/features/translation/domain/usecases/check_server_health_usecase.dart';
import 'package:omni_bridge/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:omni_bridge/features/auth/domain/usecases/observe_auth_changes_usecase.dart';
import 'package:omni_bridge/features/settings/domain/entities/app_settings.dart';
import 'package:omni_bridge/features/settings/domain/usecases/get_app_settings_usecase.dart';
import 'package:omni_bridge/features/settings/domain/usecases/get_google_credentials_usecase.dart';
import 'package:omni_bridge/features/settings/domain/usecases/sync_settings_usecase.dart';
import 'package:omni_bridge/features/settings/domain/usecases/log_event_usecase.dart';
import 'package:omni_bridge/features/auth/domain/usecases/logout_usecase.dart';
import 'package:omni_bridge/features/settings/domain/usecases/get_system_config_usecase.dart';
import 'package:omni_bridge/features/settings/domain/entities/system_config.dart';

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
  final CheckServerHealthUseCase checkServerHealthUseCase;
  final GetCurrentUserUseCase getCurrentUserUseCase;
  final ObserveAuthChangesUseCase observeAuthChangesUseCase;
  final GetAppSettingsUseCase getAppSettingsUseCase;
  final GetGoogleCredentialsUseCase getGoogleCredentialsUseCase;
  final SyncSettingsUseCase syncSettingsUseCase;
  final LogEventUseCase logEventUseCase;
  final LogoutUseCase logoutUseCase;
  final GetSystemConfigUseCase getSystemConfigUseCase;
  final SubscriptionRemoteDataSource subscriptionDataSource;
  final TranslationRestDatasource translationRestDatasource;

  StreamSubscription? _captionSub;
  StreamSubscription? _statusSub;
  Timer? _healthCheckTimer;
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
    required this.checkServerHealthUseCase,
    required this.getCurrentUserUseCase,
    required this.observeAuthChangesUseCase,
    required this.getAppSettingsUseCase,
    required this.getGoogleCredentialsUseCase,
    required this.syncSettingsUseCase,
    required this.logEventUseCase,
    required this.logoutUseCase,
    required this.getSystemConfigUseCase,
    required this.subscriptionDataSource,
    required this.translationRestDatasource,
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
    on<ResetSettingsEvent>(_onResetSettings);
    on<LangErrorEvent>(_onLangError);
    on<UpdateServerConnectionEvent>(_onUpdateServerConnection);
    on<EngineLimitReachedEvent>(_onEngineLimitReached);
    on<SwitchToFallbackEngineEvent>(_onSwitchToFallbackEngine);

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
    final user = getCurrentUserUseCase().value;
    if (user != null && !isClosed) {
      debugPrint('[TranslationBloc] Auth detected, reloading settings...');
      add(LoadSettingsEvent());
    } else if (user == null && !isClosed) {
      debugPrint('[TranslationBloc] Logout detected, resetting settings...');
      add(ResetSettingsEvent());
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
    _captionSub = observeCaptionsUseCase()?.listen((msg) {
      if (msg.isDisconnect) {
        if (!isClosed) {
          add(UpdateServerConnectionEvent(isConnected: false));
        }
        if (state.isRunning && !isClosed) {
          debugPrint('[TranslationBloc] Server disconnect detected. Auto-pausing.');
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
    final newState = state.copyWith(modelStatuses: newStatuses);
    emit(newState);
  }

  Future<void> _onToggleRunning(
    ToggleRunningEvent event,
    Emitter<TranslationState> emit,
  ) async {
    // Prevent starting translation if server is not connected
    if (!state.isRunning && !state.isServerConnected) {
      debugPrint('[TranslationBloc] Prevented resume: Server is not connected.');
      return;
    }

    if (state.isRunning) {
      stopTranslationUseCase();
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
      final systemConfig = systemConfigResult.getOrElse(() => SystemConfig.empty());

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
      );
      final newState = state.copyWith(isRunning: true);
      emit(newState);
    }
  }

  Future<void> _onUpdateQuota(UpdateQuotaEvent event, Emitter<TranslationState> emit) async {
    if (event.status == null) return;

    final bool exceeded = event.status!.isExceeded;
    final String? oldTier = state.quotaStatus?.tier;
    final String newTier = event.status!.tier;

    final newState = state.copyWith(quotaStatus: event.status, isQuotaExceeded: exceeded);
    if (newState != state) {
      debugPrint('[DEBUG-EMIT] _onUpdateQuota: emitted state with tier $newTier, exceeded: $exceeded');
    }
    emit(newState);

    // Handle Quota Exhaustion
    if (exceeded && state.isRunning) {
      debugPrint('[TranslationBloc] Quota exceeded, stopping translation.');
      stopTranslationUseCase();
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
      debugPrint('[TranslationBloc] Tier changed from $oldTier to $newTier');

      final bool isTranslationAllowed = subscriptionDataSource
          .allowedTranslationModels(newTier)
          .contains(state.activeTranslationModel);
      final bool isTranscriptionAllowed = subscriptionDataSource
          .allowedTranscriptionModels(newTier)
          .contains(state.activeTranscriptionModel);

      if (!isTranslationAllowed || !isTranscriptionAllowed) {
        if (state.isRunning) {
          stopTranslationUseCase();
        }

        try {
          await translationRestDatasource.unloadModel();
        } catch (e) {
          debugPrint('[TranslationBloc] Error unloading model: $e');
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
    final shouldShowDialog =
        subscriptionDataSource.shouldShowEngineLimitNotice(event.engineId);

    if (shouldShowDialog) {
      // First time this engine is exceeded in this session → show dialog
      debugPrint(
        '[TranslationBloc] Engine "${event.engineId}" limit reached (first time), showing dialog.',
      );
      if (state.isRunning) {
        stopTranslationUseCase();
      }
      emit(
        state.copyWith(
          isRunning: false,
          engineLimitReachedFor: event.engineId,
        ),
      );
    } else {
      // Repeat occurrence → silent fallback to google
      debugPrint(
        '[TranslationBloc] Engine "${event.engineId}" limit reached again, silent fallback to google.',
      );
      add(SwitchToFallbackEngineEvent());
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
        (failure) => debugPrint('Error loading settings: ${failure.message}'),
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
              debugPrint('[DEBUG-EMIT] _onLoadSettings: emitted state with default settings');
            }
            emit(defaultState);
          }
        },
      );
    } catch (e) {
      debugPrint('Error loading settings: $e');
    } finally {
      final finishedState = state.copyWith(isSettingsLoading: false);
      emit(finishedState);
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
      final googleCredentialsOnApply =
          event.translationModel == 'google_api'
          ? result.getOrElse(() => '')
          : '';

      final systemConfigResult = await getSystemConfigUseCase();
      final systemConfig = systemConfigResult.getOrElse(() => SystemConfig.empty());

      updateTranslationSettingsUseCase(
        targetLang: event.targetLang,
        sourceLang: event.sourceLang,
        useMic: event.useMic,
        inputDeviceIndex: event.inputDeviceIndex,
        outputDeviceIndex: event.outputDeviceIndex,
        desktopVolume: event.desktopVolume,
        micVolume: event.micVolume,
        translationModel: event.translationModel,
        nvidiaNimKey: event.nvidiaNimKey,
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
        'nvidia_nim_key': event.nvidiaNimKey,
        'transcriptionModel': event.transcriptionModel,
      });
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
      emit(state.copyWith(
        isServerConnected: false,
        modelStatuses: {}, // Clear statuses when disconnected
      ));
      _startHealthCheck();
    }
  }

  void _startHealthCheck() {
    if (_healthCheckTimer != null) return;
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      final isHealthy = await checkServerHealthUseCase();
      if (isHealthy && !isClosed) {
        add(const UpdateServerConnectionEvent(isConnected: true));
      }
    });
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
