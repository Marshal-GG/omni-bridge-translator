import 'package:omni_bridge/features/usage/domain/entities/quota_status.dart';
import 'package:omni_bridge/features/usage/domain/repositories/usage_repository.dart';

class GetInitialQuotaStatusUseCase {
  final UsageRepository repository;

  GetInitialQuotaStatusUseCase(this.repository);

  QuotaStatus? call() {
    return repository.currentQuotaStatus;
  }
}
