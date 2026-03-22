import '../repositories/i_subscription_repository.dart';

class HasUsedTrial {
  final ISubscriptionRepository _repository;

  HasUsedTrial(this._repository);

  Future<bool> call() => _repository.hasUsedTrial();
}
