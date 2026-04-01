import 'package:omni_bridge/features/usage/domain/entities/daily_usage_record.dart';
import 'package:omni_bridge/features/usage/domain/repositories/usage_repository.dart';

class GetUsageHistory {
  final UsageRepository _repository;

  GetUsageHistory(this._repository);

  Future<List<DailyUsageRecord>> call({int days = 30}) =>
      _repository.getDailyUsageHistory(days: days);
}
