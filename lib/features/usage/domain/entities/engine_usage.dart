import 'package:equatable/equatable.dart';

enum UsageType { asr, translation, unknown }

class EngineUsage extends Equatable {
  final String engine;
  final int totalTokens;
  final int totalCalls;
  final int totalInputTokens;
  final int totalOutputTokens;
  final int totalLatencyMs;
  final DateTime? lastUsed;
  final UsageType type;

  /// Monthly usage for this engine (aggregated from daily_usage this month).
  /// -1 = not yet computed.
  final int monthlyTokensUsed;

  /// Monthly per-engine cap from engine_limits in the tier config.
  /// -1 = no per-engine cap (follows overall quota only).
  final int monthlyTokensLimit;

  /// Whether this engine is included in the user's current subscription plan.
  /// Computed at load time by the bloc; used by the UI for enabled/disabled state.
  final bool isInPlan;

  const EngineUsage({
    required this.engine,
    required this.totalTokens,
    required this.totalCalls,
    required this.totalInputTokens,
    required this.totalOutputTokens,
    required this.totalLatencyMs,
    required this.type,
    this.lastUsed,
    this.monthlyTokensUsed = -1,
    this.monthlyTokensLimit = -1,
    this.isInPlan = false,
  });

  double get averageLatencyMs => totalCalls > 0 ? totalLatencyMs / totalCalls : 0;

  /// Tokens to use for display and sorting.
  /// Many engines (e.g. google, riva, mymemory) write to total_input_tokens /
  /// total_output_tokens and leave total_tokens = 0. Fall back to their sum.
  int get effectiveTokens =>
      totalTokens > 0 ? totalTokens : totalInputTokens + totalOutputTokens;

  /// Whether this engine has a per-engine monthly cap.
  bool get hasMonthlyLimit => monthlyTokensLimit > 0;

  /// Monthly usage progress (0.0–1.0), or 0.0 if no limit.
  double get monthlyProgress => hasMonthlyLimit
      ? (monthlyTokensUsed / monthlyTokensLimit).clamp(0.0, 1.0)
      : 0.0;

  /// Whether the monthly per-engine cap has been reached.
  bool get isMonthlyLimitExceeded =>
      hasMonthlyLimit && monthlyTokensUsed >= monthlyTokensLimit;

  EngineUsage copyWith({
    String? engine,
    int? totalTokens,
    int? totalCalls,
    int? totalInputTokens,
    int? totalOutputTokens,
    int? totalLatencyMs,
    DateTime? lastUsed,
    UsageType? type,
    int? monthlyTokensUsed,
    int? monthlyTokensLimit,
    bool? isInPlan,
  }) {
    return EngineUsage(
      engine: engine ?? this.engine,
      totalTokens: totalTokens ?? this.totalTokens,
      totalCalls: totalCalls ?? this.totalCalls,
      totalInputTokens: totalInputTokens ?? this.totalInputTokens,
      totalOutputTokens: totalOutputTokens ?? this.totalOutputTokens,
      totalLatencyMs: totalLatencyMs ?? this.totalLatencyMs,
      lastUsed: lastUsed ?? this.lastUsed,
      type: type ?? this.type,
      monthlyTokensUsed: monthlyTokensUsed ?? this.monthlyTokensUsed,
      monthlyTokensLimit: monthlyTokensLimit ?? this.monthlyTokensLimit,
      isInPlan: isInPlan ?? this.isInPlan,
    );
  }

  @override
  List<Object?> get props => [
        engine,
        totalTokens,
        totalCalls,
        totalInputTokens,
        totalOutputTokens,
        totalLatencyMs,
        lastUsed,
        type,
        monthlyTokensUsed,
        monthlyTokensLimit,
        isInPlan,
      ];
}
