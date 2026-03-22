import '../entities/subscription_plan.dart';
import '../repositories/i_subscription_repository.dart';

class GetAvailablePlans {
  final ISubscriptionRepository _repository;

  GetAvailablePlans(this._repository);

  List<SubscriptionPlan> call() => _repository.availablePlans;

  Stream<void> get onChange => _repository.configChangeStream;
}
