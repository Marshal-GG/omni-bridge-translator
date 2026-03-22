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
  final String activeApiKey;
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
    this.activeApiKey = '',
    this.activeTranscriptionModel = 'online',
    this.autoDetectWarning,
    this.quotaStatus,
    this.isQuotaExceeded = false,
    this.isSettingsLoading = false,
    this.isSettingsSaving = false,
    this.navToSubscriptionTrigger = 0,
    this.modelStatuses = const {},
  });

  factory TranslationState.initial() {
    return const TranslationState(
      isShrunk: false,
      isRunning: true,
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
      activeApiKey: '',
      activeTranscriptionModel: 'online',
      autoDetectWarning: null,
      quotaStatus: null,
      isQuotaExceeded: false,
      isSettingsLoading: false,
      isSettingsSaving: false,
      navToSubscriptionTrigger: 0,
      modelStatuses: {},
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
    String? activeApiKey,
    String? activeTranscriptionModel,
    Object? autoDetectWarning = _sentinel,
    SubscriptionStatus? quotaStatus,
    bool? isQuotaExceeded,
    bool? isSettingsLoading,
    bool? isSettingsSaving,
    int? navToSubscriptionTrigger,
    Map<String, dynamic>? modelStatuses,
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
      activeApiKey: activeApiKey ?? this.activeApiKey,
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
    activeApiKey,
    activeTranscriptionModel,
    autoDetectWarning,
    quotaStatus,
    isQuotaExceeded,
    isSettingsLoading,
    isSettingsSaving,
    navToSubscriptionTrigger,
    modelStatuses,
  ];

  String get activeTranslationModelStatusKey {
    return {
          'google': 'google_translate',
          'google_api': 'google_api',
          'mymemory': 'mymemory',
          'riva': 'riva-nmt',
          'llama': 'llama',
        }[activeTranslationModel] ??
        activeTranslationModel;
  }

  String get activeTranscriptionModelStatusKey {
    if (activeTranscriptionModel == 'online') return 'google_asr';
    if (activeTranscriptionModel == 'riva') return 'riva-asr';
    return activeTranscriptionModel;
  }
}

// Sentinel to distinguish 'not passed' from explicit null in copyWith
const Object _sentinel = Object();
