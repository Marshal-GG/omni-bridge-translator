import 'package:flutter_test/flutter_test.dart';
import 'package:omni_bridge/features/subscription/domain/entities/billing_info.dart';
import 'package:omni_bridge/features/subscription/domain/entities/subscription_plan.dart';
import 'package:omni_bridge/features/subscription/domain/usecases/get_billing_period_summary.dart';
import 'package:omni_bridge/features/usage/domain/entities/quota_status.dart';

void main() {
  group('deriveBillingPeriodSummary', () {
    final periodEnd = DateTime(2026, 6, 1);
    final billing = BillingInfo(
      tier: 'pro',
      status: 'active',
      subscriptionId: 'sub_X',
      since: DateTime(2026, 1, 1),
      nextBillingAt: periodEnd,
    );
    final proPlan = const SubscriptionPlan(
      id: 'pro',
      name: 'Pro',
      price: '₹799',
      description: '',
      features: [],
      dailyTokens: 50000,
      monthlyTokens: 1000000,
      requestsPerMinute: 60,
    );
    final status = QuotaStatus(
      tier: 'pro',
      dailyTokensUsed: 12500,
      weeklyTokensUsed: 0,
      monthlyTokensUsed: 250000,
      lifetimeTokensUsed: 0,
      dailyLimit: 50000,
      monthlyLimit: 1000000,
      dailyResetAt: DateTime(2026, 5, 8),
    );

    test('derives a 30-day window ending at nextBillingAt', () {
      final summary = deriveBillingPeriodSummary(
        billing: billing,
        status: status,
        plan: proPlan,
      );

      expect(summary.periodEnd, periodEnd);
      expect(summary.periodStart, periodEnd.subtract(const Duration(days: 30)));
    });

    test('carries token usage from QuotaStatus', () {
      final summary = deriveBillingPeriodSummary(
        billing: billing,
        status: status,
        plan: proPlan,
      );

      expect(summary.monthlyTokensUsed, 250000);
      expect(summary.monthlyTokensLimit, 1000000);
      expect(summary.dailyTokensUsed, 12500);
      expect(summary.dailyTokensLimit, 50000);
    });

    test('monthly progress is used / limit, clamped to 1.0', () {
      final summary = deriveBillingPeriodSummary(
        billing: billing,
        status: status,
        plan: proPlan,
      );

      expect(summary.monthlyProgress, closeTo(0.25, 1e-9));
    });

    test('clamps progress at 1.0 when usage exceeds the cap', () {
      final overusedStatus = status.copyWith(
        monthlyTokensUsed: 5000000, // 5x cap
      );

      final summary = deriveBillingPeriodSummary(
        billing: billing,
        status: overusedStatus,
        plan: proPlan,
      );

      expect(summary.monthlyProgress, 1.0);
    });

    test('flags unlimited monthly when plan limit < 0', () {
      final unlimitedPlan = const SubscriptionPlan(
        id: 'enterprise',
        name: 'Enterprise',
        price: '₹4,999',
        description: '',
        features: [],
        dailyTokens: -1,
        monthlyTokens: -1,
        requestsPerMinute: 240,
      );

      final summary = deriveBillingPeriodSummary(
        billing: billing,
        status: status,
        plan: unlimitedPlan,
      );

      expect(summary.isUnlimitedMonthly, isTrue);
      expect(summary.isUnlimitedDaily, isTrue);
      expect(summary.monthlyProgress, 0);
      expect(summary.dailyProgress, 0);
    });

    test('returns null period when nextBillingAt is missing', () {
      final freeBilling = const BillingInfo(tier: 'free', status: 'none');

      final summary = deriveBillingPeriodSummary(
        billing: freeBilling,
        status: null,
        plan: null,
      );

      expect(summary.periodStart, isNull);
      expect(summary.periodEnd, isNull);
      expect(summary.monthlyTokensUsed, 0);
      expect(summary.monthlyTokensLimit, 0);
    });

    test('falls back to QuotaStatus.dailyLimit when plan is missing', () {
      final summary = deriveBillingPeriodSummary(
        billing: billing,
        status: status,
        plan: null,
      );

      expect(summary.dailyTokensLimit, 50000);
    });
  });
}
