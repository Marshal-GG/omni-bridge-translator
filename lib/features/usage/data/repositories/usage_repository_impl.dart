import 'package:omni_bridge/core/utils/app_logger.dart';
import 'package:omni_bridge/features/usage/domain/entities/daily_usage_record.dart';
import 'package:omni_bridge/features/usage/domain/entities/engine_usage.dart';
import 'package:omni_bridge/features/usage/domain/repositories/usage_repository.dart';
import 'package:omni_bridge/features/usage/domain/entities/quota_status.dart';
import 'package:omni_bridge/features/usage/data/datasources/usage_remote_datasource.dart';
import 'package:omni_bridge/features/usage/data/models/engine_usage_dto.dart';
import 'package:omni_bridge/features/usage/data/models/daily_usage_record_dto.dart';

class UsageRepositoryImpl implements UsageRepository {
  final UsageRemoteDataSource _remoteDataSource;

  UsageRepositoryImpl({
    UsageRemoteDataSource? remoteDataSource,
  }) : _remoteDataSource = remoteDataSource ?? UsageRemoteDataSource.instance;

  @override
  Future<List<EngineUsage>> getModelUsageStats() async {
    try {
      final uid = _remoteDataSource.currentUid;
      if (uid == null) return [];

      final data = await _remoteDataSource.getModelUsageStatsRaw(uid);
      final List<EngineUsage> stats = [];

      data.forEach((engine, value) {
        if (value is Map<String, dynamic>) {
          stats.add(EngineUsageDto.fromJson(engine, value));
        }
      });

      return stats;
    } catch (e) {
      AppLogger.e('[UsageRepositoryImpl] Error fetching model stats: $e',
          tag: 'UsageRepository', error: e);
      return [];
    }
  }

  @override
  Future<List<DailyUsageRecord>> getDailyUsageHistory({int days = 30}) async {
    try {
      final uid = _remoteDataSource.currentUid;
      if (uid == null) return [];

      final data = await _remoteDataSource.getDailyUsageHistoryRaw(uid);
      final List<DailyUsageRecord> history = [];

      final sortedKeys = data.keys.toList()..sort((a, b) => b.compareTo(a));
      final limitKeys = sortedKeys.take(days).toList();

      for (final dateStr in limitKeys) {
        final dayData = data[dateStr] as Map<String, dynamic>?;
        if (dayData == null) continue;
        history.add(DailyUsageRecordDto.fromJson(dateStr, dayData));
      }

      return history.reversed.toList();
    } catch (e) {
      AppLogger.e('[UsageRepositoryImpl] Error fetching daily history: $e',
          tag: 'UsageRepository', error: e);
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>> getUsageTotals() async {
    final uid = _remoteDataSource.currentUid;
    if (uid == null) return {};
    return _remoteDataSource.fetchUsageTotals(uid);
  }

  @override
  Future<void> rolloverCalendar(String month, int tokens) async {
    final uid = _remoteDataSource.currentUid;
    final now = DateTime.now();
    final currentMonthStr =
        '${now.year}_${now.month.toString().padLeft(2, '0')}';
    if (uid != null) {
      await _remoteDataSource.rolloverCalendar(
          uid, month, currentMonthStr, tokens);
    }
  }

  @override
  Future<void> rolloverWeekly(
      String oldWeek, int tokens, String currentWeek) async {
    final uid = _remoteDataSource.currentUid;
    if (uid != null) {
      await _remoteDataSource.rolloverWeekly(uid, oldWeek, currentWeek, tokens);
    }
  }

  @override
  Future<void> rolloverSubscription(
      String cycleLabel, int tokens, DateTime nextReset) async {
    final uid = _remoteDataSource.currentUid;
    if (uid != null) {
      await _remoteDataSource.rolloverSubscription(
          uid, cycleLabel, tokens, nextReset);
    }
  }

  @override
  Stream<QuotaStatus> get quotaStatusStream =>
      _remoteDataSource.quotaStatusStream;

  @override
  QuotaStatus? get currentQuotaStatus => _remoteDataSource.currentQuotaStatus;

  @override
  Map<String, int> get engineMonthlyUsage =>
      _remoteDataSource.engineMonthlyUsage;
}
