import 'package:equatable/equatable.dart';

class QuotaStatus extends Equatable {
  final String tier;
  final int dailyTokensUsed;
  final int weeklyTokensUsed;
  final int monthlyTokensUsed;
  final int lifetimeTokensUsed;
  final int dailyLimit;
  final int monthlyLimit;
  final DateTime dailyResetAt;

  /// For time-limited tiers (e.g. trial): total token pool for the whole period.
  /// 0 = not applicable (use daily limit instead).
  final int periodLimit;

  const QuotaStatus({
    required this.tier,
    required this.dailyTokensUsed,
    required this.weeklyTokensUsed,
    required this.monthlyTokensUsed,
    required this.lifetimeTokensUsed,
    required this.dailyLimit,
    required this.dailyResetAt,
    this.monthlyResetAt,
    this.monthlyLimit = 0,
    this.periodLimit = 0,
  });

  /// The next date/time the monthly subscription quota will reset (paid only).
  final DateTime? monthlyResetAt;

  bool get hasPeriodLimit => periodLimit > 0;
  bool get hasMonthlyLimit => monthlyLimit > 0;
  bool get isUnlimited => dailyLimit < 0 && !hasPeriodLimit && !hasMonthlyLimit;

  double get progress => hasPeriodLimit
      ? (periodLimit <= 0 ? 0 : monthlyTokensUsed / periodLimit)
      : hasMonthlyLimit
          ? (monthlyLimit <= 0 ? 0 : monthlyTokensUsed / monthlyLimit)
          : (dailyLimit <= 0 ? 0 : dailyTokensUsed / dailyLimit);

  bool get isDailyExceeded =>
      !isUnlimited && !hasPeriodLimit && dailyLimit > 0 && dailyTokensUsed >= dailyLimit;

  bool get isMonthlyExceeded =>
      hasMonthlyLimit && monthlyTokensUsed >= monthlyLimit;

  bool get isExceeded =>
      (hasPeriodLimit && monthlyTokensUsed >= periodLimit) ||
      isDailyExceeded ||
      isMonthlyExceeded;

  /// Remaining daily tokens (0 if exceeded or unlimited).
  int get dailyRemaining =>
      dailyLimit > 0 ? (dailyLimit - dailyTokensUsed).clamp(0, dailyLimit) : 0;

  /// Remaining monthly tokens (0 if exceeded or no monthly limit).
  int get monthlyRemaining =>
      monthlyLimit > 0 ? (monthlyLimit - monthlyTokensUsed).clamp(0, monthlyLimit) : 0;

  QuotaStatus copyWith({
    String? tier,
    int? dailyTokensUsed,
    int? weeklyTokensUsed,
    int? monthlyTokensUsed,
    int? lifetimeTokensUsed,
    int? dailyLimit,
    int? monthlyLimit,
    DateTime? dailyResetAt,
    int? periodLimit,
  }) {
    return QuotaStatus(
      tier: tier ?? this.tier,
      dailyTokensUsed: dailyTokensUsed ?? this.dailyTokensUsed,
      weeklyTokensUsed: weeklyTokensUsed ?? this.weeklyTokensUsed,
      monthlyTokensUsed: monthlyTokensUsed ?? this.monthlyTokensUsed,
      lifetimeTokensUsed: lifetimeTokensUsed ?? this.lifetimeTokensUsed,
      dailyLimit: dailyLimit ?? this.dailyLimit,
      monthlyLimit: monthlyLimit ?? this.monthlyLimit,
      dailyResetAt: dailyResetAt ?? this.dailyResetAt,
      periodLimit: periodLimit ?? this.periodLimit,
    );
  }

  @override
  List<Object?> get props => [
        tier,
        dailyTokensUsed,
        weeklyTokensUsed,
        monthlyTokensUsed,
        lifetimeTokensUsed,
        dailyLimit,
        monthlyLimit,
        dailyResetAt,
        monthlyResetAt,
        periodLimit,
      ];
}
