import 'package:equatable/equatable.dart';
import 'package:omni_bridge/features/usage/domain/entities/quota_status.dart';

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
  final String? translationModel;
  final String? nvidiaNimKey;
  final String? transcriptionModel;
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
    this.translationModel,
    this.nvidiaNimKey,
    this.transcriptionModel,
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
    translationModel,
    nvidiaNimKey,
    transcriptionModel,
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
  final String translationModel;
  final String? nvidiaNimKey;
  final String? transcriptionModel;

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
    required this.translationModel,
    this.nvidiaNimKey,
    this.transcriptionModel,
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
    translationModel,
    nvidiaNimKey,
    transcriptionModel,
  ];
}

class ResetIODefaultsEvent extends SettingsEvent {}

class SaveSettingsEvent extends SettingsEvent {}

class SubscriptionStatusChangedEvent extends SettingsEvent {
  final QuotaStatus status;

  const SubscriptionStatusChangedEvent(this.status);

  @override
  List<Object?> get props => [status];
}

class InitializeSettingsEvent extends SettingsEvent {
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
  final String translationModel;
  final String? nvidiaNimKey;
  final String? transcriptionModel;
  final int initialTabIndex;

  const InitializeSettingsEvent({
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
    required this.translationModel,
    this.nvidiaNimKey,
    this.transcriptionModel,
    required this.initialTabIndex,
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
    translationModel,
    nvidiaNimKey,
    transcriptionModel,
    initialTabIndex,
  ];
}

class SettingsTabIndexChanged extends SettingsEvent {
  final int index;
  const SettingsTabIndexChanged(this.index);

  @override
  List<Object?> get props => [index];
}
