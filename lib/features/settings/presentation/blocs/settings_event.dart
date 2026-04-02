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

class ResetIODefaultsEvent extends SettingsEvent {}

class SaveSettingsEvent extends SettingsEvent {}

class SubscriptionStatusChangedEvent extends SettingsEvent {
  final QuotaStatus status;

  const SubscriptionStatusChangedEvent(this.status);

  @override
  List<Object?> get props => [status];
}

class InitializeSettingsEvent extends SettingsEvent {
  final int initialTabIndex;
  final Map<String, dynamic> modelStatuses;

  const InitializeSettingsEvent({
    this.initialTabIndex = 0,
    this.modelStatuses = const {},
  });

  @override
  List<Object?> get props => [initialTabIndex, modelStatuses];
}

class SettingsTabIndexChanged extends SettingsEvent {
  final int index;
  const SettingsTabIndexChanged(this.index);

  @override
  List<Object?> get props => [index];
}

class LiveVolumeUpdateEvent extends SettingsEvent {
  final double desktopVolume;
  final double micVolume;

  const LiveVolumeUpdateEvent({
    required this.desktopVolume,
    required this.micVolume,
  });

  @override
  List<Object?> get props => [desktopVolume, micVolume];
}

class LiveDeviceUpdateEvent extends SettingsEvent {
  final int? inputDeviceIndex;
  final int? outputDeviceIndex;

  const LiveDeviceUpdateEvent({this.inputDeviceIndex, this.outputDeviceIndex});

  @override
  List<Object?> get props => [inputDeviceIndex, outputDeviceIndex];
}

class LiveMicToggleEvent extends SettingsEvent {
  final bool useMic;

  const LiveMicToggleEvent({required this.useMic});

  @override
  List<Object?> get props => [useMic];
}
