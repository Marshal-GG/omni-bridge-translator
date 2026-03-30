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

      // ── 1. Compute monthly per-engine usage from daily history ──
      final now = DateTime.now();
      final Map<String, int> monthlyPerEngine = {};

      for (final day in history) {
        if (day.date.year == now.year && day.date.month == now.month) {
          day.engineTokens.forEach((engine, tokens) {
            monthlyPerEngine[engine] =
                (monthlyPerEngine[engine] ?? 0) + tokens;
          });
        }
      }

      // ── 2. Get per-engine limits from the tier config ──
      final src = SubscriptionRemoteDataSource.instance;
      final limits = src.engineLimits(); // current tier's engine_limits map

      // ── 2.5. Inject configured engines that have no RTDB data yet ──
      final configuredEngines = src.getConfiguredEngines();
      for (final engine in configuredEngines) {
        if (!rawStats.any((s) => s.engine == engine)) {
          final typeStr = src.getModelType(engine);
          UsageType type = UsageType.unknown;
          if (typeStr == 'asr') {
            type = UsageType.asr;
          } else if (typeStr == 'translation') {
            type = UsageType.translation;
          }

          if (type != UsageType.unknown) {
            rawStats.add(EngineUsage(
              engine: engine,
              totalTokens: 0,
              totalCalls: 0,
              totalInputTokens: 0,
              totalOutputTokens: 0,
              totalLatencyMs: 0,
              type: type,
            ));
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

        if (groupedStats.containsKey(groupKey)) {
          final existing = groupedStats[groupKey]!;
          groupedStats[groupKey] = EngineUsage(
            engine: existing.engine,
            totalTokens: existing.totalTokens + s.totalTokens,
            totalCalls: existing.totalCalls + s.totalCalls,
            totalInputTokens: existing.totalInputTokens + s.totalInputTokens,
            totalOutputTokens: existing.totalOutputTokens + s.totalOutputTokens,
            totalLatencyMs: existing.totalLatencyMs + s.totalLatencyMs,
            type: s.type,
            lastUsed: _latestDate(existing.lastUsed, s.lastUsed),
            monthlyTokensUsed: existing.monthlyTokensUsed + monthlyUsed,
            monthlyTokensLimit: monthlyLimit > 0
                ? monthlyLimit
                : existing.monthlyTokensLimit,
          );
        } else {
          groupedStats[groupKey] = s.copyWith(
            monthlyTokensUsed: monthlyUsed,
            monthlyTokensLimit: monthlyLimit,
          );
        }
      }

      final stats = groupedStats.values.toList()
        ..sort((a, b) => b.effectiveTokens.compareTo(a.effectiveTokens));

      final asrTokens = stats
          .where((e) => e.type == UsageType.asr)
          .fold(0, (sum, e) => sum + e.effectiveTokens);

      final translationTokens = stats
          .where((e) => e.type == UsageType.translation)
          .fold(0, (sum, e) => sum + e.effectiveTokens);

      emit(UsageLoaded(
        engineUsage: stats,
        dailyHistory: history,
        lifetimeTokens: subStatus?.lifetimeTokensUsed ?? 0,
        monthlyTokens: subStatus?.monthlyTokensUsed ?? 0,
        asrTokens: asrTokens,
        translationTokens: translationTokens,
        tier: subStatus?.tier.toUpperCase() ?? 'FREE',
      ));
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
