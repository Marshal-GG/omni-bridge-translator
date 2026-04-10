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

  UsageRepositoryImpl({UsageRemoteDataSource? remoteDataSource})
    : _remoteDataSource = remoteDataSource ?? UsageRemoteDataSource.instance;

  static const _cacheTtl = Duration(minutes: 3);

  List<EngineUsage>? _cachedModelStats;
  DateTime? _modelStatsCachedAt;

  List<DailyUsageRecord>? _cachedHistory;
  DateTime? _historyCachedAt;

  Map<String, dynamic>? _cachedTotals;
  DateTime? _totalsCachedAt;

  @override
  void clearCache() => _clearCache();

  void _clearCache() {
    _cachedModelStats = null;
    _modelStatsCachedAt = null;
    _cachedHistory = null;
    _historyCachedAt = null;
    _cachedTotals = null;
    _totalsCachedAt = null;
  }

  bool _isFresh(DateTime? cachedAt) =>
      cachedAt != null &&
      DateTime.now().difference(cachedAt) < _cacheTtl;

  @override
  Future<List<EngineUsage>> getModelUsageStats() async {
    if (_isFresh(_modelStatsCachedAt)) return _cachedModelStats!;
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

      _cachedModelStats = stats;
      _modelStatsCachedAt = DateTime.now();
      return stats;
    } catch (e) {
      AppLogger.e(
        '[UsageRepositoryImpl] Error fetching model stats: $e',
        tag: 'UsageRepository',
        error: e,
      );
      return _cachedModelStats ?? [];
    }
  }

  @override
  Future<List<DailyUsageRecord>> getDailyUsageHistory({int days = 30}) async {
    if (_isFresh(_historyCachedAt)) return _cachedHistory!;
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

      final result = history.reversed.toList();
      _cachedHistory = result;
      _historyCachedAt = DateTime.now();
      return result;
    } catch (e) {
      AppLogger.e(
        '[UsageRepositoryImpl] Error fetching daily history: $e',
        tag: 'UsageRepository',
        error: e,
      );
      return _cachedHistory ?? [];
    }
  }

  @override
  Future<Map<String, dynamic>> getUsageTotals() async {
    if (_isFresh(_totalsCachedAt)) return _cachedTotals!;
    final uid = _remoteDataSource.currentUid;
    if (uid == null) return {};
    final result = await _remoteDataSource.fetchUsageTotals(uid);
    _cachedTotals = result;
    _totalsCachedAt = DateTime.now();
    return result;
  }

  @override
  Future<void> rolloverCalendar(String month, int tokens) async {
    final uid = _remoteDataSource.currentUid;
    final now = DateTime.now();
    final currentMonthStr =
        '${now.year}_${now.month.toString().padLeft(2, '0')}';
    if (uid != null) {
      await _remoteDataSource.rolloverCalendar(uid, month, currentMonthStr, tokens);
      _clearCache();
    }
  }

  @override
  Future<void> rolloverWeekly(
    String oldWeek,
    int tokens,
    String currentWeek,
  ) async {
    final uid = _remoteDataSource.currentUid;
    if (uid != null) {
      await _remoteDataSource.rolloverWeekly(uid, oldWeek, currentWeek, tokens);
      _clearCache();
    }
  }

  @override
  Future<void> rolloverSubscription(
    String cycleLabel,
    int tokens,
    DateTime nextReset,
  ) async {
    final uid = _remoteDataSource.currentUid;
    if (uid != null) {
      await _remoteDataSource.rolloverSubscription(uid, cycleLabel, tokens, nextReset);
      _clearCache();
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
