import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:omni_bridge/features/usage/domain/entities/engine_usage.dart';
import 'package:omni_bridge/features/usage/presentation/widgets/usage_utils.dart';

class EngineUsageCard extends StatelessWidget {
  final EngineUsage usage;
  final double? maxTokens;

  const EngineUsageCard({
    super.key,
    required this.usage,
    this.maxTokens,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.compact();
    final effective = usage.effectiveTokens;
    final progress = maxTokens != null && maxTokens! > 0
        ? (effective / maxTokens!).clamp(0.0, 1.0)
        : 0.0;
    
    final isAsr = usage.type == UsageType.asr;
    final themeColor = isAsr ? const Color(0xFF6366F1) : const Color(0xFF2DD4BF);
    final displayName = UsageUtils.getDisplayName(usage.engine, usage.type);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        themeColor.withValues(alpha: 0.2),
                        themeColor.withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    isAsr ? Icons.mic_rounded : Icons.translate_rounded,
                    color: themeColor,
                    size: 11,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TOKENS',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.4,
                  ),
                ),
                Text(
                  formatter.format(effective),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withValues(alpha: 0.05),
                valueColor: AlwaysStoppedAnimation<Color>(themeColor.withValues(alpha: 0.5)),
                minHeight: 2,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: 'CALLS',
                    value: formatter.format(usage.totalCalls),
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'LATENCY',
                    value: '${usage.averageLatencyMs.toInt()}ms',
                    isRightAligned: true,
                  ),
                ),
              ],
            ),
            // ── Monthly usage vs limit (only if engine has a per-engine cap) ──
            if (usage.monthlyTokensUsed >= 0) ...[
              const SizedBox(height: 4),
              const Divider(color: Colors.white10, height: 1),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'THIS MONTH',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                  Text(
                    usage.hasMonthlyLimit
                        ? '${formatter.format(usage.monthlyTokensUsed)} / ${formatter.format(usage.monthlyTokensLimit)}'
                        : formatter.format(usage.monthlyTokensUsed),
                    style: TextStyle(
                      color: usage.isMonthlyLimitExceeded
                          ? const Color(0xFFEF4444)
                          : Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              if (usage.hasMonthlyLimit) ...[
                const SizedBox(height: 2),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: usage.monthlyProgress,
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      usage.isMonthlyLimitExceeded
                          ? const Color(0xFFEF4444)
                          : themeColor.withValues(alpha: 0.7),
                    ),
                    minHeight: 2,
                  ),
                ),
              ],
            ],
          ],
        ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final bool isRightAligned;

  const _MiniStat({
    required this.label,
    required this.value,
    this.isRightAligned = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: isRightAligned ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
