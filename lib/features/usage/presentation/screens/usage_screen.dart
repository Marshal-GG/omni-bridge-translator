import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:omni_bridge/core/theme/app_theme.dart';
import 'package:omni_bridge/features/usage/presentation/bloc/usage_bloc.dart';
import 'package:omni_bridge/features/usage/presentation/bloc/usage_event.dart';
import 'package:omni_bridge/features/usage/presentation/bloc/usage_state.dart';
import 'package:omni_bridge/features/usage/domain/entities/engine_usage.dart';
import 'package:omni_bridge/features/usage/domain/entities/quota_status.dart';
import 'package:omni_bridge/features/usage/domain/entities/daily_usage_record.dart';
import 'package:omni_bridge/features/usage/presentation/widgets/usage_header.dart';
import 'package:omni_bridge/features/usage/presentation/widgets/engine_usage_card.dart';
import 'package:omni_bridge/core/di/di.dart';
import 'package:omni_bridge/features/shell/presentation/widgets/app_dashboard_shell.dart';
import 'package:omni_bridge/core/navigation/app_router.dart';

class UsageScreen extends StatelessWidget {
  const UsageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => sl<UsageBloc>()..add(const LoadUsageStats()),
      child: Builder(
        builder: (context) => AppDashboardShell(
          currentRoute: AppRouter.usage,
          header: buildUsageHeader(context),
          child: BlocBuilder<UsageBloc, UsageState>(
            builder: (context, state) {
              if (state is UsageLoading) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: Colors.tealAccent,
                    strokeWidth: 2,
                  ),
                );
              }

              if (state is UsageError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Colors.redAccent,
                        size: 32,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        state.message,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () => context
                            .read<UsageBloc>()
                            .add(const LoadUsageStats(refresh: true)),
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                );
              }

              if (state is UsageLoaded) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 24,
                  ),
                  physics: const BouncingScrollPhysics(),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1020),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Stats strip ─────────────────────────────────
                          _StatsStrip(state: state),
                          const SizedBox(height: 28),

                          // ── ASR Engines ──────────────────────────────────
                          _buildEngineSection(
                            title: 'ASR Engines',
                            icon: Icons.mic_none_rounded,
                            accentColor: const Color(0xFF6366F1),
                            engines: state.engineUsage
                                .where((e) => e.type == UsageType.asr)
                                .toList(),
                            allEngines: state.engineUsage,
                            selectedEngine: state.selectedTranscriptionEngine,
                            dailyHistory: state.dailyHistory,
                          ),
                          const SizedBox(height: 24),

                          // ── Translation Engines ───────────────────────────
                          _buildEngineSection(
                            title: 'Translation Engines',
                            icon: Icons.translate_rounded,
                            accentColor: const Color(0xFF2DD4BF),
                            engines: state.engineUsage
                                .where((e) => e.type == UsageType.translation)
                                .toList(),
                            allEngines: state.engineUsage,
                            selectedEngine: state.selectedTranslationEngine,
                            dailyHistory: state.dailyHistory,
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return const SizedBox();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEngineSection({
    required String title,
    required IconData icon,
    required Color accentColor,
    required List<EngineUsage> engines,
    required List<EngineUsage> allEngines,
    required String selectedEngine,
    required List<DailyUsageRecord> dailyHistory,
  }) {
    if (engines.isEmpty) return const SizedBox.shrink();

    final maxTokens = allEngines
        .map((e) => e.effectiveTokens)
        .fold(0.0, (a, b) => a > b ? a : b.toDouble());

    // Week-over-week trend per engine from dailyHistory
    final now = DateTime.now();
    final Map<String, _Trend> trends = {};
    for (final e in engines) {
      int thisWeek = 0;
      int lastWeek = 0;
      for (final record in dailyHistory) {
        final daysAgo = now.difference(record.date).inDays;
        final tokens = record.engineTokens[e.engine] ?? 0;
        if (daysAgo < 7) {
          thisWeek += tokens;
        } else if (daysAgo < 14) {
          lastWeek += tokens;
        }
      }
      trends[e.engine] = _Trend(thisWeek: thisWeek, lastWeek: lastWeek);
    }

    // Empty state: all engines have zero calls ever
    final allEmpty = engines.every((e) => e.totalCalls == 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: accentColor.withValues(alpha: 0.8)),
            const SizedBox(width: 8),
            Text(
              title.toUpperCase(),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Divider(color: Colors.white10, height: 1)),
          ],
        ),
        const SizedBox(height: 12),
        if (allEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                const SizedBox(width: 8),
                Text(
                  'No usage recorded yet for these engines',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.25),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              int cols = 4;
              if (constraints.maxWidth < 500) {
                cols = 1;
              } else if (constraints.maxWidth < 750) {
                cols = 2;
              } else if (constraints.maxWidth < 950) {
                cols = 3;
              }
              const spacing = 10.0;
              final cardWidth =
                  (constraints.maxWidth - spacing * (cols - 1)) / cols;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: engines
                    .map(
                      (e) => SizedBox(
                        width: cardWidth,
                        child: EngineUsageCard(
                          usage: e,
                          maxTokens: maxTokens,
                          isSelected: e.engine == selectedEngine,
                          trendChangePct: trends[e.engine]?.changePct,
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
      ],
    );
  }
}

// ── Week-over-week trend data ─────────────────────────────────────────────────

class _Trend {
  final int thisWeek;
  final int lastWeek;

  const _Trend({required this.thisWeek, required this.lastWeek});

  /// Positive = growth, negative = decline, null = not enough data.
  double? get changePct {
    if (lastWeek == 0 && thisWeek == 0) return null;
    if (lastWeek == 0) return null; // can't compute % from zero base
    return (thisWeek - lastWeek) / lastWeek * 100;
  }
}

// ── Stats strip ───────────────────────────────────────────────────────────────

Color _tierColor(String tier) => switch (tier.toLowerCase()) {
      'enterprise' => const Color(0xFFFFD700),
      'pro' => Colors.tealAccent,
      'trial' => Colors.purpleAccent,
      _ => Colors.white38,
    };

IconData _tierIcon(String tier) => switch (tier.toLowerCase()) {
      'enterprise' => Icons.workspace_premium_rounded,
      'pro' => Icons.bolt_rounded,
      'trial' => Icons.hourglass_top_rounded,
      _ => Icons.person_outline_rounded,
    };

class _StatsStrip extends StatelessWidget {
  final UsageLoaded state;

  const _StatsStrip({required this.state});

  @override
  Widget build(BuildContext context) {
    final compact = NumberFormat.compact();
    final quota = state.quotaStatus;
    final tierColor = _tierColor(state.tier);

    final age = DateTime.now().difference(state.loadedAt);
    final updatedLabel = age.inSeconds < 10
        ? 'just now'
        : age.inMinutes < 1
            ? '${age.inSeconds}s ago'
            : age.inMinutes < 60
                ? '${age.inMinutes}m ago'
                : '${age.inHours}h ago';

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              tierColor.withValues(alpha: 0.08),
              tierColor.withValues(alpha: 0.02),
              AppColors.cardBackground,
            ],
            stops: const [0.0, 0.3, 1.0],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: tierColor.withValues(alpha: 0.18)),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Colored left accent bar
              Container(
                width: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      tierColor,
                      tierColor.withValues(alpha: 0.3),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Tier badge
                          _TierBadge(tier: state.tier),
                          const SizedBox(width: 20),

                          // Quota band (expanded center)
                          if (quota != null && !quota.isUnlimited)
                            Expanded(child: _QuotaBand(status: quota))
                          else if (quota != null && quota.isUnlimited)
                            Expanded(child: _UnlimitedBadge(color: tierColor))
                          else
                            const Spacer(),

                          const SizedBox(width: 20),

                          // Stat cells
                          if (quota != null && !quota.isUnlimited)
                            _StatCell(
                              icon: Icons.today_rounded,
                              label: 'TODAY',
                              value: compact.format(quota.dailyTokensUsed),
                              iconColor: Colors.blueAccent,
                            ),
                          if (quota != null && !quota.isUnlimited)
                            const SizedBox(width: 10),
                          _StatCell(
                            icon: Icons.calendar_month_rounded,
                            label: 'THIS MONTH',
                            value: compact.format(state.monthlyTokens),
                            iconColor: const Color(0xFF6366F1),
                          ),
                          const SizedBox(width: 10),
                          _StatCell(
                            icon: Icons.all_inclusive_rounded,
                            label: 'LIFETIME',
                            value: compact.format(state.lifetimeTokens),
                            iconColor: const Color(0xFF2DD4BF),
                          ),

                          // Trial countdown
                          if (quota?.trialExpiresAt != null) ...[
                            const SizedBox(width: 10),
                            _TrialCountdown(
                              expiresAt: quota!.trialExpiresAt!,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Last updated
                      Row(
                        children: [
                          Icon(
                            Icons.update_rounded,
                            size: 9,
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Updated $updatedLabel',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.18),
                              fontSize: 9,
                            ),
                          ),
                        ],
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
}

// ── Tier badge ────────────────────────────────────────────────────────────────

class _TierBadge extends StatelessWidget {
  final String tier;

  const _TierBadge({required this.tier});

  @override
  Widget build(BuildContext context) {
    final color = _tierColor(tier);
    final icon = _tierIcon(tier);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 5),
          Text(
            tier.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quota progress band ───────────────────────────────────────────────────────

class _QuotaBand extends StatelessWidget {
  final QuotaStatus status;

  const _QuotaBand({required this.status});

  @override
  Widget build(BuildContext context) {
    final compact = NumberFormat.compact();
    final progress = status.progress.clamp(0.0, 1.0);
    final isExceeded = status.isExceeded;
    final color = isExceeded
        ? Colors.redAccent
        : progress > 0.85
            ? Colors.orangeAccent
            : Colors.tealAccent;

    final int used = status.hasPeriodLimit || status.hasMonthlyLimit
        ? status.monthlyTokensUsed
        : status.dailyTokensUsed;
    final int limit = status.hasPeriodLimit
        ? status.periodLimit
        : status.hasMonthlyLimit
            ? status.monthlyLimit
            : status.dailyLimit;
    final String periodLabel =
        status.hasPeriodLimit || status.hasMonthlyLimit ? 'MONTHLY' : 'DAILY';

    final DateTime resetAt = status.monthlyResetAt ?? status.dailyResetAt;
    final Duration remaining = resetAt.difference(DateTime.now());
    final String resetLabel = remaining.isNegative
        ? 'resetting…'
        : remaining.inDays > 0
            ? 'resets in ${remaining.inDays}d'
            : remaining.inHours > 0
                ? 'resets in ${remaining.inHours}h'
                : 'resets in ${remaining.inMinutes}m';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              '$periodLabel QUOTA',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const Spacer(),
            Text(
              '${compact.format(used)} / ${compact.format(limit)}',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                resetLabel,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Custom gradient progress bar
        Stack(
          children: [
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: UsageColors.barTrack,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            if (progress > 0)
              FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: LinearGradient(
                      colors: [
                        color.withValues(alpha: 0.6),
                        color,
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ── Unlimited badge ───────────────────────────────────────────────────────────

class _UnlimitedBadge extends StatelessWidget {
  final Color color;

  const _UnlimitedBadge({required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.all_inclusive_rounded, size: 14, color: color),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'QUOTA',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Unlimited',
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Generic stat cell ─────────────────────────────────────────────────────────

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  const _StatCell({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 10, color: iconColor.withValues(alpha: 0.6)),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textDisabled,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Trial countdown ───────────────────────────────────────────────────────────

class _TrialCountdown extends StatelessWidget {
  final DateTime expiresAt;

  const _TrialCountdown({required this.expiresAt});

  @override
  Widget build(BuildContext context) {
    final remaining = expiresAt.difference(DateTime.now());
    final expired = remaining.isNegative;

    final String label = expired
        ? 'Trial expired'
        : remaining.inDays > 0
            ? '${remaining.inDays}d ${remaining.inHours.remainder(24)}h left'
            : remaining.inHours > 0
                ? '${remaining.inHours}h ${remaining.inMinutes.remainder(60)}m left'
                : '${remaining.inMinutes}m left';

    final color = expired
        ? Colors.redAccent
        : remaining.inDays < 2
            ? Colors.orangeAccent
            : Colors.amberAccent;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.timer_outlined, size: 12, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
