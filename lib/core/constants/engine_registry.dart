enum EngineType { asr, translation }

class EngineInfo {
  final String settingsKey;
  final String statsKey;
  final String displayName;
  final EngineType type;

  const EngineInfo({
    required this.settingsKey,
    required this.statsKey,
    required this.displayName,
    required this.type,
  });
}

class EngineRegistry {
  EngineRegistry._();

  static const List<EngineInfo> all = [
    // ── Translation ──────────────────────────────────────────────────────────
    EngineInfo(
      settingsKey: 'google',
      statsKey: 'google-translate',
      displayName: 'Google Translate',
      type: EngineType.translation,
    ),
    EngineInfo(
      settingsKey: 'google_api',
      statsKey: 'google-cloud-v3-grpc',
      displayName: 'Google Cloud',
      type: EngineType.translation,
    ),
    EngineInfo(
      settingsKey: 'mymemory',
      statsKey: 'mymemory-translate',
      displayName: 'MyMemory',
      type: EngineType.translation,
    ),
    EngineInfo(
      settingsKey: 'riva-nmt',
      statsKey: 'riva-grpc-mt',
      displayName: 'NVIDIA Riva NMT',
      type: EngineType.translation,
    ),
    EngineInfo(
      settingsKey: 'llama',
      statsKey: 'llama-translate',
      displayName: 'Llama 3.1',
      type: EngineType.translation,
    ),

    // ── ASR ──────────────────────────────────────────────────────────────────
    EngineInfo(
      settingsKey: 'online',
      statsKey: 'google-asr',
      displayName: 'Google Speech',
      type: EngineType.asr,
    ),
    EngineInfo(
      settingsKey: 'whisper-tiny',
      statsKey: 'whisper-asr',
      displayName: 'Whisper',
      type: EngineType.asr,
    ),
    EngineInfo(
      settingsKey: 'whisper-base',
      statsKey: 'whisper-asr',
      displayName: 'Whisper',
      type: EngineType.asr,
    ),
    EngineInfo(
      settingsKey: 'whisper-small',
      statsKey: 'whisper-asr',
      displayName: 'Whisper',
      type: EngineType.asr,
    ),
    EngineInfo(
      settingsKey: 'whisper-medium',
      statsKey: 'whisper-asr',
      displayName: 'Whisper',
      type: EngineType.asr,
    ),
    EngineInfo(
      settingsKey: 'whisper-large',
      statsKey: 'whisper-asr',
      displayName: 'Whisper',
      type: EngineType.asr,
    ),
    EngineInfo(
      settingsKey: 'riva-asr',
      statsKey: 'riva-asr',
      displayName: 'NVIDIA Riva ASR',
      type: EngineType.asr,
    ),
  ];

  // ── Lookups ────────────────────────────────────────────────────────────────

  /// Translates a settings key → RTDB stats key.
  /// Returns the settings key unchanged if no mapping exists.
  static String settingsKeyToStatsKey(String settingsKey) {
    for (final e in all) {
      if (e.settingsKey == settingsKey) return e.statsKey;
    }
    return settingsKey;
  }

  /// Display name for a given RTDB stats key.
  /// Falls back to title-casing the key if not found.
  static String displayNameForStatsKey(String statsKey) {
    for (final e in all) {
      if (e.statsKey == statsKey) return e.displayName;
    }
    return _titleCase(statsKey);
  }

  /// All settings keys that map to a given RTDB stats key.
  /// (Multiple settings keys can share one stats key, e.g. all whisper-* → whisper-asr.)
  static List<String> settingsKeysForStatsKey(String statsKey) =>
      all.where((e) => e.statsKey == statsKey).map((e) => e.settingsKey).toList();

  /// Unique RTDB stats keys for all known ASR engines.
  static List<String> get knownAsrStatsKeys =>
      all
          .where((e) => e.type == EngineType.asr)
          .map((e) => e.statsKey)
          .toSet()
          .toList();

  /// Unique RTDB stats keys for all known translation engines.
  static List<String> get knownTranslationStatsKeys =>
      all
          .where((e) => e.type == EngineType.translation)
          .map((e) => e.statsKey)
          .toSet()
          .toList();

  static String _titleCase(String s) => s
      .replaceAll('-', ' ')
      .replaceAll('_', ' ')
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}
