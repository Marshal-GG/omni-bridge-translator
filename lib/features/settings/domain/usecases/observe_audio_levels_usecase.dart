import 'package:omni_bridge/features/translation/domain/repositories/i_translation_repository.dart';

class ObserveAudioLevelsUseCase {
  final ITranslationRepository repository;

  ObserveAudioLevelsUseCase(this.repository);

  void call(void Function(double inputLevel, double outputLevel) onAudioLevel) {
    repository.onAudioLevel = onAudioLevel;
  }
}
