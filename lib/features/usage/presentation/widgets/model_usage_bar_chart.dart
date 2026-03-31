import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:omni_bridge/core/theme/app_theme.dart';
import 'package:omni_bridge/features/usage/domain/entities/engine_usage.dart';
import 'package:omni_bridge/features/usage/presentation/widgets/usage_utils.dart';

/// A clean, custom-drawn horizontal bar chart showing token distribution
/// across models. No external charting dependency needed.
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

    // Sort by effectiveTokens descending, take top models
    final sorted = List<EngineUsage>.from(engineUsage)
      ..sort((a, b) => b.effectiveTokens.compareTo(a.effectiveTokens));
    // Filter out zero-usage unless there are very few models
    final display = sorted.where((e) => e.effectiveTokens > 0).toList();
    if (display.isEmpty) {
      return const Center(
        child: Text(
          'No usage recorded yet',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
      );
    }

    final maxTokens = display.first.effectiveTokens.toDouble();
    final totalTokens = display.fold<int>(0, (s, e) => s + e.effectiveTokens);
    final formatter = NumberFormat.compact();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Legend row ──
        Row(
          children: [
            _legendDot(UsageColors.asrAccent, 'ASR'),
            const SizedBox(width: 14),
            _legendDot(UsageColors.translationAccent, 'Translation'),
            const Spacer(),
            Text(
              '${formatter.format(totalTokens)} total tokens',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // ── Bar rows ──
        ...display.map((e) => _buildBarRow(e, maxTokens, formatter)),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildBarRow(
    EngineUsage usage,
    double maxTokens,
    NumberFormat formatter,
  ) {
    final isAsr = usage.type == UsageType.asr;
    final barColor =
        isAsr ? UsageColors.asrAccent : UsageColors.translationAccent;
    final displayName = UsageUtils.getDisplayName(usage.engine, usage.type);
    final fraction =
        maxTokens > 0 ? (usage.effectiveTokens / maxTokens).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Label row: name + value ──
          Row(
            children: [
              Icon(
                isAsr ? Icons.mic_rounded : Icons.translate_rounded,
                size: 11,
                color: barColor.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  displayName,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                formatter.format(usage.effectiveTokens),
                style: TextStyle(
                  color: barColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // ── Bar ──
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      // Background track
                      Container(
                        width: constraints.maxWidth,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      // Filled bar
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                        width: constraints.maxWidth * fraction,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              barColor.withValues(alpha: 0.8),
                              barColor.withValues(alpha: 0.5),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
