import 'package:omni_bridge/features/usage/domain/entities/engine_usage.dart';
import 'package:omni_bridge/features/subscription/data/datasources/subscription_remote_datasource.dart';

class UsageUtils {
  /// Canonical mapping from RTDB engine key → human-readable display name.
  /// These must match the keys used in `model_stats/{engine}` in RTDB.
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
    'whisper-tiny': 'Whisper Tiny',
    'whisper-base': 'Whisper Base',
    'whisper-small': 'Whisper Small',
    'whisper-medium': 'Whisper Medium',
    'whisper-large': 'Whisper Large',
    'riva-asr': 'NVIDIA Riva ASR',
  };

  /// Returns a human-readable display name for the given engine ID and type.
  ///
  /// Priority:
  ///   1. Remote config `model_overrides[engineId].display_name` (authoritative, live from Firestore).
  ///   2. Static lookup table above (fast, deterministic for known IDs).
  ///   3. Dynamic pattern matching for Whisper size variants.
  ///   4. Title-cased version of the engine ID as absolute fallback.
  static String getDisplayName(String engineId, UsageType type) {
    if (engineId.isEmpty) return 'Unknown';

    // 1. Remote config is the single source of truth.
    final remoteName =
        SubscriptionRemoteDataSource.instance.getModelDisplayName(engineId);
    if (remoteName != engineId && remoteName.isNotEmpty) {
      return remoteName;
    }

    // 2. Static lookup (covers all expected RTDB keys, including legacy variants).
    final staticName = _staticDisplayNames[engineId.toLowerCase()];
    if (staticName != null) return staticName;

    // 3. Dynamic pattern: whisper-{size}
    final id = engineId.toLowerCase();
    if (id.startsWith('whisper-')) {
      final size = id.substring('whisper-'.length);
      if (size.isEmpty) return 'Whisper';
      return 'Whisper ${size[0].toUpperCase()}${size.substring(1)}';
    }

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
