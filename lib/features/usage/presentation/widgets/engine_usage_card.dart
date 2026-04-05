import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:omni_bridge/core/theme/app_theme.dart';
import 'package:omni_bridge/features/usage/domain/entities/engine_usage.dart';
import 'package:omni_bridge/features/usage/presentation/widgets/usage_utils.dart';

class EngineUsageCard extends StatelessWidget {
  final EngineUsage usage;
  final double? maxTokens;
  final bool isSelected;

  const EngineUsageCard({
    super.key,
    required this.usage,
    this.maxTokens,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.compact();
    final hasAccess = usage.isInPlan;
    final isAsr = usage.type == UsageType.asr;
    final themeColor = UsageColors.accentFor(isAsr: isAsr, isInPlan: hasAccess);
    final displayName = UsageUtils.getDisplayName(usage.engine, usage.type);

    return Opacity(
      opacity: hasAccess ? 1.0 : 0.4,
      child: Container(
        decoration: BoxDecoration(
          color: UsageColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? themeColor.withValues(alpha: 0.75)
                : themeColor.withValues(alpha: 0.15),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            children: [
              // ── Colored accent bar ──
              Container(
                width: 3.5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      themeColor.withValues(alpha: 0.9),
                      themeColor.withValues(alpha: 0.3),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              // ── Card content ──
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Header: Icon + Name ──
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: themeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              isAsr
                                  ? Icons.mic_rounded
                                  : Icons.translate_rounded,
                              color: themeColor,
                              size: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                letterSpacing: 0.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSelected)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: themeColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'ACTIVE',
                                style: TextStyle(
                                  color: themeColor,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            )
                          else if (!hasAccess)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: UsageColors.statBackground,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'LOCKED',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // ── Monthly Usage (primary metric) ──
                      _buildMonthlySection(formatter, themeColor),

                      const SizedBox(height: 10),

                      // ── Secondary stats row ──
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: UsageColors.statBackground,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            _StatChip(
                              label: 'Lifetime',
                              value: formatter.format(usage.effectiveTokens),
                              icon: Icons.all_inclusive_rounded,
                              iconColor: themeColor,
                            ),
                            _buildDot(),
                            _StatChip(
                              label: 'Calls',
                              value: formatter.format(usage.totalCalls),
                              icon: Icons.touch_app_rounded,
                              iconColor: themeColor,
                            ),
                            _buildDot(),
                            _StatChip(
                              label: 'Avg',
                              value: '${usage.averageLatencyMs.toInt()}ms',
                              icon: Icons.speed_rounded,
                              iconColor: themeColor,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthlySection(NumberFormat formatter, Color themeColor) {
    final monthlyUsed = usage.monthlyTokensUsed >= 0
        ? usage.monthlyTokensUsed
        : 0;
    final hasLimit = usage.hasMonthlyLimit;
    final isExceeded = usage.isMonthlyLimitExceeded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatter.format(monthlyUsed),
              style: TextStyle(
                color: isExceeded ? UsageColors.errorRed : Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 17,
                height: 1,
              ),
            ),
            if (hasLimit) ...[
              const SizedBox(width: 2),
              Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: Text(
                  ' / ${formatter.format(usage.monthlyTokensLimit)}',
                  style: const TextStyle(
                    color: UsageColors.limitText,
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ),
            ],
            const Spacer(),
            const Padding(
              padding: EdgeInsets.only(bottom: 2),
              child: Text(
                'THIS MONTH',
                style: TextStyle(
                  color: UsageColors.monthLabel,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(2.5),
          child: LinearProgressIndicator(
            value: hasLimit
                ? usage.monthlyProgress
                : (maxTokens != null && maxTokens! > 0
                      ? (monthlyUsed / maxTokens!).clamp(0.0, 1.0)
                      : 0.0),
            backgroundColor: UsageColors.barTrack,
            valueColor: AlwaysStoppedAnimation<Color>(
              UsageColors.barColor(isExceeded: isExceeded, accent: themeColor),
            ),
            minHeight: 4,
          ),
        ),
      ],
    );
  }

  Widget _buildDot() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Container(
        width: 3,
        height: 3,
        decoration: const BoxDecoration(
          color: UsageColors.barTrack,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: iconColor.withValues(alpha: 0.5)),
          const SizedBox(width: 4),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: UsageColors.statValue,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    height: 1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  label,
                  style: const TextStyle(
                    color: UsageColors.statLabel,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
