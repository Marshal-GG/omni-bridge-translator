class SubscriptionStatus {
  final String tier;
  final int dailyTokensUsed;
  final int weeklyTokensUsed;
  final int monthlyTokensUsed;
  final int lifetimeTokensUsed;
  final int dailyLimit;
  final DateTime dailyResetAt;

  /// For time-limited tiers (e.g. trial): total token pool for the whole period.
  /// 0 = not applicable (use daily limit instead).
  final int periodLimit;

  const SubscriptionStatus({
    required this.tier,
    required this.dailyTokensUsed,
    required this.weeklyTokensUsed,
    required this.monthlyTokensUsed,
    required this.lifetimeTokensUsed,
    required this.dailyLimit,
    required this.dailyResetAt,
    this.periodLimit = 0,
  });

  bool get hasPeriodLimit => periodLimit > 0;
  bool get isUnlimited => dailyLimit < 0 && !hasPeriodLimit;
  double get progress => hasPeriodLimit
      ? (periodLimit <= 0 ? 0 : monthlyTokensUsed / periodLimit)
      : (dailyLimit <= 0 ? 0 : dailyTokensUsed / dailyLimit);
  bool get isExceeded =>
      (hasPeriodLimit && monthlyTokensUsed >= periodLimit) ||
      (!isUnlimited && !hasPeriodLimit && dailyTokensUsed >= dailyLimit);

  SubscriptionStatus copyWith({
    String? tier,
    int? dailyTokensUsed,
    int? weeklyTokensUsed,
    int? monthlyTokensUsed,
    int? lifetimeTokensUsed,
    int? dailyLimit,
    DateTime? dailyResetAt,
    int? periodLimit,
  }) {
    return SubscriptionStatus(
      tier: tier ?? this.tier,
      dailyTokensUsed: dailyTokensUsed ?? this.dailyTokensUsed,
      weeklyTokensUsed: weeklyTokensUsed ?? this.weeklyTokensUsed,
      monthlyTokensUsed: monthlyTokensUsed ?? this.monthlyTokensUsed,
      lifetimeTokensUsed: lifetimeTokensUsed ?? this.lifetimeTokensUsed,
      dailyLimit: dailyLimit ?? this.dailyLimit,
      dailyResetAt: dailyResetAt ?? this.dailyResetAt,
      periodLimit: periodLimit ?? this.periodLimit,
    );
  }
}
