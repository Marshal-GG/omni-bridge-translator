import 'package:omni_bridge/features/usage/domain/entities/engine_usage.dart';
import 'package:omni_bridge/features/subscription/data/datasources/subscription_remote_datasource.dart';

class UsageUtils {
  /// Canonical mapping from RTDB engine key → human-readable display name.
  /// These must match the keys used in `model_stats/{engine}` in RTDB.
  ///
  /// All whisper variants (whisper-base, whisper-tiny, etc.) intentionally
  /// map to a single "Whisper" name so they get grouped into one card.
  static const Map<String, String> _staticDisplayNames = {
    // Translation engines
    'google': 'Google Translate',
    'google_api': 'Google Cloud',
    'mymemory': 'MyMemory',
    'riva-nmt': 'NVIDIA Riva NMT',
    'llama': 'Llama 3.1',
    // ASR engines
    'online': 'Google Speech',
    'whisper': 'Whisper',
    'whisper-tiny': 'Whisper',
    'whisper-base': 'Whisper',
    'whisper-small': 'Whisper',
    'whisper-medium': 'Whisper',
    'whisper-large': 'Whisper',
    'riva-asr': 'NVIDIA Riva ASR',
  };

  /// Returns a human-readable display name for the given engine ID and type.
  ///
  /// Priority:
  ///   1. Remote config `model_overrides[engineId].display_name` (authoritative, live from Firestore).
  ///   2. Static lookup table above (fast, deterministic for known IDs).
  ///   3. Dynamic pattern matching for Whisper size variants → all collapse to "Whisper".
  ///   4. Title-cased version of the engine ID as absolute fallback.
  static String getDisplayName(String engineId, UsageType type) {
    if (engineId.isEmpty) return 'Unknown';

    // 1. Remote config is the single source of truth.
    final remoteName = SubscriptionRemoteDataSource.instance
        .getModelDisplayName(engineId);
    if (remoteName != engineId && remoteName.isNotEmpty) {
      // If remote gives a whisper-specific name, still collapse to "Whisper"
      if (engineId.toLowerCase().startsWith('whisper')) return 'Whisper';
      return remoteName;
    }

    // 2. Static lookup (covers all expected RTDB keys).
    final staticName = _staticDisplayNames[engineId.toLowerCase()];
    if (staticName != null) return staticName;

    // 3. Dynamic pattern: any whisper-* variant → "Whisper"
    final id = engineId.toLowerCase();
    if (id.startsWith('whisper')) return 'Whisper';

    // 4. Absolute fallback: title-case + remove separators.
    return id
        .replaceAll('-', ' ')
        .replaceAll('_', ' ')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}
