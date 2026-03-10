import 'package:equatable/equatable.dart';

import 'package:omni_bridge/models/app_settings.dart';

class SettingsState extends Equatable {
  final AppSettings settings;

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
    required this.settings,
    required this.currentInputVolume,
    required this.currentOutputVolume,
    required this.devicesLoading,
    required this.inputDevices,
    required this.outputDevices,
    required this.defaultInputDeviceName,
    required this.defaultOutputDeviceName,
  });

  factory SettingsState.initial() {
    return SettingsState(
      settings: AppSettings.initial(),
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
    AppSettings? settings,
    double? currentInputVolume,
    double? currentOutputVolume,
    bool? devicesLoading,
    List<Map<String, dynamic>>? inputDevices,
    List<Map<String, dynamic>>? outputDevices,
    String? defaultInputDeviceName,
    String? defaultOutputDeviceName,
  }) {
    return SettingsState(
      settings: settings ?? this.settings,
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
    settings,
    currentInputVolume,
    currentOutputVolume,
    devicesLoading,
    inputDevices,
    outputDevices,
    defaultInputDeviceName,
    defaultOutputDeviceName,
  ];
}
