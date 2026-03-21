import '../repositories/i_translation_repository.dart';

class StopTranslationUseCase {
  final ITranslationRepository _repository;

  StopTranslationUseCase(this._repository);

  void call() {
    _repository.stop();
  }
}
