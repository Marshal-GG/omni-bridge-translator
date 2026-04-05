import 'package:omni_bridge/core/constants/engine_registry.dart';

class UsageConstants {
  static List<String> get knownAsrEngines => EngineRegistry.knownAsrStatsKeys;
  static List<String> get knownTranslationEngines => EngineRegistry.knownTranslationStatsKeys;
}
