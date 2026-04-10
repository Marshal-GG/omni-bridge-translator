import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omni_bridge/features/usage/domain/entities/daily_usage_record.dart';
import 'package:omni_bridge/features/usage/domain/usecases/get_usage_stats.dart';
import 'package:omni_bridge/features/usage/domain/usecases/get_usage_history.dart';
import 'package:omni_bridge/features/usage/domain/usecases/get_quota_status.dart';
import 'package:omni_bridge/features/usage/domain/usecases/check_usage_rollover.dart';
import 'package:omni_bridge/features/usage/domain/usecases/get_selected_engines_usecase.dart';
import 'package:omni_bridge/features/usage/domain/usecases/clear_usage_cache.dart';
import 'package:omni_bridge/features/usage/presentation/bloc/usage_event.dart';
import 'package:omni_bridge/features/usage/presentation/bloc/usage_state.dart';

class UsageBloc extends Bloc<UsageEvent, UsageState> {
  final GetUsageStats _getUsageStats;
  final GetUsageHistory _getUsageHistory;
  final GetQuotaStatus _getQuotaStatus;
  final CheckUsageRollover _checkUsageRollover;
  final GetSelectedEnginesUseCase _getSelectedEngines;
  final ClearUsageCache _clearUsageCache;

  UsageBloc({
    required GetUsageStats getUsageStats,
    required GetUsageHistory getUsageHistory,
    required GetQuotaStatus getQuotaStatus,
    required CheckUsageRollover checkUsageRollover,
    required GetSelectedEnginesUseCase getSelectedEngines,
    required ClearUsageCache clearUsageCache,
  }) : _getUsageStats = getUsageStats,
       _getUsageHistory = getUsageHistory,
       _getQuotaStatus = getQuotaStatus,
       _checkUsageRollover = checkUsageRollover,
       _getSelectedEngines = getSelectedEngines,
       _clearUsageCache = clearUsageCache,
       super(UsageInitial()) {
    on<LoadUsageStats>(_onLoadUsageStats);
  }

  Future<void> _onLoadUsageStats(
    LoadUsageStats event,
    Emitter<UsageState> emit,
  ) async {
    emit(UsageLoading());
    try {
      // Pull-to-refresh bypasses the cache so the user always gets fresh data.
      if (event.refresh) _clearUsageCache();

      // Rollover must complete first — it may reset counters that stats reads.
      await _checkUsageRollover();

      // Stats, history and engine selection are independent — run in parallel.
      late UsageSummary summary;
      late List<DailyUsageRecord> history;
      late SelectedEngines engines;

      await Future.wait([
        _getUsageStats().then((v) => summary = v),
        _getUsageHistory().then((v) => history = v),
        _getSelectedEngines().then((v) => engines = v),
      ]);

      final quotaStatus = _getQuotaStatus.current;

      emit(
        UsageLoaded(
          engineUsage: summary.stats,
          dailyHistory: history,
          lifetimeTokens: quotaStatus?.lifetimeTokensUsed ?? 0,
          monthlyTokens: quotaStatus?.monthlyTokensUsed ?? 0,
          asrTokens: summary.asrTokens,
          translationTokens: summary.translationTokens,
          tier: quotaStatus?.tier.toUpperCase() ?? 'FREE',
          quotaStatus: quotaStatus,
          selectedTranslationEngine: engines.translationStatsKey,
          selectedTranscriptionEngine: engines.transcriptionStatsKey,
        ),
      );
    } catch (e) {
      emit(UsageError(e.toString()));
    }
  }
}
