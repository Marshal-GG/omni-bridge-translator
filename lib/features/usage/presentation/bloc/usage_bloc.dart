import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omni_bridge/features/usage/domain/usecases/get_usage_stats.dart';
import 'package:omni_bridge/features/usage/domain/usecases/get_usage_history.dart';
import 'package:omni_bridge/features/usage/domain/usecases/get_quota_status.dart';
import 'package:omni_bridge/features/usage/domain/usecases/check_usage_rollover.dart';
import 'package:omni_bridge/features/usage/presentation/bloc/usage_event.dart';
import 'package:omni_bridge/features/usage/presentation/bloc/usage_state.dart';

class UsageBloc extends Bloc<UsageEvent, UsageState> {
  final GetUsageStats _getUsageStats;
  final GetUsageHistory _getUsageHistory;
  final GetQuotaStatus _getQuotaStatus;
  final CheckUsageRollover _checkUsageRollover;

  UsageBloc({
    required GetUsageStats getUsageStats,
    required GetUsageHistory getUsageHistory,
    required GetQuotaStatus getQuotaStatus,
    required CheckUsageRollover checkUsageRollover,
  }) : _getUsageStats = getUsageStats,
       _getUsageHistory = getUsageHistory,
       _getQuotaStatus = getQuotaStatus,
       _checkUsageRollover = checkUsageRollover,
       super(UsageInitial()) {
    on<LoadUsageStats>(_onLoadUsageStats);
  }

  Future<void> _onLoadUsageStats(
    LoadUsageStats event,
    Emitter<UsageState> emit,
  ) async {
    emit(UsageLoading());
    try {
      // Perform rollover check before loading stats
      await _checkUsageRollover();

      final summary = await _getUsageStats();
      final history = await _getUsageHistory();
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
        ),
      );
    } catch (e) {
      emit(UsageError(e.toString()));
    }
  }
}
