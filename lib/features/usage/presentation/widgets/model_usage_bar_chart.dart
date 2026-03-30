import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:omni_bridge/features/usage/domain/entities/engine_usage.dart';
import 'package:omni_bridge/features/usage/presentation/widgets/usage_utils.dart';

class ModelUsageBarChart extends StatelessWidget {
  final List<EngineUsage> engineUsage;

  const ModelUsageBarChart({
    super.key,
    required this.engineUsage,
  });

  @override
  Widget build(BuildContext context) {
    if (engineUsage.isEmpty) {
      return const Center(
        child: Text(
          'No model data',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
      );
    }

    // Sort by effectiveTokens (handles engines where total_tokens = 0)
    final sortedUsage = List<EngineUsage>.from(engineUsage)
      ..sort((a, b) => b.effectiveTokens.compareTo(a.effectiveTokens));
    final displayUsage = sortedUsage.take(6).toList();

    // Use effectiveTokens for maxY; ensure at least 100 to avoid flat lines.
    final maxTokens =
        displayUsage.map((e) => e.effectiveTokens).fold(0, (a, b) => a > b ? a : b);
    final maxY = maxTokens == 0 ? 100.0 : maxTokens.toDouble() * 1.2;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Colors.black87,
            tooltipBorder: const BorderSide(color: Colors.white24),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final usage = displayUsage[groupIndex];
              final displayName = UsageUtils.getDisplayName(usage.engine, usage.type);
              return BarTooltipItem(
                '$displayName\n',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                children: [
                  TextSpan(
                    text: '${rod.toY.toInt()} tokens',
                    style: TextStyle(
                      color: usage.type == UsageType.asr ? const Color(0xFF6366F1) : const Color(0xFF10B981),
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= displayUsage.length) return const SizedBox.shrink();

                // Use the resolved display name (first word, uppercased) as the label.
                final usage = displayUsage[index];
                final displayName = UsageUtils.getDisplayName(usage.engine, usage.type);
                final label = displayName.split(' ').first.toUpperCase();

                return Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
              reservedSize: 32,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(color: Colors.white24, fontSize: 9),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (value) => const FlLine(
            color: Colors.white10,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: displayUsage.asMap().entries.map((entry) {
          final index = entry.key;
          final usage = entry.value;
          final isAsr = usage.type == UsageType.asr;

          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: usage.effectiveTokens.toDouble(),
                color: isAsr ? const Color(0xFF6366F1) : const Color(0xFF10B981),
                width: 14,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxY,
                  color: Colors.white.withValues(alpha: 0.02),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
