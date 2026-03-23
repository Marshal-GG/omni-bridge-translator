import '../repositories/i_translation_repository.dart';

class CheckServerHealthUseCase {
  final ITranslationRepository _repository;

  CheckServerHealthUseCase(this._repository);

  Future<bool> call() async {
    return await _repository.checkServerHealth();
  }
}
