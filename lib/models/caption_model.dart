class CaptionMessage {
  final String text;
  final String original;
  final bool isError;
  final bool isFinal;
  final bool isSystemMessage;
  final String? sourceLangOverride;
  // Non-null when type == 'audio_levels'
  final double? inputLevel;
  final double? outputLevel;
  // Non-null when type == 'usage_stats'
  final Map<String, dynamic>? usageStats;
  // Non-null when type == 'model_status'
  final List<dynamic>? modelStatuses;

  CaptionMessage({
    required this.text,
    required this.original,
    required this.isError,
    required this.isFinal,
    this.isSystemMessage = false,
    this.sourceLangOverride,
    this.inputLevel,
    this.outputLevel,
    this.usageStats,
    this.modelStatuses,
  });

  factory CaptionMessage.fromJson(Map<String, dynamic> json) {
    // Audio level packets
    if (json['type'] == 'audio_levels') {
      return CaptionMessage(
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
      return CaptionMessage(
        text: '',
        original: '',
        isError: false,
        isFinal: false,
        usageStats: Map<String, dynamic>.from(json),
      );
    }

    // Model status packet
    if (json['type'] == 'model_status') {
      return CaptionMessage(
        text: '',
        original: '',
        isError: false,
        isFinal: false,
        modelStatuses: json['models'] as List<dynamic>?,
      );
    }

    final text = json['text'] as String? ?? '';
    // nim_api sends this magic string when auto-ASR falls back to a specific lang
    String? magicOverride;
    if (text.startsWith('__source_lang_override__:')) {
      magicOverride = text.split(':').last.trim();
    }
    return CaptionMessage(
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
