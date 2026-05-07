class HistoryEntry {
  final String transcription;
  final String translation;
  final DateTime timestamp;
  final String sourceLang;
  final String targetLang;

  /// Translation engine ID at the time of capture (e.g. `'riva-nmt'`,
  /// `'llama'`, `'google_api'`). Null for entries written before the field
  /// was added or when the active engine is unknown — UI gracefully renders
  /// `'—'` in that case.
  final String? engine;

  const HistoryEntry({
    required this.transcription,
    required this.translation,
    required this.timestamp,
    required this.sourceLang,
    required this.targetLang,
    this.engine,
  });
}
