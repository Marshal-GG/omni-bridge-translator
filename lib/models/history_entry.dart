class HistoryEntry {
  final String transcription;
  final String translation;
  final DateTime timestamp;
  final String sourceLang;
  final String targetLang;

  const HistoryEntry({
    required this.transcription,
    required this.translation,
    required this.timestamp,
    required this.sourceLang,
    required this.targetLang,
  });
}
