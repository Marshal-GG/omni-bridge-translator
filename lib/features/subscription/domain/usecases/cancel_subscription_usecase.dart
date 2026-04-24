import '../repositories/i_subscription_repository.dart';

class CancelSubscriptionUseCase {
  final ISubscriptionRepository _repo;
  const CancelSubscriptionUseCase(this._repo);

  Future<String?> call() => _repo.cancelSubscription();
}
