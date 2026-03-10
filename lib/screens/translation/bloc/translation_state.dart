import 'package:equatable/equatable.dart';
import '../../../core/services/firebase/subscription_service.dart';

class TranslationState extends Equatable {
  // App UI State
  final bool isShrunk;
  final bool isRunning;
  final SubscriptionStatus? quotaStatus;
  final bool isQuotaExceeded;

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
    this.navToSubscriptionTrigger = 0,
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
      navToSubscriptionTrigger: 0,
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
    int? navToSubscriptionTrigger,
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
      navToSubscriptionTrigger:
          navToSubscriptionTrigger ?? this.navToSubscriptionTrigger,
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
    navToSubscriptionTrigger,
  ];
}

// Sentinel to distinguish 'not passed' from explicit null in copyWith
const Object _sentinel = Object();
