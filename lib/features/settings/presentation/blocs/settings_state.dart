import 'package:equatable/equatable.dart';

import 'package:omni_bridge/features/settings/domain/entities/app_settings.dart';
import 'package:omni_bridge/features/settings/domain/entities/audio_device.dart';

class SettingsState extends Equatable {
  final AppSettings settings;

  // UI State
  final int activeTabIndex;
  final bool isInitialized;
  final bool isSaving;

  // Snapshot of translation model statuses at settings-open time
  final Map<String, dynamic> modelStatuses;

  // Devices Loading
  final bool devicesLoading;
  final List<AudioDevice> inputDevices;
  final List<AudioDevice> outputDevices;
  final String defaultInputDeviceName;
  final String defaultOutputDeviceName;

  /// Non-null when the selected translation model does not support the
  /// chosen source/target language pair. Blocks saving.
  final String? translationCompatibilityError;

  /// True when the NVIDIA API key is present but failed validation. Blocks saving.
  final bool invalidApiKey;

  const SettingsState({
    required this.settings,
    required this.activeTabIndex,
    required this.isInitialized,
    required this.isSaving,
    required this.modelStatuses,
    required this.devicesLoading,
    required this.inputDevices,
    required this.outputDevices,
    required this.defaultInputDeviceName,
    required this.defaultOutputDeviceName,
    this.translationCompatibilityError,
    this.invalidApiKey = false,
  });

  factory SettingsState.initial() {
    return SettingsState(
      settings: AppSettings.initial(),
      activeTabIndex: 0,
      isInitialized: false,
      isSaving: false,
      modelStatuses: const {},
      devicesLoading: false,
      inputDevices: const [],
      outputDevices: const [],
      defaultInputDeviceName: 'Default',
      defaultOutputDeviceName: 'Default',
    );
  }

  SettingsState copyWith({
    AppSettings? settings,
    int? activeTabIndex,
    bool? isInitialized,
    bool? isSaving,
    Map<String, dynamic>? modelStatuses,
    bool? devicesLoading,
    List<AudioDevice>? inputDevices,
    List<AudioDevice>? outputDevices,
    String? defaultInputDeviceName,
    String? defaultOutputDeviceName,
    String? translationCompatibilityError,
    bool clearCompatibilityError = false,
    bool? invalidApiKey,
  }) {
    return SettingsState(
      settings: settings ?? this.settings,
      activeTabIndex: activeTabIndex ?? this.activeTabIndex,
      isInitialized: isInitialized ?? this.isInitialized,
      isSaving: isSaving ?? this.isSaving,
      modelStatuses: modelStatuses ?? this.modelStatuses,
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
      invalidApiKey: invalidApiKey ?? this.invalidApiKey,
    );
  }

  @override
  List<Object?> get props => [
    settings,
    activeTabIndex,
    isInitialized,
    isSaving,
    modelStatuses,
    devicesLoading,
    inputDevices,
    outputDevices,
    defaultInputDeviceName,
    defaultOutputDeviceName,
    translationCompatibilityError,
    invalidApiKey,
  ];
}
