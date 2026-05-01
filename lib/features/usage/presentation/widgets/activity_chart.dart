import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:omni_bridge/core/constants/engine_registry.dart';
import 'package:omni_bridge/core/theme/app_theme.dart';
import 'package:omni_bridge/features/usage/domain/entities/daily_usage_record.dart';

/// 30-day stacked bar chart (ASR indigo / Translation teal) with hover and
/// a summary row (active days, average, peak). Real data from [dailyHistory];
/// no mock data.
class ActivityChart extends StatefulWidget {
  final List<DailyUsageRecord> dailyHistory;

  const ActivityChart({super.key, required this.dailyHistory});

  @override
  State<ActivityChart> createState() => _ActivityChartState();
}

class _ActivityChartState extends State<ActivityChart> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    final data = _buildChartData(widget.dailyHistory);
    if (data.isEmpty) {
      return _EmptyChart();
    }

    final maxTotal = data.map((d) => d.asr + d.nmt).reduce(math.max);
    final gridMax = _niceMax(maxTotal);
    final activeDays = data.where((d) => d.asr + d.nmt > 0).length;
    final totalTokens = data.fold<int>(0, (s, d) => s + d.asr + d.nmt);
    final avg =
        activeDays > 0 ? (totalTokens / activeDays).round() : 0;
    final peakEntry = data.reduce(
      (best, d) => (d.asr + d.nmt) > (best.asr + best.nmt) ? d : best,
    );

    final hovered =
        _hoveredIndex != null ? data[_hoveredIndex!] : null;

    return Container(
      padding: const EdgeInsets.all(18),
      height: 280,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Text(
                'Daily Activity',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 12),
              _Chip('TOKENS / DAY', UsageColors.asrAccent),
              const Spacer(),
              _Legend(color: UsageColors.asrAccent, label: 'ASR'),
              const SizedBox(width: 12),
              _Legend(
                color: UsageColors.translationAccent,
                label: 'Translation',
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Summary row
          DefaultTextStyle(
            style: const TextStyle(
              color: AppColors.textFaint,
              fontSize: 10,
              fontFamily: 'JetBrains Mono',
            ),
            child: Row(
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      color: AppColors.textFaint,
                      fontSize: 10,
                      fontFamily: 'JetBrains Mono',
                    ),
                    children: [
                      TextSpan(
                        text: '$activeDays',
                        style: const TextStyle(
                          color: AppColors.semanticTranslation,
                        ),
                      ),
                      TextSpan(text: '/${data.length} active days'),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Text('avg '),
                Text(
                  NumberFormat.compact().format(avg),
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                const SizedBox(width: 16),
                Text('peak '),
                Text(
                  NumberFormat.compact().format(peakEntry.asr + peakEntry.nmt),
                  style: const TextStyle(color: AppColors.amber),
                ),
                Text(' · ${_dateLabel(peakEntry.date)}'),
                const Spacer(),
                if (hovered != null)
                  Text(
                    '${_dateLabel(hovered.date)} · ${NumberFormat.decimalPattern().format(hovered.asr + hovered.nmt)} '
                    '(${NumberFormat.compact().format(hovered.asr)} ASR + ${NumberFormat.compact().format(hovered.nmt)} NMT)',
                    style: const TextStyle(color: AppColors.accentTeal),
                  )
                else
                  const Text('hover a bar →'),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Chart area
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Y-axis labels
                SizedBox(
                  width: 38,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final p in [1.0, 0.75, 0.5, 0.25, 0.0])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(
                            _formatToken((gridMax * p).round()),
                            style: const TextStyle(
                              color: AppColors.textFaint,
                              fontSize: 8,
                              fontFamily: 'JetBrains Mono',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Bars
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Stack(
                              children: [
                                // Horizontal grid lines
                                for (final p in [0.0, 0.25, 0.5, 0.75])
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: p * constraints.maxHeight,
                                    child: Container(
                                      height: 1,
                                      color:
                                          p == 0.0
                                              ? Colors.white.withValues(
                                                alpha: 0.10,
                                              )
                                              : Colors.white.withValues(
                                                alpha: 0.04,
                                              ),
                                    ),
                                  ),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: List.generate(data.length, (i) {
                                    final d = data[i];
                                    final total = d.asr + d.nmt;
                                    final isZero = total == 0;
                                    final isHovered = _hoveredIndex == i;
                                    final h = gridMax > 0
                                        ? (total / gridMax).clamp(0.0, 1.0)
                                        : 0.0;
                                    final asrH = total > 0
                                        ? (d.asr / total) * h
                                        : 0.0;
                                    final nmtH = total > 0
                                        ? (d.nmt / total) * h
                                        : 0.0;

                                    return Expanded(
                                      child: MouseRegion(
                                        onEnter: (_) => setState(
                                          () => _hoveredIndex = i,
                                        ),
                                        onExit: (_) => setState(
                                          () => _hoveredIndex = null,
                                        ),
                                        child: Opacity(
                                          opacity: _hoveredIndex != null &&
                                                  !isHovered
                                              ? 0.45
                                              : 1.0,
                                          child: _BarColumn(
                                            height: constraints.maxHeight,
                                            asrFraction: asrH,
                                            nmtFraction: nmtH,
                                            isZero: isZero,
                                            isHovered: isHovered,
                                            index: i,
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ],
                            );
                          },
                        ),
                      ),

                      // X-axis labels
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          for (final idx in _xLabelIndices(data.length))
                            Text(
                              _dateLabel(data[idx].date),
                              style: const TextStyle(
                                color: AppColors.textFaint,
                                fontSize: 9,
                                fontFamily: 'JetBrains Mono',
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static List<int> _xLabelIndices(int len) {
    if (len == 0) return [];
    return {
      0,
      (len * 0.25).round().clamp(0, len - 1),
      (len * 0.5).round().clamp(0, len - 1),
      (len * 0.75).round().clamp(0, len - 1),
      len - 1,
    }.toList()..sort();
  }

  static String _dateLabel(DateTime d) =>
      DateFormat('MMM d').format(d);

  static int _niceMax(int v) {
    if (v <= 0) return 1000;
    final pow = math.pow(10, (math.log(v) / math.ln10).floor()).toInt();
    return ((v / pow).ceil() * pow);
  }

  static String _formatToken(int v) {
    if (v >= 1000) {
      final k = v / 1000;
      return '${k >= 10 ? k.toStringAsFixed(0) : k.toStringAsFixed(1)}k';
    }
    return v.toString();
  }

  static List<_DayData> _buildChartData(List<DailyUsageRecord> history) {
    final asrKeys = EngineRegistry.knownAsrStatsKeys.toSet();
    return history.map((r) {
      int asr = 0, nmt = 0;
      r.engineTokens.forEach((engine, tokens) {
        if (asrKeys.contains(engine)) {
          asr += tokens;
        } else {
          nmt += tokens;
        }
      });
      // If no per-engine breakdown available, fall back to total
      if (asr == 0 && nmt == 0 && r.totalTokens > 0) {
        nmt = r.totalTokens;
      }
      return _DayData(date: r.date, asr: asr, nmt: nmt);
    }).toList();
  }
}

class _DayData {
  final DateTime date;
  final int asr;
  final int nmt;
  const _DayData({required this.date, required this.asr, required this.nmt});
}

// ── Bar column ────────────────────────────────────────────────────────────────

class _BarColumn extends StatelessWidget {
  final double height;
  final double asrFraction;
  final double nmtFraction;
  final bool isZero;
  final bool isHovered;
  final int index;

  const _BarColumn({
    required this.height,
    required this.asrFraction,
    required this.nmtFraction,
    required this.isZero,
    required this.isHovered,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    if (isZero) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: 2,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: Colors.redAccent.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // NMT (translation — teal, top)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: nmtFraction),
            duration: Duration(milliseconds: 800 + index * 15),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => Container(
              height: height * v,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    UsageColors.translationAccent,
                    UsageColors.translationAccent.withValues(alpha: 0.67),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(2),
                ),
                boxShadow: isHovered
                    ? [
                        BoxShadow(
                          color: UsageColors.translationAccent.withValues(
                            alpha: 0.8,
                          ),
                          blurRadius: 10,
                        ),
                      ]
                    : [],
              ),
            ),
          ),
          // ASR (indigo, bottom)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: asrFraction),
            duration: Duration(milliseconds: 900 + index * 15),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => Container(
              height: height * v,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    UsageColors.asrAccent,
                    AppColors.semanticAsr,
                  ],
                ),
                boxShadow: isHovered
                    ? [
                        BoxShadow(
                          color: UsageColors.asrAccent.withValues(alpha: 0.8),
                          blurRadius: 10,
                        ),
                      ]
                    : [],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bar_chart_rounded,
            size: 28,
            color: Colors.white.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 8),
          Text(
            'No activity data yet',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.25),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
