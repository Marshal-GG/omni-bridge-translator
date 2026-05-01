import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:omni_bridge/core/theme/app_theme.dart';
import 'package:omni_bridge/features/usage/domain/entities/daily_usage_record.dart';

/// Four stat cards — TODAY / THIS WEEK / THIS MONTH / LIFETIME — each with a
/// left color bar, big value, trend badge, and a real sparkline from daily history.
/// No mock data: sparkline points come from [dailyHistory.totalTokens].
class StatCardsGrid extends StatelessWidget {
  final int todayTokens;
  final int weeklyTokens;
  final int monthlyTokens;
  final int lifetimeTokens;
  final List<DailyUsageRecord> dailyHistory;

  const StatCardsGrid({
    super.key,
    required this.todayTokens,
    required this.weeklyTokens,
    required this.monthlyTokens,
    required this.lifetimeTokens,
    required this.dailyHistory,
  });

  @override
  Widget build(BuildContext context) {
    final sparkPoints = _sparkPoints(dailyHistory);
    final trends = _computeTrends(dailyHistory);

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'TODAY',
            value: todayTokens,
            trendLabel: 'vs yesterday',
            trendPct: trends['today'],
            color: AppColors.splashBlue,
            spark: sparkPoints,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'THIS WEEK',
            value: weeklyTokens,
            trendLabel: 'vs last week',
            trendPct: trends['week'],
            color: UsageColors.asrAccent,
            spark: sparkPoints,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'THIS MONTH',
            value: monthlyTokens,
            trendLabel: 'vs last month',
            trendPct: trends['month'],
            color: UsageColors.translationAccent,
            spark: sparkPoints,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'LIFETIME',
            value: lifetimeTokens,
            trendLabel: null,
            trendPct: null,
            color: AppColors.amber,
            spark: sparkPoints,
          ),
        ),
      ],
    );
  }

  static List<double> _sparkPoints(List<DailyUsageRecord> history) {
    if (history.isEmpty) return [];
    const maxPoints = 20;
    final src =
        history.length > maxPoints
            ? history.sublist(history.length - maxPoints)
            : history;
    return src.map((d) => d.totalTokens.toDouble()).toList();
  }

  static Map<String, double?> _computeTrends(
    List<DailyUsageRecord> history,
  ) {
    final now = DateTime.now();
    int today = 0, yesterday = 0;
    int thisWeek = 0, lastWeek = 0;
    int thisMonth = 0, lastMonth = 0;

    final prevMonthNum = now.month == 1 ? 12 : now.month - 1;
    final prevMonthYear = now.month == 1 ? now.year - 1 : now.year;

    for (final r in history) {
      final daysAgo = now.difference(r.date).inDays;
      if (daysAgo == 0) today += r.totalTokens;
      if (daysAgo == 1) yesterday += r.totalTokens;
      if (daysAgo < 7) thisWeek += r.totalTokens;
      if (daysAgo >= 7 && daysAgo < 14) lastWeek += r.totalTokens;
      if (r.date.year == now.year && r.date.month == now.month) {
        thisMonth += r.totalTokens;
      }
      if (r.date.year == prevMonthYear && r.date.month == prevMonthNum) {
        lastMonth += r.totalTokens;
      }
    }

    double? pct(int current, int previous) {
      if (previous == 0) return null;
      return (current - previous) / previous * 100;
    }

    return {
      'today': pct(today, yesterday),
      'week': pct(thisWeek, lastWeek),
      'month': pct(thisMonth, lastMonth),
    };
  }
}

// ── Single stat card ──────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final double? trendPct;
  final String? trendLabel;
  final Color color;
  final List<double> spark;

  const _StatCard({
    required this.label,
    required this.value,
    required this.trendPct,
    required this.trendLabel,
    required this.color,
    required this.spark,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.compact();
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Left accent bar
          Positioned(
            left: -18,
            top: -16,
            bottom: -14,
            child: Container(
              width: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [color, color.withValues(alpha: 0.19)],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textFaint,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    fmt.format(value),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      fontFamily: 'JetBrains Mono',
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'tokens',
                    style: TextStyle(
                      color: AppColors.textFaint,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (trendPct != null && trendLabel != null) ...[
                Row(
                  children: [
                    Text(
                      '${trendPct! >= 0 ? '↑' : '↓'} ${trendPct!.abs().toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: trendPct! >= 0
                            ? AppColors.semanticTranslation
                            : UsageColors.errorRed,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'JetBrains Mono',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      trendLabel!,
                      style: const TextStyle(
                        color: AppColors.textFaint,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ] else if (trendLabel != null) ...[
                Text(
                  trendLabel!,
                  style: const TextStyle(
                    color: AppColors.textFaint,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 10),
              ] else ...[
                const SizedBox(height: 10),
              ],
              if (spark.isNotEmpty)
                _Sparkline(points: spark, color: color),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Sparkline (CustomPainter from real daily history) ─────────────────────────

class _Sparkline extends StatelessWidget {
  final List<double> points;
  final Color color;

  const _Sparkline({required this.points, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: CustomPaint(
        painter: _SparklinePainter(points: points, color: color),
        size: Size.infinite,
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> points;
  final Color color;

  const _SparklinePainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final mn = points.reduce(math.min);
    final mx = points.reduce(math.max);
    final range = mx - mn;

    double xAt(int i) => (i / (points.length - 1)) * size.width;
    double yAt(double v) =>
        range > 0 ? size.height - ((v - mn) / range) * size.height : size.height / 2;

    final path = Path();
    path.moveTo(xAt(0), yAt(points[0]));
    for (int i = 1; i < points.length; i++) {
      path.lineTo(xAt(i), yAt(points[i]));
    }

    // Fill
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.4), color.withValues(alpha: 0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Line
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      !listEquals(old.points, points) || old.color != color;
}
