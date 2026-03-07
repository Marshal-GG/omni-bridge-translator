import 'package:equatable/equatable.dart';

abstract class SettingsEvent extends Equatable {
  const SettingsEvent();
  @override
  List<Object?> get props => [];
}

class UpdateTempSettingEvent extends SettingsEvent {
  final String? targetLang;
  final String? sourceLang;
  final bool? useMic;
  final double? fontSize;
  final bool? isBold;
  final double? opacity;
  final int? inputDeviceIndex;
  final int? outputDeviceIndex;
  final double? desktopVolume;
  final double? micVolume;
  final String? aiEngine;
  final String? apiKey;
  final String? transcriptionEngine;
  final bool clearInputDevice;
  final bool clearOutputDevice;

  const UpdateTempSettingEvent({
    this.targetLang,
    this.sourceLang,
    this.useMic,
    this.fontSize,
    this.isBold,
    this.opacity,
    this.inputDeviceIndex,
    this.outputDeviceIndex,
    this.desktopVolume,
    this.micVolume,
    this.aiEngine,
    this.apiKey,
    this.transcriptionEngine,
    this.clearInputDevice = false,
    this.clearOutputDevice = false,
  });

  @override
  List<Object?> get props => [
    targetLang,
    sourceLang,
    useMic,
    fontSize,
    isBold,
    opacity,
    inputDeviceIndex,
    outputDeviceIndex,
    desktopVolume,
    micVolume,
    aiEngine,
    apiKey,
    transcriptionEngine,
    clearInputDevice,
    clearOutputDevice,
  ];
}

class LoadDevicesEvent extends SettingsEvent {}

class SyncTempSettingsEvent extends SettingsEvent {
  final String targetLang;
  final String sourceLang;
  final bool useMic;
  final double fontSize;
  final bool isBold;
  final double opacity;
  final int? inputDeviceIndex;
  final int? outputDeviceIndex;
  final double desktopVolume;
  final double micVolume;
  final String aiEngine;
  final String? apiKey;
  final String? transcriptionEngine;

  const SyncTempSettingsEvent({
    required this.targetLang,
    required this.sourceLang,
    required this.useMic,
    required this.fontSize,
    required this.isBold,
    required this.opacity,
    this.inputDeviceIndex,
    this.outputDeviceIndex,
    required this.desktopVolume,
    required this.micVolume,
    required this.aiEngine,
    this.apiKey,
    this.transcriptionEngine,
  });

  @override
  List<Object?> get props => [
    targetLang,
    sourceLang,
    useMic,
    fontSize,
    isBold,
    opacity,
    inputDeviceIndex,
    outputDeviceIndex,
    desktopVolume,
    micVolume,
    aiEngine,
    apiKey,
    transcriptionEngine,
  ];
}

class UpdateAudioLevelsEvent extends SettingsEvent {
  final double inputVolume;
  final double outputVolume;

  const UpdateAudioLevelsEvent(this.inputVolume, this.outputVolume);

  @override
  List<Object?> get props => [inputVolume, outputVolume];
}

class SaveSettingsEvent extends SettingsEvent {}
