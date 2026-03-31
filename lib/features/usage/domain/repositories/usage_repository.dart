import 'package:omni_bridge/features/usage/domain/entities/engine_usage.dart';
import 'package:omni_bridge/features/usage/domain/entities/daily_usage_record.dart';
import 'package:omni_bridge/features/usage/domain/entities/quota_status.dart';

abstract class UsageRepository {
  Future<List<EngineUsage>> getModelUsageStats();
  Future<List<DailyUsageRecord>> getDailyUsageHistory({int days = 30});
  
  Stream<QuotaStatus> get quotaStatusStream;
  QuotaStatus? get currentQuotaStatus;
  
  /// Returns the per-engine monthly usage totals.
  Map<String, int> get engineMonthlyUsage;

  /// Returns the complete usage totals Map from the data source.
  Future<Map<String, dynamic>> getUsageTotals();

  /// Performs a calendar month rollover.
  Future<void> rolloverCalendar(String month, int tokens);

  /// Performs a weekly rollover.
  Future<void> rolloverWeekly(String oldWeek, int tokens, String currentWeek);

  /// Performs a subscription rollover (paid tiers only).
  Future<void> rolloverSubscription(String cycleLabel, int tokens, DateTime nextReset);
}
