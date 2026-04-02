import 'package:omni_bridge/features/translation/domain/repositories/i_translation_repository.dart';

class UnloadModelUseCase {
  final ITranslationRepository repository;

  UnloadModelUseCase(this.repository);

  Future<void> call() async {
    return await repository.unloadModel();
  }
}
