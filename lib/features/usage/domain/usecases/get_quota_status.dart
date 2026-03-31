import 'package:omni_bridge/features/usage/domain/entities/quota_status.dart';
import 'package:omni_bridge/features/usage/domain/repositories/usage_repository.dart';

class GetQuotaStatus {
  final UsageRepository _repository;

  GetQuotaStatus(this._repository);

  QuotaStatus? get current => _repository.currentQuotaStatus;
  Stream<QuotaStatus> get stream => _repository.quotaStatusStream;
}
