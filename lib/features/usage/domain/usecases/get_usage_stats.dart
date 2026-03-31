import 'package:omni_bridge/features/usage/domain/entities/engine_usage.dart';
import 'package:omni_bridge/features/usage/domain/repositories/usage_repository.dart';
import 'package:omni_bridge/features/usage/presentation/widgets/usage_utils.dart';
import 'package:omni_bridge/features/subscription/domain/repositories/i_subscription_repository.dart';
import 'package:omni_bridge/features/usage/domain/utils/usage_constants.dart';

class UsageSummary {
  final List<EngineUsage> stats;
  final int asrTokens;
  final int translationTokens;

  UsageSummary({
    required this.stats,
    required this.asrTokens,
    required this.translationTokens,
  });
}

class GetUsageStats {
  final UsageRepository _repository;
  final ISubscriptionRepository _subscriptionRepository;

  GetUsageStats(this._repository, this._subscriptionRepository);

  Future<UsageSummary> call() async {
    final rawStatsList = await _repository.getModelUsageStats();
    final rawStats = rawStatsList.toList();
    final history = await _repository.getDailyUsageHistory();

    // ── 1. Compute monthly per-engine usage ──
    final now = DateTime.now();
    final Map<String, int> monthlyPerEngine = {};

    for (final day in history) {
      if (day.date.year == now.year && day.date.month == now.month) {
        day.engineTokens.forEach((engine, tokens) {
          monthlyPerEngine[engine] = (monthlyPerEngine[engine] ?? 0) + tokens;
        });
      }
    }

    final polledMonthly = _repository.engineMonthlyUsage;
    polledMonthly.forEach((engine, tokens) {
      if (tokens > 0) {
        monthlyPerEngine[engine] = tokens;
      }
    });

    // ── 2. Get per-engine limits ──
    final limits = _subscriptionRepository.engineLimits();

    // ── 2.5. Inject configured engines ──
    _injectMissingEngines(rawStats);

    // ── 3. Group by (type, displayName) ──
    final Map<String, EngineUsage> groupedStats = {};

    for (final s in rawStats) {
      final displayName = UsageUtils.getDisplayName(s.engine, s.type);
      final groupKey = '${s.type.name}::$displayName';

      final monthlyUsed = monthlyPerEngine[s.engine] ?? 0;
      final monthlyLimit = limits[s.engine] ?? -1;
      final inPlan = _subscriptionRepository.canUseModel(s.engine);

      if (groupedStats.containsKey(groupKey)) {
        final existing = groupedStats[groupKey]!;
        final existingMonthly =
            existing.monthlyTokensUsed > 0 ? existing.monthlyTokensUsed : 0;
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
          monthlyTokensLimit:
              monthlyLimit > 0 ? monthlyLimit : existing.monthlyTokensLimit,
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

    final finalStats = groupedStats.values.toList()
      ..sort((a, b) {
        if (a.isInPlan != b.isInPlan) return a.isInPlan ? -1 : 1;
        return b.effectiveTokens.compareTo(a.effectiveTokens);
      });

    // ── 4. Calculate Summary Totals ──
    final asrTokens = finalStats
        .where((e) => e.type == UsageType.asr)
        .fold(0, (sum, e) => sum + e.effectiveTokens);

    final translationTokens = finalStats
        .where((e) => e.type == UsageType.translation)
        .fold(0, (sum, e) => sum + e.effectiveTokens);

    return UsageSummary(
      stats: finalStats,
      asrTokens: asrTokens,
      translationTokens: translationTokens,
    );
  }

  void _injectMissingEngines(List<EngineUsage> stats) {
    for (final engine in UsageConstants.knownAsrEngines) {
      if (!stats.any((s) => s.engine == engine)) {
        if (_subscriptionRepository.isModelEnabled(engine)) {
          stats.add(_emptyUsage(engine, UsageType.asr));
        }
      }
    }

    for (final engine in UsageConstants.knownTranslationEngines) {
      if (!stats.any((s) => s.engine == engine)) {
        if (_subscriptionRepository.isModelEnabled(engine)) {
          stats.add(_emptyUsage(engine, UsageType.translation));
        }
      }
    }
  }

  EngineUsage _emptyUsage(String engine, UsageType type) {
    return EngineUsage(
      engine: engine,
      totalTokens: 0,
      totalCalls: 0,
      totalInputTokens: 0,
      totalOutputTokens: 0,
      totalLatencyMs: 0,
      type: type,
    );
  }

  DateTime? _latestDate(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }
}
