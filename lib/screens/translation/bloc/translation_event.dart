import 'package:equatable/equatable.dart';

abstract class TranslationEvent extends Equatable {
  const TranslationEvent();

  @override
  List<Object?> get props => [];
}

class ToggleSettingsEvent extends TranslationEvent {}

class ToggleShrinkEvent extends TranslationEvent {}

class LoadDevicesEvent extends TranslationEvent {}

class SourceLangOverrideEvent extends TranslationEvent {
  final String sourceLang;
  const SourceLangOverrideEvent(this.sourceLang);

  @override
  List<Object?> get props => [sourceLang];
}

class SaveSettingsEvent extends TranslationEvent {}

class SyncTempSettingsEvent extends TranslationEvent {}

// Events for changing temp settings while the panel is open
class UpdateTempSettingEvent extends TranslationEvent {
  final String? targetLang;
  final String? sourceLang;
  final bool? useMic;
  final double? fontSize;
  final bool? isBold;
  final double? opacity;
  final int? inputDeviceIndex;
  final int? outputDeviceIndex;
  // A flag to determine if the device indices should be cleared (passed as null literally)
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
    clearInputDevice,
    clearOutputDevice,
  ];
}
