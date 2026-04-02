import '../repositories/i_subscription_repository.dart';

class CheckModelAccessUseCase {
  final ISubscriptionRepository _repository;

  CheckModelAccessUseCase(this._repository);

  bool isTranslationModelAllowed(String modelId, [String? tier]) {
    return _repository.allowedTranslationModels(tier).contains(modelId);
  }

  bool isTranscriptionModelAllowed(String modelId, [String? tier]) {
    return _repository.allowedTranscriptionModels(tier).contains(modelId);
  }
}
