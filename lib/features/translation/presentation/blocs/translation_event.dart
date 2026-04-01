import 'package:equatable/equatable.dart';
import 'package:omni_bridge/features/usage/domain/entities/quota_status.dart';

abstract class TranslationEvent extends Equatable {
  const TranslationEvent();

  @override
  List<Object?> get props => [];
}

class ToggleShrinkEvent extends TranslationEvent {}

class ToggleRunningEvent extends TranslationEvent {}

class UpdateQuotaEvent extends TranslationEvent {
  final QuotaStatus? status;
  const UpdateQuotaEvent(this.status);

  @override
  List<Object?> get props => [status];
}

class QuotaExceededEvent extends TranslationEvent {}

/// Dispatched on every caption update while in shrunk mode so the bloc
/// can measure line count and resize the window to snugly fit the text.
class CaptionTextChangedEvent extends TranslationEvent {
  final String text;
  final double windowWidth;

  const CaptionTextChangedEvent({
    required this.text,
    required this.windowWidth,
  });

  @override
  List<Object?> get props => [text, windowWidth];
}

class LoadSettingsEvent extends TranslationEvent {}

class ResetSettingsEvent extends TranslationEvent {}

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
  final String translationModel;
  final String nvidiaNimKey;
  final String transcriptionModel;
  final String rivaTranslationFunctionId;
  final String rivaAsrParakeetFunctionId;
  final String rivaAsrCanaryFunctionId;
  final bool isUserInitiated;

  const ApplySettingsEvent({
    required this.targetLang,
    required this.sourceLang,
    required this.useMic,
    required this.fontSize,
    required this.isBold,
    required this.opacity,
    this.inputDeviceIndex,
    required this.outputDeviceIndex,
    required this.desktopVolume,
    required this.micVolume,
    required this.translationModel,
    this.nvidiaNimKey = '',
    this.transcriptionModel = 'online',
    this.rivaTranslationFunctionId = '',
    this.rivaAsrParakeetFunctionId = '',
    this.rivaAsrCanaryFunctionId = '',
    this.isUserInitiated = false,
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
    rivaTranslationFunctionId,
    rivaAsrParakeetFunctionId,
    rivaAsrCanaryFunctionId,
    isUserInitiated,
  ];
}

/// Fired when the server sends a type:'error' message (API failure / lang issue).
class LangErrorEvent extends TranslationEvent {
  final String message;
  const LangErrorEvent(this.message);

  @override
  List<Object?> get props => [message];
}

/// Fired when the server sends a type:'model_status' message.
class ModelStatusChangedEvent extends TranslationEvent {
  final List<dynamic> statuses;
  const ModelStatusChangedEvent(this.statuses);

  @override
  List<Object?> get props => [statuses];
}

class UpdateServerConnectionEvent extends TranslationEvent {
  final bool isConnected;
  const UpdateServerConnectionEvent({required this.isConnected});

  @override
  List<Object?> get props => [isConnected];
}

/// Fired when a specific paid engine's monthly limit is exceeded.
class EngineLimitReachedEvent extends TranslationEvent {
  /// The engine ID that hit its cap (e.g. `google_api`, `riva`, `llama`).
  final String engineId;
  const EngineLimitReachedEvent(this.engineId);

  @override
  List<Object?> get props => [engineId];
}

/// User chose to switch to the free fallback engine after seeing the dialog,
/// or the system is performing a silent fallback on repeat occurrences.
class SwitchToFallbackEngineEvent extends TranslationEvent {}
