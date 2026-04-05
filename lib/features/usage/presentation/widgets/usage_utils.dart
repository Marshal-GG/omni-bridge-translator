import 'package:omni_bridge/core/constants/engine_registry.dart';
import 'package:omni_bridge/features/usage/domain/entities/engine_usage.dart';

class UsageUtils {
  static String getDisplayName(String statsKey, UsageType type) {
    if (statsKey.isEmpty) return 'Unknown';
    return EngineRegistry.displayNameForStatsKey(statsKey);
  }
}
