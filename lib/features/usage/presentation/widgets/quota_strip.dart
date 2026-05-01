import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:omni_bridge/core/theme/app_theme.dart';
import 'package:omni_bridge/features/usage/domain/entities/quota_status.dart';

/// Two-bar quota strip matching `demo/Usage Analytics.html` QuotaStrip.
///
/// Layout:
///   Header row: PRO PLAN pill · label · spacer · reset info · Upgrade button
///   Two-column grid: Daily bar (amber) | Monthly bar (teal)
class QuotaStrip extends StatelessWidget {
  final QuotaStatus quota;
  final int monthlyTokens;
  final int lifetimeTokens;

  const QuotaStrip({
    super.key,
    required this.quota,
    required this.monthlyTokens,
    required this.lifetimeTokens,
  });

  @override
  Widget build(BuildContext context) {
    final tier = quota.tier.isNotEmpty ? quota.tier.toUpperCase() : 'FREE';
    final dailyLimit = quota.dailyLimit;
    // Prefer the actual monthly cap; fall back to trial period pool; -1 = unlimited.
    final monthlyLimit = quota.hasMonthlyLimit
        ? quota.monthlyLimit
        : quota.hasPeriodLimit
            ? quota.periodLimit
            : -1;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accentTeal.withValues(alpha: 0.07),
            AppColors.accentTeal.withValues(alpha: 0.01),
          ],
        ),
        border: Border.all(color: AppColors.accentTeal.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ──
          Row(
            children: [
              _PlanPill(tier: tier),
              const SizedBox(width: 14),
              const Text(
                'Translation quota · daily + monthly',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              Text(
                _resetInfoText(quota),
                style: const TextStyle(
                  color: AppColors.textFaint,
                  fontSize: 10,
                  fontFamily: 'JetBrains Mono',
                ),
              ),
              const SizedBox(width: 12),
              _UpgradeButton(),
            ],
          ),
          const SizedBox(height: 14),

          // ── Two-bar grid ──
          Row(
            children: [
              Expanded(
                child: _QuotaBar(
                  label: 'TODAY',
                  color: AppColors.amber,
                  glowColor: AppColors.amber,
                  used: quota.dailyTokensUsed,
                  max: dailyLimit,
                  gradientColors: [
                    AppColors.amber.withValues(alpha: 0.67),
                    AppColors.amber,
                    AppColors.orange.withValues(alpha: 0.9),
                  ],
                ),
              ),
              const SizedBox(width: 22),
              Expanded(
                child: _QuotaBar(
                  label: 'THIS MONTH',
                  color: AppColors.accentTeal,
                  glowColor: AppColors.accentTeal,
                  used: monthlyTokens,
                  max: monthlyLimit,
                  gradientColors: [
                    AppColors.semanticAsr.withValues(alpha: 0.9),
                    AppColors.accentTeal,
                    AppColors.translationTeal.withValues(alpha: 0.9),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _resetInfoText(QuotaStatus q) {
    final parts = <String>[];
    if (q.monthlyResetAt != null) {
      final remaining = q.monthlyResetAt!.difference(DateTime.now());
      if (!remaining.isNegative) {
        parts.add('Monthly resets in ${remaining.inDays}d');
      }
    }
    final dailyRemaining = q.dailyResetAt.difference(DateTime.now());
    if (!dailyRemaining.isNegative) {
      final h = dailyRemaining.inHours;
      final m = dailyRemaining.inMinutes % 60;
      parts.add('Daily resets in ${h}h ${m}m');
    }
    return parts.join(' · ');
  }
}

// ── Plan pill ──────────────────────────────────────────────────────────────

class _PlanPill extends StatelessWidget {
  final String tier;
  const _PlanPill({required this.tier});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.accentTeal.withValues(alpha: 0.13),
        border: Border.all(color: AppColors.accentTeal.withValues(alpha: 0.31)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, size: 12, color: AppColors.accentTeal),
          const SizedBox(width: 6),
          Text(
            '$tier PLAN',
            style: const TextStyle(
              color: AppColors.accentTeal,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Upgrade button ─────────────────────────────────────────────────────────

class _UpgradeButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accentTeal,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'Upgrade →',
        style: TextStyle(
          color: AppColors.bgDeepest,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ── Individual quota bar ───────────────────────────────────────────────────

class _QuotaBar extends StatelessWidget {
  final String label;
  final Color color;
  final Color glowColor;
  final int used;
  final int max;
  final List<Color> gradientColors;

  const _QuotaBar({
    required this.label,
    required this.color,
    required this.glowColor,
    required this.used,
    required this.max,
    required this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (max > 0) ? (used / max).clamp(0.0, 1.0) : 0.0;
    final isWarn = pct >= 0.8;
    final valueColor = isWarn ? AppColors.amber : color;
    final fmt = NumberFormat.decimalPattern();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label + pct
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const Spacer(),
            Text(
              max > 0 ? '${(pct * 100).toStringAsFixed(1)}%' : '–',
              style: TextStyle(
                color: valueColor,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                fontFamily: 'JetBrains Mono',
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Token count
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              fmt.format(used),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                fontFamily: 'JetBrains Mono',
              ),
            ),
            const SizedBox(width: 6),
            Text(
              max > 0 ? '/ ${fmt.format(max)} tokens' : 'tokens',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Progress bar with shimmer
        _ShimmerBar(
          progress: pct,
          gradientColors: gradientColors,
          glowColor: glowColor,
        ),
      ],
    );
  }
}

// ── Shimmer progress bar ───────────────────────────────────────────────────

class _ShimmerBar extends StatefulWidget {
  final double progress;
  final List<Color> gradientColors;
  final Color glowColor;

  const _ShimmerBar({
    required this.progress,
    required this.gradientColors,
    required this.glowColor,
  });

  @override
  State<_ShimmerBar> createState() => _ShimmerBarState();
}

class _ShimmerBarState extends State<_ShimmerBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 7,
        child: Stack(
          children: [
            Container(color: Colors.white.withValues(alpha: 0.06)),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: widget.progress),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: value,
                  child: AnimatedBuilder(
                    animation: _shimmer,
                    builder: (context, _) {
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: widget.gradientColors,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: widget.glowColor.withValues(alpha: 0.4),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: ClipRect(
                          child: Align(
                            alignment: Alignment(
                              -1.0 + _shimmer.value * 3.0,
                              0,
                            ),
                            child: FractionallySizedBox(
                              widthFactor: 0.3,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      Colors.white.withValues(alpha: 0.35),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
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
