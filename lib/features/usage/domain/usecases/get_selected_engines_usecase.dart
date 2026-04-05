import 'package:omni_bridge/core/constants/engine_registry.dart';
import 'package:omni_bridge/core/interfaces/i_engine_selection_source.dart';

class SelectedEngines {
  final String translationStatsKey;
  final String transcriptionStatsKey;

  const SelectedEngines({
    required this.translationStatsKey,
    required this.transcriptionStatsKey,
  });
}

class GetSelectedEnginesUseCase {
  final IEngineSelectionSource _source;

  GetSelectedEnginesUseCase(this._source);

  Future<SelectedEngines> call() async {
    final translationSettingsKey = await _source.getSelectedTranslationEngine();
    final transcriptionSettingsKey = await _source.getSelectedTranscriptionEngine();
    return SelectedEngines(
      translationStatsKey: EngineRegistry.settingsKeyToStatsKey(translationSettingsKey),
      transcriptionStatsKey: EngineRegistry.settingsKeyToStatsKey(transcriptionSettingsKey),
    );
  }
}
