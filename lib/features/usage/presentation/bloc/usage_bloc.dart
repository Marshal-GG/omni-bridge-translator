import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omni_bridge/features/usage/domain/entities/engine_usage.dart';
import 'package:omni_bridge/features/usage/domain/repositories/usage_repository.dart';
import 'package:omni_bridge/features/usage/presentation/bloc/usage_event.dart';
import 'package:omni_bridge/features/usage/presentation/bloc/usage_state.dart';
import 'package:omni_bridge/features/usage/presentation/widgets/usage_utils.dart';
import 'package:omni_bridge/features/subscription/data/datasources/subscription_remote_datasource.dart';

class UsageBloc extends Bloc<UsageEvent, UsageState> {
  final UsageRepository _usageRepository;

  UsageBloc({required UsageRepository usageRepository})
    : _usageRepository = usageRepository,
      super(UsageInitial()) {
    on<LoadUsageStats>(_onLoadUsageStats);
  }

  Future<void> _onLoadUsageStats(
    LoadUsageStats event,
    Emitter<UsageState> emit,
  ) async {
    emit(UsageLoading());

    try {
      final rawStats = (await _usageRepository.getModelUsageStats()).toList();
      final history = await _usageRepository.getDailyUsageHistory();
      final subStatus = await _usageRepository.getSubscriptionStatus();

      // ── 1. Compute monthly per-engine usage ──
      // Primary source: SubscriptionRemoteDataSource.engineMonthlyUsage
      // (fetched from usage/totals/subscription_monthly_models via REST polling).
      // Secondary source: daily_usage history aggregation (fills gaps).
      final src = SubscriptionRemoteDataSource.instance;
      final now = DateTime.now();
      final Map<String, int> monthlyPerEngine = {};

      // Secondary: aggregate from daily history for the current month
      for (final day in history) {
        if (day.date.year == now.year && day.date.month == now.month) {
          day.engineTokens.forEach((engine, tokens) {
            monthlyPerEngine[engine] = (monthlyPerEngine[engine] ?? 0) + tokens;
          });
        }
      }

      // Primary: overlay with the polled totals (more accurate & up-to-date)
      final polledMonthly = src.engineMonthlyUsage;
      polledMonthly.forEach((engine, tokens) {
        if (tokens > 0) {
          monthlyPerEngine[engine] = tokens;
        }
      });

      // ── 2. Get per-engine limits from the tier config ──
      final limits = src.engineLimits(); // current tier's engine_limits map

      // ── 2.5. Inject configured engines that have no RTDB data yet ──
      // Show ALL globally-enabled engines (kill-switch only).
      // The visual enabled/disabled state is handled per-card via canUseModel().
      const knownAsr = ['online', 'riva-asr', 'whisper'];
      for (final engine in knownAsr) {
        if (!rawStats.any((s) => s.engine == engine)) {
          if (src.isModelEnabled(engine)) {
            rawStats.add(
              EngineUsage(
                engine: engine,
                totalTokens: 0,
                totalCalls: 0,
                totalInputTokens: 0,
                totalOutputTokens: 0,
                totalLatencyMs: 0,
                type: UsageType.asr,
              ),
            );
          }
        }
      }

      const knownTranslation = [
        'google',
        'google_api',
        'mymemory',
        'riva-nmt',
        'llama',
      ];
      for (final engine in knownTranslation) {
        if (!rawStats.any((s) => s.engine == engine)) {
          if (src.isModelEnabled(engine)) {
            rawStats.add(
              EngineUsage(
                engine: engine,
                totalTokens: 0,
                totalCalls: 0,
                totalInputTokens: 0,
                totalOutputTokens: 0,
                totalLatencyMs: 0,
                type: UsageType.translation,
              ),
            );
          }
        }
      }

      // ── 3. Group by (type, displayName) to merge duplicates ──
      final Map<String, EngineUsage> groupedStats = {};

      for (final s in rawStats) {
        final displayName = UsageUtils.getDisplayName(s.engine, s.type);
        final groupKey = '${s.type.name}::$displayName';

        final monthlyUsed = monthlyPerEngine[s.engine] ?? 0;
        final monthlyLimit = limits[s.engine] ?? -1;
        final inPlan = src.canUseModel(s.engine);

        if (groupedStats.containsKey(groupKey)) {
          final existing = groupedStats[groupKey]!;
          // When merging, ensure we don't corrupt the sum with -1 defaults
          final existingMonthly = existing.monthlyTokensUsed > 0
              ? existing.monthlyTokensUsed
              : 0;
          groupedStats[groupKey] = EngineUsage(
            engine: existing.engine,
            totalTokens: existing.totalTokens + s.totalTokens,
            totalCalls: existing.totalCalls + s.totalCalls,
            totalInputTokens: existing.totalInputTokens + s.totalInputTokens,
            totalOutputTokens: existing.totalOutputTokens + s.totalOutputTokens,
            totalLatencyMs: existing.totalLatencyMs + s.totalLatencyMs,
            type: s.type,
            lastUsed: _latestDate(existing.lastUsed, s.lastUsed),
            monthlyTokensUsed: existingMonthly + monthlyUsed,
            monthlyTokensLimit: monthlyLimit > 0
                ? monthlyLimit
                : existing.monthlyTokensLimit,
            isInPlan: existing.isInPlan || inPlan,
          );
        } else {
          groupedStats[groupKey] = s.copyWith(
            monthlyTokensUsed: monthlyUsed,
            monthlyTokensLimit: monthlyLimit,
            isInPlan: inPlan,
          );
        }
      }

      final stats = groupedStats.values.toList()
        ..sort((a, b) {
          // Plan-active engines first, then sort by token usage
          if (a.isInPlan != b.isInPlan) return a.isInPlan ? -1 : 1;
          return b.effectiveTokens.compareTo(a.effectiveTokens);
        });

      final asrTokens = stats
          .where((e) => e.type == UsageType.asr)
          .fold(0, (sum, e) => sum + e.effectiveTokens);

      final translationTokens = stats
          .where((e) => e.type == UsageType.translation)
          .fold(0, (sum, e) => sum + e.effectiveTokens);

      emit(
        UsageLoaded(
          engineUsage: stats,
          dailyHistory: history,
          lifetimeTokens: subStatus?.lifetimeTokensUsed ?? 0,
          monthlyTokens: subStatus?.monthlyTokensUsed ?? 0,
          asrTokens: asrTokens,
          translationTokens: translationTokens,
          tier: subStatus?.tier.toUpperCase() ?? 'FREE',
        ),
      );
    } catch (e) {
      emit(UsageError(e.toString()));
    }
  }

  DateTime? _latestDate(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }
}
