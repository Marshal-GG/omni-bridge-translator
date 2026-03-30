import 'package:equatable/equatable.dart';
import 'package:omni_bridge/features/subscription/data/models/subscription_dto.dart';

class TranslationState extends Equatable {
  // App UI State
  final bool isShrunk;
  final bool isRunning;
  final SubscriptionStatus? quotaStatus;
  final bool isQuotaExceeded;
  final bool isSettingsLoading;
  final bool isSettingsSaving;
  final bool isServerConnected;

  // Per-engine limit state (hybrid fallback)
  /// Non-null when a specific engine's monthly limit was just hit (show dialog).
  final String? engineLimitReachedFor;
  /// True when translation is using a fallback engine due to model limit.
  final bool isUsingFallbackEngine;

  // Active Settings (Applied to WebSocket)
  final String activeTargetLang;
  final String activeSourceLang;
  final bool activeUseMic;
  final double activeFontSize;
  final bool activeIsBold;
  final double activeOpacity;
  final int? activeInputDeviceIndex;
  final int? activeOutputDeviceIndex;
  final double activeDesktopVolume;
  final double activeMicVolume;
  final String activeTranslationModel;
  final String activeNvidiaNimKey;
  final String activeTranscriptionModel;

  // Auto-detect warning – set when server overrides 'auto' with a detected lang
  final String? autoDetectWarning;

  final int navToSubscriptionTrigger;
  final Map<String, dynamic> modelStatuses;

  const TranslationState({
    required this.isShrunk,
    required this.isRunning,
    required this.activeTargetLang,
    required this.activeSourceLang,
    required this.activeUseMic,
    required this.activeFontSize,
    required this.activeIsBold,
    required this.activeOpacity,
    this.activeInputDeviceIndex,
    this.activeOutputDeviceIndex,
    required this.activeDesktopVolume,
    required this.activeMicVolume,
    required this.activeTranslationModel,
    this.activeNvidiaNimKey = '',
    this.activeTranscriptionModel = 'online',
    this.autoDetectWarning,
    this.quotaStatus,
    this.isQuotaExceeded = false,
    this.isSettingsLoading = false,
    this.isSettingsSaving = false,
    this.navToSubscriptionTrigger = 0,
    this.modelStatuses = const {},
    this.isServerConnected = true,
    this.engineLimitReachedFor,
    this.isUsingFallbackEngine = false,
  });

  factory TranslationState.initial() {
    return const TranslationState(
      isShrunk: false,
      isRunning: false,
      // Active
      activeTargetLang: 'en',
      activeSourceLang: 'auto',
      activeUseMic: false,
      activeFontSize: 18.0,
      activeIsBold: false,
      activeOpacity: 0.85,
      activeInputDeviceIndex: null,
      activeOutputDeviceIndex: null,
      activeDesktopVolume: 1.0,
      activeMicVolume: 1.0,
      activeTranslationModel: 'google',
      activeNvidiaNimKey: '',
      activeTranscriptionModel: 'online',
      autoDetectWarning: null,
      quotaStatus: null,
      isQuotaExceeded: false,
      isSettingsLoading: false,
      isSettingsSaving: false,
      navToSubscriptionTrigger: 0,
      modelStatuses: {},
      isServerConnected: true,
      engineLimitReachedFor: null,
      isUsingFallbackEngine: false,
    );
  }

  TranslationState copyWith({
    bool? isShrunk,
    bool? isRunning,
    String? activeTargetLang,
    String? activeSourceLang,
    bool? activeUseMic,
    double? activeFontSize,
    bool? activeIsBold,
    double? activeOpacity,
    int? activeInputDeviceIndex,
    int? activeOutputDeviceIndex,
    double? activeDesktopVolume,
    double? activeMicVolume,
    String? activeTranslationModel,
    String? activeNvidiaNimKey,
    String? activeTranscriptionModel,
    Object? autoDetectWarning = _sentinel,
    SubscriptionStatus? quotaStatus,
    bool? isQuotaExceeded,
    bool? isSettingsLoading,
    bool? isSettingsSaving,
    int? navToSubscriptionTrigger,
    Map<String, dynamic>? modelStatuses,
    bool? isServerConnected,
    Object? engineLimitReachedFor = _sentinel,
    bool? isUsingFallbackEngine,
  }) {
    return TranslationState(
      isShrunk: isShrunk ?? this.isShrunk,
      isRunning: isRunning ?? this.isRunning,
      activeTargetLang: activeTargetLang ?? this.activeTargetLang,
      activeSourceLang: activeSourceLang ?? this.activeSourceLang,
      activeUseMic: activeUseMic ?? this.activeUseMic,
      activeFontSize: activeFontSize ?? this.activeFontSize,
      activeIsBold: activeIsBold ?? this.activeIsBold,
      activeOpacity: activeOpacity ?? this.activeOpacity,
      activeInputDeviceIndex:
          activeInputDeviceIndex ?? this.activeInputDeviceIndex,
      activeOutputDeviceIndex:
          activeOutputDeviceIndex ?? this.activeOutputDeviceIndex,
      activeDesktopVolume: activeDesktopVolume ?? this.activeDesktopVolume,
      activeMicVolume: activeMicVolume ?? this.activeMicVolume,
      activeTranslationModel:
          activeTranslationModel ?? this.activeTranslationModel,
      activeNvidiaNimKey: activeNvidiaNimKey ?? this.activeNvidiaNimKey,
      activeTranscriptionModel:
          activeTranscriptionModel ?? this.activeTranscriptionModel,
      autoDetectWarning: autoDetectWarning == _sentinel
          ? this.autoDetectWarning
          : autoDetectWarning as String?,
      quotaStatus: quotaStatus ?? this.quotaStatus,
      isQuotaExceeded: isQuotaExceeded ?? this.isQuotaExceeded,
      isSettingsLoading: isSettingsLoading ?? this.isSettingsLoading,
      isSettingsSaving: isSettingsSaving ?? this.isSettingsSaving,
      navToSubscriptionTrigger:
          navToSubscriptionTrigger ?? this.navToSubscriptionTrigger,
      modelStatuses: modelStatuses ?? this.modelStatuses,
      isServerConnected: isServerConnected ?? this.isServerConnected,
      engineLimitReachedFor: engineLimitReachedFor == _sentinel
          ? this.engineLimitReachedFor
          : engineLimitReachedFor as String?,
      isUsingFallbackEngine: isUsingFallbackEngine ?? this.isUsingFallbackEngine,
    );
  }

  @override
  List<Object?> get props => [
    isShrunk,
    isRunning,
    activeTargetLang,
    activeSourceLang,
    activeUseMic,
    activeFontSize,
    activeIsBold,
    activeOpacity,
    activeInputDeviceIndex,
    activeOutputDeviceIndex,
    activeDesktopVolume,
    activeMicVolume,
    activeTranslationModel,
    activeNvidiaNimKey,
    activeTranscriptionModel,
    autoDetectWarning,
    quotaStatus,
    isQuotaExceeded,
    isSettingsLoading,
    isSettingsSaving,
    navToSubscriptionTrigger,
    modelStatuses,
    isServerConnected,
    engineLimitReachedFor,
    isUsingFallbackEngine,
  ];

  String get activeTranslationModelStatusKey {
    return {
          'google': 'google_translate',
          'google_api': 'google_api',
          'mymemory': 'mymemory',
          'riva-nmt': 'riva-nmt',
          'llama': 'llama',
        }[activeTranslationModel] ??
        activeTranslationModel;
  }

  String get activeTranscriptionModelStatusKey {
    if (activeTranscriptionModel == 'online') return 'google_asr';
    if (activeTranscriptionModel == 'riva-asr') return 'riva-asr';
    return activeTranscriptionModel;
  }
}

// Sentinel to distinguish 'not passed' from explicit null in copyWith
const Object _sentinel = Object();
