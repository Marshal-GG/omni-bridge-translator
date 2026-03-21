import '../repositories/i_translation_repository.dart';

class GetModelStatusUseCase {
  final ITranslationRepository _repository;

  GetModelStatusUseCase(this._repository);

  Future<List<dynamic>> call() {
    return _repository.getModelStatuses();
  }
}
