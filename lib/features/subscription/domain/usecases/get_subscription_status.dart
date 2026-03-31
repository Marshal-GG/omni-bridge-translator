import 'package:omni_bridge/features/usage/domain/entities/quota_status.dart';
import '../repositories/i_subscription_repository.dart';

class GetSubscriptionStatus {
  final ISubscriptionRepository _repository;

  GetSubscriptionStatus(this._repository);

  Stream<QuotaStatus> call() => _repository.statusStream;

  QuotaStatus? get current => _repository.currentStatus;
}
