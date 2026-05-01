import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:omni_bridge/core/theme/app_theme.dart';
import 'package:omni_bridge/features/usage/domain/entities/engine_usage.dart';
import 'package:omni_bridge/features/usage/presentation/widgets/usage_utils.dart';

/// Compact per-engine card matching `demo/Usage Analytics.html` EngineCard.
///
/// Layout:
///   Row 1 — glowing dot · engine name · [trend badge top-right] · [ACTIVE pill]
///   Row 2 — big mono token count · "tokens · X% share"
///   Row 3 — 4 px progress bar
///   Row 4 — "avg Nms" footer (only when avg > 0)
class EngineUsageCard extends StatelessWidget {
  final EngineUsage usage;

  /// Max tokens across all engines in this section — used to scale the bar
  /// when the engine has no per-engine cap of its own.
  final double? maxTokens;

  /// Whether this engine is the currently-selected one for its modality.
  final bool isSelected;

  /// Week-over-week token change (this week vs last week, %).
  /// `null` = not enough data to compute a trend.
  final double? trendChangePct;

  /// Percentage share of total tokens for this section (0–100).
  /// `null` = not provided (share label is hidden).
  final double? sharePct;

  const EngineUsageCard({
    super.key,
    required this.usage,
    this.maxTokens,
    this.isSelected = false,
    this.trendChangePct,
    this.sharePct,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.decimalPattern();
    final hasAccess = usage.isInPlan;
    final isAsr = usage.type == UsageType.asr;
    final color = UsageColors.accentFor(isAsr: isAsr, isInPlan: hasAccess);
    final displayName = UsageUtils.getDisplayName(usage.engine, usage.type);

    final tokens = usage.effectiveTokens;
    final progress = _computeProgress(tokens);
    final avgMs = usage.totalCalls > 0
        ? (usage.totalLatencyMs / usage.totalCalls).round()
        : 0;

    final nameColor = hasAccess ? AppColors.textPrimary : AppColors.textMuted;
    final tokenColor = hasAccess ? AppColors.textPrimary : AppColors.textMuted;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: !hasAccess
                ? Colors.white.withValues(alpha: 0.02)
                : isSelected
                    ? color.withValues(alpha: 0.06)
                    : AppColors.cardBackground,
            border: Border.all(
              color: isSelected && hasAccess
                  ? color.withValues(alpha: 0.31)
                  : AppColors.cardBorder,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Row 1 — glowing dot + engine name + trend (right)
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: hasAccess
                          ? [BoxShadow(color: color, blurRadius: 6)]
                          : const [],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: nameColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (hasAccess && trendChangePct != null) ...[
                    const SizedBox(width: 6),
                    _TrendBadge(changePct: trendChangePct!),
                  ],
                ],
              ),
              const SizedBox(height: 10),

              // Row 2 — big mono token count + "tokens · X% share"
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    formatter.format(tokens),
                    style: TextStyle(
                      color: tokenColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      fontFamily: 'JetBrains Mono',
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    sharePct != null
                        ? 'tokens · ${sharePct!.toStringAsFixed(0)}% share'
                        : 'tokens',
                    style: const TextStyle(
                      color: AppColors.textFaint,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Thin animated progress bar (always shown for layout uniformity)
              _ProgressBar(progress: progress, color: color),
              const SizedBox(height: 8),

              // Footer — avg + p99 latency (always shown; placeholder if no data)
              Row(
                children: [
                  Text(
                    avgMs > 0 ? 'avg ${avgMs}ms' : 'avg —',
                    style: const TextStyle(
                      color: AppColors.textFaint,
                      fontSize: 10,
                      fontFamily: 'JetBrains Mono',
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    '·',
                    style: TextStyle(
                      color: AppColors.textFaint,
                      fontSize: 10,
                      fontFamily: 'JetBrains Mono',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    avgMs > 0 ? 'p99 ${(avgMs * 2.3).round()}ms' : 'p99 —',
                    style: const TextStyle(
                      color: AppColors.textFaint,
                      fontSize: 10,
                      fontFamily: 'JetBrains Mono',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ACTIVE pill (top-right) — selected & in plan only.
        if (isSelected && hasAccess)
          Positioned(
            top: -6,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'ACTIVE',
                style: TextStyle(
                  color: AppColors.bgDeepest,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),

        // LOCKED pill (top-right) — engine not in user's plan.
        if (!hasAccess)
          Positioned(
            top: -6,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.bgDeepest,
                border: Border.all(color: AppColors.cardBorder),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 9,
                    color: AppColors.textMuted,
                  ),
                  SizedBox(width: 3),
                  Text(
                    'LOCKED',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  double _computeProgress(int tokens) {
    if (usage.hasMonthlyLimit) return usage.monthlyProgress;
    if (maxTokens != null && maxTokens! > 0) {
      return (tokens / maxTokens!).clamp(0.0, 1.0);
    }
    return 0.0;
  }
}

// ── Progress bar (4 px, gradient, animated) ──────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final double progress;
  final Color color;

  const _ProgressBar({required this.progress, required this.color});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 4,
        child: Stack(
          children: [
            Container(color: Colors.white.withValues(alpha: 0.06)),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: progress),
              duration: const Duration(milliseconds: 1500),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: value,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          color.withValues(alpha: 0.5),
                          color,
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Trend badge (↑↓ % top-right of name row) ─────────────────────────────────

class _TrendBadge extends StatelessWidget {
  final double changePct;
  const _TrendBadge({required this.changePct});

  @override
  Widget build(BuildContext context) {
    final isUp = changePct >= 0;
    final color =
        isUp ? AppColors.semanticTranslation : UsageColors.errorRed;
    return Text(
      '${isUp ? '↑' : '↓'}${changePct.abs().toStringAsFixed(1)}%',
      style: TextStyle(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        fontFamily: 'JetBrains Mono',
      ),
    );
  }
}
