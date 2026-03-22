import 'package:omni_bridge/features/subscription/data/models/subscription_dto.dart';
import 'package:omni_bridge/features/translation/domain/repositories/i_translation_repository.dart';

class GetInitialQuotaStatusUseCase {
  final ITranslationRepository repository;

  GetInitialQuotaStatusUseCase(this.repository);

  SubscriptionStatus? call() {
    return repository.currentQuotaStatus;
  }
}
