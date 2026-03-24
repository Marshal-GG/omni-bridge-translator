import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class UsageDonutChart extends StatelessWidget {
  final int asrTokens;
  final int translationTokens;

  const UsageDonutChart({
    super.key,
    required this.asrTokens,
    required this.translationTokens,
  });

  @override
  Widget build(BuildContext context) {
    final total = asrTokens + translationTokens;
    if (total == 0) {
      return const Center(
        child: Text(
          'No data available',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
      );
    }

    final asrPercent = (asrTokens / total * 100).toStringAsFixed(1);
    final transPercent = (translationTokens / total * 100).toStringAsFixed(1);

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: AspectRatio(
            aspectRatio: 1,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 35,
                    sections: [
                      PieChartSectionData(
                        color: const Color(0xFF6366F1), // Indigo (ASR)
                        value: asrTokens.toDouble(),
                        title: '',
                        radius: 12,
                        showTitle: false,
                      ),
                      PieChartSectionData(
                        color: const Color(0xFF10B981), // Emerald (Translation)
                        value: translationTokens.toDouble(),
                        title: '',
                        radius: 12,
                        showTitle: false,
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'TOTAL',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      '${(total / 1000).toStringAsFixed(total >= 100000 ? 0 : 1)}k',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 4,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LegendItem(
                color: const Color(0xFF6366F1),
                label: 'ASR',
                percentage: asrPercent,
                icon: Icons.mic_rounded,
              ),
              const SizedBox(height: 12),
              _LegendItem(
                color: const Color(0xFF10B981),
                label: 'Translation',
                percentage: transPercent,
                icon: Icons.translate_rounded,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final String percentage;
  final IconData icon;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.percentage,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Icon(icon, size: 14, color: Colors.white38),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                '$percentage%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
