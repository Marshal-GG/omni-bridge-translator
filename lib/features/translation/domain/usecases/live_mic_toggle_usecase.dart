import '../repositories/i_translation_repository.dart';

class LiveMicToggleUseCase {
  final ITranslationRepository _repository;

  LiveMicToggleUseCase(this._repository);

  void call(bool useMic) {
    _repository.liveMicToggle(useMic);
  }
}
