import 'package:equatable/equatable.dart';
import '../../../subscription/domain/entities/subscription_status.dart';

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
  final String? apiKey;
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
    this.apiKey,
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
    apiKey,
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
  final String? apiKey;
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
    this.apiKey,
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
    apiKey,
    transcriptionModel,
  ];
}

class UpdateAudioLevelsEvent extends SettingsEvent {
  final double inputVolume;
  final double outputVolume;

  const UpdateAudioLevelsEvent(this.inputVolume, this.outputVolume);

  @override
  List<Object?> get props => [inputVolume, outputVolume];
}

class ResetIODefaultsEvent extends SettingsEvent {}

class SaveSettingsEvent extends SettingsEvent {}
class SubscriptionStatusChangedEvent extends SettingsEvent {
  final SubscriptionStatus status;

  const SubscriptionStatusChangedEvent(this.status);

  @override
  List<Object?> get props => [status];
}
