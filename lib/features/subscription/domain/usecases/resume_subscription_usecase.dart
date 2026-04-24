import '../repositories/i_subscription_repository.dart';

class ResumeSubscriptionUseCase {
  final ISubscriptionRepository _repo;
  const ResumeSubscriptionUseCase(this._repo);

  Future<String?> call() => _repo.resumeSubscription();
}
