import 'package:equatable/equatable.dart';

class TranslationState extends Equatable {
  // App UI State
  final bool isSettingsOpen;
  final bool isShrunk;

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

  // Auto-detect warning – set when server overrides 'auto' with a detected lang
  final String? autoDetectWarning;

  const TranslationState({
    required this.isSettingsOpen,
    required this.isShrunk,
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
    this.autoDetectWarning,
  });

  factory TranslationState.initial() {
    return const TranslationState(
      isSettingsOpen: false,
      isShrunk: false,
      // Active
      activeTargetLang: 'en',
      activeSourceLang: 'auto',
      activeUseMic: false,
      activeFontSize: 18.0,
      activeIsBold: false,
      activeOpacity: 0.7,
      activeInputDeviceIndex: null,
      activeOutputDeviceIndex: null,
      activeDesktopVolume: 1.0,
      activeMicVolume: 1.0,
      autoDetectWarning: null,
    );
  }

  TranslationState copyWith({
    bool? isSettingsOpen,
    bool? isShrunk,
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
    Object? autoDetectWarning = _sentinel,
  }) {
    return TranslationState(
      isSettingsOpen: isSettingsOpen ?? this.isSettingsOpen,
      isShrunk: isShrunk ?? this.isShrunk,
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
      autoDetectWarning: autoDetectWarning == _sentinel
          ? this.autoDetectWarning
          : autoDetectWarning as String?,
    );
  }

  @override
  List<Object?> get props => [
    isSettingsOpen,
    isShrunk,
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
    autoDetectWarning,
  ];
}

// Sentinel to distinguish 'not passed' from explicit null in copyWith
const Object _sentinel = Object();
