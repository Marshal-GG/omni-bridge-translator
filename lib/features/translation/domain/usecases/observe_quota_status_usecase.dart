import 'package:omni_bridge/features/usage/domain/entities/quota_status.dart';
import 'package:omni_bridge/features/usage/domain/repositories/usage_repository.dart';

class ObserveQuotaStatusUseCase {
  final UsageRepository repository;

  ObserveQuotaStatusUseCase(this.repository);

  Stream<QuotaStatus> call() {
    return repository.quotaStatusStream;
  }
}
