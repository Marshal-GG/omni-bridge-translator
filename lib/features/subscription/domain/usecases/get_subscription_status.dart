import '../entities/subscription_status.dart';
import '../repositories/i_subscription_repository.dart';

class GetSubscriptionStatus {
  final ISubscriptionRepository _repository;

  GetSubscriptionStatus(this._repository);

  Stream<SubscriptionStatus> call() => _repository.statusStream;

  SubscriptionStatus? get current => _repository.currentStatus;
}
