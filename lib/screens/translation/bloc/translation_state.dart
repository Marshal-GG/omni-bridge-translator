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

  // Temporary Settings (Pending in Settings Screen)
  final String tempTargetLang;
  final String tempSourceLang;
  final bool tempUseMic;
  final double tempFontSize;
  final bool tempIsBold;
  final double tempOpacity;
  final int? tempInputDeviceIndex;
  final int? tempOutputDeviceIndex;

  // Device Info
  final bool devicesLoading;
  final List<Map<String, dynamic>> inputDevices;
  final List<Map<String, dynamic>> outputDevices;
  final String defaultInputDeviceName;
  final String defaultOutputDeviceName;

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
    required this.tempTargetLang,
    required this.tempSourceLang,
    required this.tempUseMic,
    required this.tempFontSize,
    required this.tempIsBold,
    required this.tempOpacity,
    this.tempInputDeviceIndex,
    this.tempOutputDeviceIndex,
    required this.devicesLoading,
    required this.inputDevices,
    required this.outputDevices,
    required this.defaultInputDeviceName,
    required this.defaultOutputDeviceName,
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
      // Temp
      tempTargetLang: 'en',
      tempSourceLang: 'auto',
      tempUseMic: false,
      tempFontSize: 18.0,
      tempIsBold: false,
      tempOpacity: 0.7,
      tempInputDeviceIndex: null,
      tempOutputDeviceIndex: null,
      // Devices
      devicesLoading: false,
      inputDevices: [],
      outputDevices: [],
      defaultInputDeviceName: 'Default',
      defaultOutputDeviceName: 'Default',
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
    String? tempTargetLang,
    String? tempSourceLang,
    bool? tempUseMic,
    double? tempFontSize,
    bool? tempIsBold,
    double? tempOpacity,
    int? tempInputDeviceIndex,
    int? tempOutputDeviceIndex,
    bool? devicesLoading,
    List<Map<String, dynamic>>? inputDevices,
    List<Map<String, dynamic>>? outputDevices,
    String? defaultInputDeviceName,
    String? defaultOutputDeviceName,
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
      tempTargetLang: tempTargetLang ?? this.tempTargetLang,
      tempSourceLang: tempSourceLang ?? this.tempSourceLang,
      tempUseMic: tempUseMic ?? this.tempUseMic,
      tempFontSize: tempFontSize ?? this.tempFontSize,
      tempIsBold: tempIsBold ?? this.tempIsBold,
      tempOpacity: tempOpacity ?? this.tempOpacity,
      tempInputDeviceIndex: tempInputDeviceIndex ?? this.tempInputDeviceIndex,
      tempOutputDeviceIndex:
          tempOutputDeviceIndex ?? this.tempOutputDeviceIndex,
      devicesLoading: devicesLoading ?? this.devicesLoading,
      inputDevices: inputDevices ?? this.inputDevices,
      outputDevices: outputDevices ?? this.outputDevices,
      defaultInputDeviceName:
          defaultInputDeviceName ?? this.defaultInputDeviceName,
      defaultOutputDeviceName:
          defaultOutputDeviceName ?? this.defaultOutputDeviceName,
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
    tempTargetLang,
    tempSourceLang,
    tempUseMic,
    tempFontSize,
    tempIsBold,
    tempOpacity,
    tempInputDeviceIndex,
    tempOutputDeviceIndex,
    devicesLoading,
    inputDevices,
    outputDevices,
    defaultInputDeviceName,
    defaultOutputDeviceName,
  ];
}
