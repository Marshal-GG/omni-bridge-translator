import 'package:omni_bridge/features/usage/domain/entities/engine_usage.dart';
import 'package:omni_bridge/features/usage/domain/entities/daily_usage_record.dart';
import 'package:omni_bridge/features/subscription/domain/entities/subscription_status.dart';

abstract class UsageRepository {
  Future<List<EngineUsage>> getModelUsageStats();
  Future<List<DailyUsageRecord>> getDailyUsageHistory({int days = 30});
  Future<SubscriptionStatus?> getSubscriptionStatus();
}
