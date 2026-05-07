import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:omni_bridge/core/theme/app_theme.dart';
import 'package:omni_bridge/core/widgets/omni_progress_bar.dart';
import 'package:omni_bridge/features/subscription/domain/entities/billing_period_summary.dart';

/// Right half of the Billing screen's hero row. Shows the current period
/// window plus monthly + daily token progress. Stays inside what BillingInfo
/// + QuotaStatus give us natively — deeper analytics live on the Usage screen.
class BillingUsageCard extends StatelessWidget {
  final BillingPeriodSummary summary;
  final Color tierAccent;

  const BillingUsageCard({
    required this.summary,
    required this.tierAccent,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM');
    final hasWindow =
        summary.periodStart != null && summary.periodEnd != null;
    final formatter = NumberFormat('#,###');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: AppShapes.md,
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'THIS BILLING PERIOD',
                style: TextStyle(
                  color: AppColors.textDisabled,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              if (hasWindow)
                Text(
                  '${fmt.format(summary.periodStart!)} – ${fmt.format(summary.periodEnd!)}',
                  style: TextStyle(
                    color: tierAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _UsageRow(
            label: 'Monthly tokens',
            used: summary.monthlyTokensUsed,
            limit: summary.monthlyTokensLimit,
            progress: summary.monthlyProgress,
            isUnlimited: summary.isUnlimitedMonthly,
            accent: tierAccent,
            formatter: formatter,
          ),
          const SizedBox(height: 14),
          _UsageRow(
            label: 'Daily tokens',
            used: summary.dailyTokensUsed,
            limit: summary.dailyTokensLimit,
            progress: summary.dailyProgress,
            isUnlimited: summary.isUnlimitedDaily,
            accent: tierAccent,
            formatter: formatter,
          ),
          if (summary.requestsPerMinuteLimit > 0) ...[
            const SizedBox(height: 14),
            _RateLimitRow(
              limit: summary.requestsPerMinuteLimit,
              accent: tierAccent,
            ),
          ],
        ],
      ),
    );
  }
}

class _UsageRow extends StatelessWidget {
  final String label;
  final int used;
  final int limit;
  final double progress;
  final bool isUnlimited;
  final Color accent;
  final NumberFormat formatter;

  const _UsageRow({
    required this.label,
    required this.used,
    required this.limit,
    required this.progress,
    required this.isUnlimited,
    required this.accent,
    required this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    final right = isUnlimited
        ? '${formatter.format(used)} · ∞'
        : '${formatter.format(used)} / ${formatter.format(limit)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              right,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        OmniProgressBar(
          progress: isUnlimited ? 0 : progress,
          color: accent,
          backgroundColor: AppColors.white(0.06),
          height: 5,
          borderRadius: 3,
          warningThreshold: isUnlimited ? null : 0.9,
        ),
      ],
    );
  }
}

class _RateLimitRow extends StatelessWidget {
  final int limit;
  final Color accent;

  const _RateLimitRow({required this.limit, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.bolt_rounded, size: 13, color: accent),
        const SizedBox(width: 8),
        const Text(
          'Rate limit',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Text(
          '$limit req/min',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
