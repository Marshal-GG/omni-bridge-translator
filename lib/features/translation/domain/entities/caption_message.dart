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

  const CaptionMessage({
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
}
