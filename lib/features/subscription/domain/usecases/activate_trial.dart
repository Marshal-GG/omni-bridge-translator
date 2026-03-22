import '../repositories/i_subscription_repository.dart';

class ActivateTrial {
  final ISubscriptionRepository _repository;

  ActivateTrial(this._repository);

  Future<String?> call() => _repository.activateTrial();
}
