import 'package:equatable/equatable.dart';

import 'package:omni_bridge/features/settings/domain/entities/app_settings.dart';
import 'package:omni_bridge/features/settings/domain/entities/system_config.dart';

class SettingsState extends Equatable {
  final AppSettings settings;
  final SystemConfig systemConfig;

  // UI State
  final int activeTabIndex;
  final bool isInitialized;

  // Devices Loading
  final bool devicesLoading;
  final List<Map<String, dynamic>> inputDevices;
  final List<Map<String, dynamic>> outputDevices;
  final String defaultInputDeviceName;
  final String defaultOutputDeviceName;

  /// Non-null when the selected translation model does not support the
  /// chosen source/target language pair. Blocks saving.
  final String? translationCompatibilityError;

  const SettingsState({
    required this.settings,
    required this.systemConfig,
    required this.activeTabIndex,
    required this.isInitialized,
    required this.devicesLoading,
    required this.inputDevices,
    required this.outputDevices,
    required this.defaultInputDeviceName,
    required this.defaultOutputDeviceName,
    this.translationCompatibilityError,
  });

  factory SettingsState.initial() {
    return SettingsState(
      settings: AppSettings.initial(),
      systemConfig: SystemConfig.initial(),
      activeTabIndex: 0,
      isInitialized: false,
      devicesLoading: false,
      inputDevices: [],
      outputDevices: [],
      defaultInputDeviceName: 'Default',
      defaultOutputDeviceName: 'Default',
    );
  }

  SettingsState copyWith({
    AppSettings? settings,
    SystemConfig? systemConfig,
    int? activeTabIndex,
    bool? isInitialized,
    bool? devicesLoading,
    List<Map<String, dynamic>>? inputDevices,
    List<Map<String, dynamic>>? outputDevices,
    String? defaultInputDeviceName,
    String? defaultOutputDeviceName,
    String? translationCompatibilityError,
    bool clearCompatibilityError = false,
  }) {
    return SettingsState(
      settings: settings ?? this.settings,
      systemConfig: systemConfig ?? this.systemConfig,
      activeTabIndex: activeTabIndex ?? this.activeTabIndex,
      isInitialized: isInitialized ?? this.isInitialized,
      devicesLoading: devicesLoading ?? this.devicesLoading,
      inputDevices: inputDevices ?? this.inputDevices,
      outputDevices: outputDevices ?? this.outputDevices,
      defaultInputDeviceName:
          defaultInputDeviceName ?? this.defaultInputDeviceName,
      defaultOutputDeviceName:
          defaultOutputDeviceName ?? this.defaultOutputDeviceName,
      translationCompatibilityError: clearCompatibilityError
          ? null
          : (translationCompatibilityError ??
                this.translationCompatibilityError),
    );
  }

  @override
  List<Object?> get props => [
    settings,
    systemConfig,
    activeTabIndex,
    isInitialized,
    devicesLoading,
    inputDevices,
    outputDevices,
    defaultInputDeviceName,
    defaultOutputDeviceName,
    translationCompatibilityError,
  ];
}

