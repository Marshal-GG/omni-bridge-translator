import '../repositories/i_subscription_repository.dart';

class CheckEngineLimitUseCase {
  final ISubscriptionRepository _repository;

  CheckEngineLimitUseCase(this._repository);

  bool shouldShowNotice(String engineId) {
    return _repository.shouldShowEngineLimitNotice(engineId);
  }
}
