import 'package:omni_bridge/features/translation/domain/repositories/i_translation_repository.dart';

class GetDefaultTierUseCase {
  final ITranslationRepository repository;

  GetDefaultTierUseCase(this.repository);

  String call() {
    return repository.defaultTier;
  }
}
