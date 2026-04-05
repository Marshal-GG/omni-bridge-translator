abstract class IEngineSelectionSource {
  Future<String> getSelectedTranslationEngine();
  Future<String> getSelectedTranscriptionEngine();
}
