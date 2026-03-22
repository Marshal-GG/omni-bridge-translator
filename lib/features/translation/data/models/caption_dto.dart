import '../../domain/entities/caption_message.dart';

class CaptionDto extends CaptionMessage {
  const CaptionDto({
    required super.text,
    required super.original,
    required super.isError,
    required super.isFinal,
    super.isSystemMessage = false,
    super.sourceLangOverride,
    super.inputLevel,
    super.outputLevel,
    super.usageStats,
    super.modelStatuses,
    super.isReset = false,
  });

  factory CaptionDto.fromJson(Map<String, dynamic> json) {
    // Session reset packet
    if (json['type'] == 'reset') {
      return const CaptionDto(
        text: '',
        original: '',
        isError: false,
        isFinal: false,
        isReset: true,
      );
    }

    // Audio level packets
    if (json['type'] == 'audio_levels') {
      return CaptionDto(
        text: '',
        original: '',
        isError: false,
        isFinal: false,
        inputLevel: (json['input_level'] as num?)?.toDouble() ?? 0.0,
        outputLevel: (json['output_level'] as num?)?.toDouble() ?? 0.0,
      );
    }

    // Usage stats packet
    if (json['type'] == 'usage_stats') {
      return CaptionDto(
        text: '',
        original: '',
        isError: false,
        isFinal: false,
        usageStats: Map<String, dynamic>.from(json),
      );
    }

    // Model status packet
    if (json['type'] == 'model_status') {
      return CaptionDto(
        text: '',
        original: '',
        isError: false,
        isFinal: false,
        modelStatuses: json['models'] as List<dynamic>?,
      );
    }

    final text = json['text'] as String? ?? '';
    // orchestrator sends this magic string when auto-ASR falls back to a specific lang
    String? magicOverride;
    if (text.startsWith('__source_lang_override__:')) {
      magicOverride = text.split(':').last.trim();
    }
    return CaptionDto(
      text: magicOverride != null ? '' : text,
      original: json['original'] ?? '',
      isError: json['type'] == 'error',
      isFinal: json['is_final'] ?? true,
      sourceLangOverride: json['type'] == 'source_lang_override'
          ? json['lang']
          : magicOverride,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'original': original,
      'is_error': isError,
      'is_final': isFinal,
      'is_system_message': isSystemMessage,
      'source_lang_override': sourceLangOverride,
      'input_level': inputLevel,
      'output_level': outputLevel,
      'usage_stats': usageStats,
      'model_statuses': modelStatuses,
    };
  }
}
