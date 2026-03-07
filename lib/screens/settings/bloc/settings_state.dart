import 'package:equatable/equatable.dart';

class SettingsState extends Equatable {
  // Temporary Settings (Pending in Settings Screen)
  final String tempTargetLang;
  final String tempSourceLang;
  final bool tempUseMic;
  final double tempFontSize;
  final bool tempIsBold;
  final double tempOpacity;
  final int? tempInputDeviceIndex;
  final int? tempOutputDeviceIndex;
  final double tempDesktopVolume;
  final double tempMicVolume;
  final String tempTranslationModel;
  final String tempApiKey;
  final String tempTranscriptionModel;

  // Audio Levels (live during settings open)
  final double currentInputVolume;
  final double currentOutputVolume;

  // Devices Loading
  final bool devicesLoading;
  final List<Map<String, dynamic>> inputDevices;
  final List<Map<String, dynamic>> outputDevices;
  final String defaultInputDeviceName;
  final String defaultOutputDeviceName;

  const SettingsState({
    required this.tempTargetLang,
    required this.tempSourceLang,
    required this.tempUseMic,
    required this.tempFontSize,
    required this.tempIsBold,
    required this.tempOpacity,
    this.tempInputDeviceIndex,
    this.tempOutputDeviceIndex,
    required this.tempDesktopVolume,
    required this.tempMicVolume,
    required this.tempTranslationModel,
    required this.tempApiKey,
    required this.tempTranscriptionModel,
    required this.currentInputVolume,
    required this.currentOutputVolume,
    required this.devicesLoading,
    required this.inputDevices,
    required this.outputDevices,
    required this.defaultInputDeviceName,
    required this.defaultOutputDeviceName,
  });

  factory SettingsState.initial() {
    return const SettingsState(
      tempTargetLang: 'en',
      tempSourceLang: 'auto',
      tempUseMic: false,
      tempFontSize: 18.0,
      tempIsBold: false,
      tempOpacity: 0.85,
      tempInputDeviceIndex: null,
      tempOutputDeviceIndex: null,
      tempDesktopVolume: 1.0,
      tempMicVolume: 1.0,
      tempTranslationModel: 'google',
      tempApiKey: '',
      tempTranscriptionModel: 'online',
      currentInputVolume: 0.0,
      currentOutputVolume: 0.0,
      devicesLoading: false,
      inputDevices: [],
      outputDevices: [],
      defaultInputDeviceName: 'Default',
      defaultOutputDeviceName: 'Default',
    );
  }

  SettingsState copyWith({
    String? tempTargetLang,
    String? tempSourceLang,
    bool? tempUseMic,
    double? tempFontSize,
    bool? tempIsBold,
    double? tempOpacity,
    int? tempInputDeviceIndex,
    int? tempOutputDeviceIndex,
    double? tempDesktopVolume,
    double? tempMicVolume,
    String? tempTranslationModel,
    String? tempApiKey,
    String? tempTranscriptionModel,
    double? currentInputVolume,
    double? currentOutputVolume,
    bool? devicesLoading,
    List<Map<String, dynamic>>? inputDevices,
    List<Map<String, dynamic>>? outputDevices,
    String? defaultInputDeviceName,
    String? defaultOutputDeviceName,
  }) {
    return SettingsState(
      tempTargetLang: tempTargetLang ?? this.tempTargetLang,
      tempSourceLang: tempSourceLang ?? this.tempSourceLang,
      tempUseMic: tempUseMic ?? this.tempUseMic,
      tempFontSize: tempFontSize ?? this.tempFontSize,
      tempIsBold: tempIsBold ?? this.tempIsBold,
      tempOpacity: tempOpacity ?? this.tempOpacity,
      tempInputDeviceIndex: tempInputDeviceIndex ?? this.tempInputDeviceIndex,
      tempOutputDeviceIndex:
          tempOutputDeviceIndex ?? this.tempOutputDeviceIndex,
      tempDesktopVolume: tempDesktopVolume ?? this.tempDesktopVolume,
      tempMicVolume: tempMicVolume ?? this.tempMicVolume,
      tempTranslationModel: tempTranslationModel ?? this.tempTranslationModel,
      tempApiKey: tempApiKey ?? this.tempApiKey,
      tempTranscriptionModel:
          tempTranscriptionModel ?? this.tempTranscriptionModel,
      currentInputVolume: currentInputVolume ?? this.currentInputVolume,
      currentOutputVolume: currentOutputVolume ?? this.currentOutputVolume,
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
    tempTargetLang,
    tempSourceLang,
    tempUseMic,
    tempFontSize,
    tempIsBold,
    tempOpacity,
    tempInputDeviceIndex,
    tempOutputDeviceIndex,
    tempDesktopVolume,
    tempMicVolume,
    tempTranslationModel,
    tempApiKey,
    tempTranscriptionModel,
    currentInputVolume,
    currentOutputVolume,
    devicesLoading,
    inputDevices,
    outputDevices,
    defaultInputDeviceName,
    defaultOutputDeviceName,
  ];
}
