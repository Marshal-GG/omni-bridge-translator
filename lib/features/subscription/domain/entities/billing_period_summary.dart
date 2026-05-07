import 'package:equatable/equatable.dart';

/// Derived view of the current billing period for the Billing screen's Usage
/// card. Pure presentation derivation from `BillingInfo` + `QuotaStatus` —
/// holds no extra state and never hits Firestore.
class BillingPeriodSummary extends Equatable {
  /// Start of the current billing window (≈ `nextBillingAt - 30 days`). Null
  /// when there is no active subscription (free / trial without sub history).
  final DateTime? periodStart;

  /// End of the current billing window — when the next charge will land.
  /// Mirrors [BillingInfo.nextBillingAt].
  final DateTime? periodEnd;

  /// Tokens consumed in the current month (carried over from `QuotaStatus`).
  final int monthlyTokensUsed;

  /// Monthly cap for the current tier. `< 0` means unlimited (paid tiers can
  /// be configured to skip the cap entirely).
  final int monthlyTokensLimit;

  /// Daily token usage — same source as `QuotaStatus.dailyTokensUsed`.
  final int dailyTokensUsed;

  /// Daily cap for the current tier. `< 0` means unlimited.
  final int dailyTokensLimit;

  /// Requests-per-minute cap from the tier's rate limits. `0` when the plan
  /// doesn't expose a rate limit for the user (free / trial).
  final int requestsPerMinuteLimit;

  const BillingPeriodSummary({
    required this.monthlyTokensUsed,
    required this.monthlyTokensLimit,
    required this.dailyTokensUsed,
    required this.dailyTokensLimit,
    required this.requestsPerMinuteLimit,
    this.periodStart,
    this.periodEnd,
  });

  bool get isUnlimitedMonthly => monthlyTokensLimit < 0;
  bool get isUnlimitedDaily => dailyTokensLimit < 0;

  /// Monthly progress (0.0 – 1.0). Returns 0 when unlimited or limit ≤ 0.
  double get monthlyProgress {
    if (isUnlimitedMonthly || monthlyTokensLimit <= 0) return 0;
    return (monthlyTokensUsed / monthlyTokensLimit).clamp(0.0, 1.0);
  }

  /// Daily progress (0.0 – 1.0). Returns 0 when unlimited or limit ≤ 0.
  double get dailyProgress {
    if (isUnlimitedDaily || dailyTokensLimit <= 0) return 0;
    return (dailyTokensUsed / dailyTokensLimit).clamp(0.0, 1.0);
  }

  @override
  List<Object?> get props => [
    periodStart,
    periodEnd,
    monthlyTokensUsed,
    monthlyTokensLimit,
    dailyTokensUsed,
    dailyTokensLimit,
    requestsPerMinuteLimit,
  ];
}
