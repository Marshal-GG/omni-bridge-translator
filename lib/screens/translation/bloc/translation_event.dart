import 'package:equatable/equatable.dart';

abstract class TranslationEvent extends Equatable {
  const TranslationEvent();

  @override
  List<Object?> get props => [];
}

class ToggleSettingsEvent extends TranslationEvent {}

class ToggleShrinkEvent extends TranslationEvent {}

class LoadSettingsEvent extends TranslationEvent {}

class SourceLangOverrideEvent extends TranslationEvent {
  final String sourceLang;
  const SourceLangOverrideEvent(this.sourceLang);

  @override
  List<Object?> get props => [sourceLang];
}

class ApplySettingsEvent extends TranslationEvent {
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

  const ApplySettingsEvent({
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
  ];
}

/// Fired when the server sends a type:'error' message (API failure / lang issue).
class LangErrorEvent extends TranslationEvent {
  final String message;
  const LangErrorEvent(this.message);

  @override
  List<Object?> get props => [message];
}
