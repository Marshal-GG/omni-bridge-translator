import 'package:omni_bridge/features/usage/domain/entities/quota_status.dart';
import '../entities/billing_info.dart';
import '../entities/billing_period_summary.dart';
import '../entities/subscription_plan.dart';
import '../repositories/i_subscription_repository.dart';

/// Derives [BillingPeriodSummary] from the current `BillingInfo` + `QuotaStatus`
/// + the active tier's `SubscriptionPlan`. All three inputs are already in
/// memory on the Subscription repository, so no additional I/O happens.
///
/// Period start is approximated as `nextBillingAt - 30 days` because the app
/// only supports monthly Razorpay subscriptions today (per
/// `docs/04_features/16_monetization_plan.md`). Yearly cycles need a different
/// derivation if/when they're added.
class GetBillingPeriodSummary {
  final ISubscriptionRepository _repository;

  GetBillingPeriodSummary(this._repository);

  BillingPeriodSummary call({BillingInfo? billingInfoOverride}) {
    final billing = billingInfoOverride ?? _repository.billingInfoNotifier.value;
    final status = _repository.currentStatus;
    final plan = _planFor(billing.tier);

    final end = billing.nextBillingAt;
    final start = end?.subtract(const Duration(days: 30));

    return BillingPeriodSummary(
      periodStart: start,
      periodEnd: end,
      monthlyTokensUsed: status?.monthlyTokensUsed ?? 0,
      monthlyTokensLimit: plan?.monthlyTokens ?? 0,
      dailyTokensUsed: status?.dailyTokensUsed ?? 0,
      dailyTokensLimit:
          plan?.dailyTokens ?? (status?.dailyLimit ?? 0),
      requestsPerMinuteLimit: plan?.requestsPerMinute ?? 0,
    );
  }

  SubscriptionPlan? _planFor(String tier) {
    for (final plan in _repository.availablePlans) {
      if (plan.id == tier) return plan;
    }
    return null;
  }
}

/// Test-friendly variant that accepts already-resolved values directly. Avoids
/// having to mock the whole repository when all you want to test is the
/// derivation arithmetic.
BillingPeriodSummary deriveBillingPeriodSummary({
  required BillingInfo billing,
  required QuotaStatus? status,
  required SubscriptionPlan? plan,
}) {
  final end = billing.nextBillingAt;
  final start = end?.subtract(const Duration(days: 30));

  return BillingPeriodSummary(
    periodStart: start,
    periodEnd: end,
    monthlyTokensUsed: status?.monthlyTokensUsed ?? 0,
    monthlyTokensLimit: plan?.monthlyTokens ?? 0,
    dailyTokensUsed: status?.dailyTokensUsed ?? 0,
    dailyTokensLimit:
        plan?.dailyTokens ?? (status?.dailyLimit ?? 0),
    requestsPerMinuteLimit: plan?.requestsPerMinute ?? 0,
  );
}
