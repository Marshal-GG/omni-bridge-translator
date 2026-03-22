import 'package:omni_bridge/features/subscription/data/models/subscription_dto.dart';
import 'package:omni_bridge/features/translation/domain/repositories/i_translation_repository.dart';

class ObserveQuotaStatusUseCase {
  final ITranslationRepository repository;

  ObserveQuotaStatusUseCase(this.repository);

  Stream<SubscriptionStatus> call() {
    return repository.quotaStatusStream;
  }
}
