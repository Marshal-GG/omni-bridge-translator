import 'package:omni_bridge/features/usage/domain/repositories/usage_repository.dart';
import 'package:omni_bridge/features/subscription/domain/repositories/i_subscription_repository.dart';

class CheckUsageRollover {
  final UsageRepository _repository;
  final ISubscriptionRepository _subscriptionRepository;

  CheckUsageRollover(this._repository, this._subscriptionRepository);

  Future<void> call() async {
    final totals = await _repository.getUsageTotals();
    if (totals.isEmpty) return;

    final now = DateTime.now();

    // 1. Calendar Rollover (Monthly token bucket)
    final currentMonthStr = '${now.year}_${now.month.toString().padLeft(2, '0')}';
    final lastCalendarMonth = totals['last_calendar_month'] as String? ?? currentMonthStr;

    if (currentMonthStr != lastCalendarMonth) {
      final calendarUsed = (totals['calendar_monthly'] as num?)?.toInt() ?? 0;
      await _repository.rolloverCalendar(lastCalendarMonth, calendarUsed);
    }

    // 2. Weekly Rollover
    final currentMonday = now.subtract(Duration(days: now.weekday - 1));
    final currentWeekStr = '${currentMonday.year}_${currentMonday.month.toString().padLeft(2, '0')}_${currentMonday.day.toString().padLeft(2, '0')}';
    final lastWeekStr = totals['last_week'] as String? ?? currentWeekStr;

    if (currentWeekStr != lastWeekStr) {
      final weeklyUsed = (totals['weekly'] as num?)?.toInt() ?? 0;
      await _repository.rolloverWeekly(lastWeekStr, weeklyUsed, currentWeekStr);
    }

    // 3. Subscription Rollover (Paid tiers only)
    final status = _subscriptionRepository.currentStatus;
    if (status != null && status.tier != _subscriptionRepository.defaultTier) {
      final monthlyResetAt = status.monthlyResetAt;
      if (monthlyResetAt != null && now.isAfter(monthlyResetAt)) {
        final subUsed = (totals['subscription_monthly'] as num?)?.toInt() ?? 0;
        final cycleLabel = '${monthlyResetAt.subtract(const Duration(days: 30)).toIso8601String().split('T')[0]}__${monthlyResetAt.toIso8601String().split('T')[0]}';

        DateTime nextReset = monthlyResetAt;
        while (now.isAfter(nextReset)) {
          nextReset = nextReset.add(const Duration(days: 30));
        }

        await _repository.rolloverSubscription(cycleLabel, subUsed, nextReset);
      }
    }
  }
}
