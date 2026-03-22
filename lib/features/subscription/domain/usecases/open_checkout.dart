import '../repositories/i_subscription_repository.dart';

class OpenCheckout {
  final ISubscriptionRepository _repository;

  OpenCheckout(this._repository);

  Future<void> call(String tierId) => _repository.openCheckout(tierId);
}
