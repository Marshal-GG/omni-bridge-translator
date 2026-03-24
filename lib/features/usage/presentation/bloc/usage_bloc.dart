import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omni_bridge/features/usage/domain/entities/engine_usage.dart';
import 'package:omni_bridge/features/usage/domain/repositories/usage_repository.dart';
import 'package:omni_bridge/features/usage/presentation/bloc/usage_event.dart';
import 'package:omni_bridge/features/usage/presentation/bloc/usage_state.dart';

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
      final stats = await _usageRepository.getModelUsageStats();
      final history = await _usageRepository.getDailyUsageHistory();
      final subStatus = await _usageRepository.getSubscriptionStatus();

      final asrTokens = stats
          .where((e) => e.type == UsageType.asr)
          .fold(0, (sum, e) => sum + e.totalTokens);
          
      final translationTokens = stats
          .where((e) => e.type == UsageType.translation)
          .fold(0, (sum, e) => sum + e.totalTokens);

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
}
