import 'package:omni_bridge/data/models/subscription_models.dart';
import 'package:omni_bridge/features/translation/domain/repositories/i_translation_repository.dart';

class ObserveQuotaStatusUseCase {
  final ITranslationRepository repository;

  ObserveQuotaStatusUseCase(this.repository);

  Stream<SubscriptionStatus> call() {
    return repository.quotaStatusStream;
  }
}
