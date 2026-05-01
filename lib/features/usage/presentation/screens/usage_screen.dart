import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:omni_bridge/core/constants/engine_registry.dart';
import 'package:omni_bridge/core/di/di.dart';
import 'package:omni_bridge/core/navigation/app_router.dart';
import 'package:omni_bridge/core/theme/app_theme.dart';
import 'package:omni_bridge/features/shell/presentation/widgets/app_dashboard_shell.dart';
import 'package:omni_bridge/features/usage/domain/entities/daily_usage_record.dart';
import 'package:omni_bridge/features/usage/domain/entities/engine_usage.dart';
import 'package:omni_bridge/features/usage/presentation/bloc/usage_bloc.dart';
import 'package:omni_bridge/features/usage/presentation/bloc/usage_event.dart';
import 'package:omni_bridge/features/usage/presentation/bloc/usage_state.dart';
import 'package:omni_bridge/features/usage/presentation/widgets/activity_chart.dart';
import 'package:omni_bridge/features/usage/presentation/widgets/engine_usage_card.dart';
import 'package:omni_bridge/features/usage/presentation/widgets/language_pie.dart';
import 'package:omni_bridge/features/usage/presentation/widgets/quota_strip.dart';
import 'package:omni_bridge/features/usage/presentation/widgets/stat_cards_grid.dart';
import 'package:omni_bridge/features/usage/presentation/widgets/usage_header.dart';
import 'package:omni_bridge/features/usage/presentation/widgets/usage_status_bar.dart';

/// Usage analytics dashboard matching `demo/Usage Analytics.html`.
///
/// Layout (top → bottom inside scrollable content):
///   1. Title row — "Usage Analytics" + tier chip + range selector + Export CSV
///   2. [QuotaStrip] — daily (amber) + monthly (teal) bars
///   3. [StatCardsGrid] — TODAY / THIS WEEK / THIS MONTH / LIFETIME
///   4. Charts row — [ActivityChart] (1.7fr) + [LanguagePie] (1fr)
///   5. ASR ENGINES section header + 3-col [EngineUsageCard] grid
///   6. TRANSLATION ENGINES section header + 3-col [EngineUsageCard] grid
///   7. [UsageStatusBar] — fixed 28 px footer
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
          child: BlocConsumer<UsageBloc, UsageState>(
            listenWhen: (previous, current) {
              if (current is! UsageLoaded) return false;
              final prev = previous is UsageLoaded ? previous : null;
              // Only fire when exportPath/exportError transitions from null → non-null.
              final exportPathChanged =
                  current.exportPath != null && prev?.exportPath != current.exportPath;
              final exportErrorChanged =
                  current.exportError != null && prev?.exportError != current.exportError;
              return exportPathChanged || exportErrorChanged;
            },
            listener: (context, state) {
              if (state is UsageLoaded && state.exportPath != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Exported to ${state.exportPath}'),
                    backgroundColor: AppColors.semanticTranslation,
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
              if (state is UsageLoaded && state.exportError != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Export failed: ${state.exportError}'),
                    backgroundColor: UsageColors.errorRed,
                  ),
                );
              }
            },
            builder: (context, state) {
              if (state is UsageLoading || state is UsageInitial) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.accentTeal,
                    strokeWidth: 2,
                  ),
                );
              }
              if (state is UsageError) {
                return _ErrorView(message: state.message);
              }
              if (state is UsageLoaded) {
                return _LoadedView(state: state);
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }
}

// ── Loaded view ───────────────────────────────────────────────────────────────

class _LoadedView extends StatelessWidget {
  final UsageLoaded state;
  const _LoadedView({required this.state});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF161616), Color(0xFF0F0F0F)],
        ),
      ),
      child: Column(
      children: [
        // Pinned sub-header matching demo (padding 18/24/14 + bottom border).
        Container(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.cardBorder, width: 1),
            ),
          ),
          child: _TitleRow(state: state),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (state.quotaStatus != null)
                  QuotaStrip(
                    quota: state.quotaStatus!,
                    monthlyTokens: state.monthlyTokens,
                    lifetimeTokens: state.lifetimeTokens,
                  ),
                const SizedBox(height: 16),

                StatCardsGrid(
                  todayTokens: state.quotaStatus?.dailyTokensUsed ?? 0,
                  weeklyTokens: state.weeklyTokens,
                  monthlyTokens: state.monthlyTokens,
                  lifetimeTokens: state.lifetimeTokens,
                  dailyHistory: state.dailyHistory,
                ),
                const SizedBox(height: 16),

                _ChartsRow(state: state),
                const SizedBox(height: 22),

                _EngineSection(
                  title: 'ASR ENGINES',
                  icon: Icons.mic_none_rounded,
                  accent: UsageColors.asrAccent,
                  engines: state.engineUsage
                      .where((e) => e.type == UsageType.asr)
                      .toList(),
                  selectedEngine: state.selectedTranscriptionEngine,
                  dailyHistory: state.dailyHistory,
                ),
                const SizedBox(height: 18),

                _EngineSection(
                  title: 'TRANSLATION ENGINES',
                  icon: Icons.translate_rounded,
                  accent: UsageColors.translationAccent,
                  engines: state.engineUsage
                      .where((e) => e.type == UsageType.translation)
                      .toList(),
                  selectedEngine: state.selectedTranslationEngine,
                  dailyHistory: state.dailyHistory,
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
        UsageStatusBar(
          loadedAt: state.loadedAt,
          avgLatencyMs: () {
            final calls = state.engineUsage.fold<int>(0, (s, e) => s + e.totalCalls);
            final ms = state.engineUsage.fold<int>(0, (s, e) => s + e.totalLatencyMs);
            return calls > 0 ? (ms / calls).round() : 0;
          }(),
          translationEngine: EngineRegistry.displayNameForStatsKey(
            state.selectedTranslationEngine,
          ),
          transcriptionEngine: EngineRegistry.displayNameForStatsKey(
            state.selectedTranscriptionEngine,
          ),
          isConnected: state.quotaStatus != null,
        ),
      ],
    ),
    );
  }
}

// ── Title row ─────────────────────────────────────────────────────────────────

class _TitleRow extends StatelessWidget {
  final UsageLoaded state;
  const _TitleRow({required this.state});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text(
                  'Usage Analytics',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 10),
                _TierChip(label: state.tier),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Track tokens, engines, and languages across every session.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
        const Spacer(),
        _RangeSelector(current: state.range),
        const SizedBox(width: 8),
        _ExportButton(),
      ],
    );
  }
}

class _TierChip extends StatelessWidget {
  final String label;
  const _TierChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accentTeal.withValues(alpha: 0.10),
        border: Border.all(
          color: AppColors.accentTeal.withValues(alpha: 0.30),
        ),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.accentTeal,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ── Range selector ────────────────────────────────────────────────────────────

class _RangeSelector extends StatelessWidget {
  final UsageRange current;
  const _RangeSelector({required this.current});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: UsageRange.values.map((r) {
          final isActive = current == r;
          final is1Y = r == UsageRange.oneYear;
          return GestureDetector(
            onTap: () => context.read<UsageBloc>().add(SetDateRange(r)),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.accentTeal.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                r.label,
                style: TextStyle(
                  color: isActive
                      ? AppColors.accentTeal
                      : is1Y
                          ? AppColors.textDisabled
                          : AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Export CSV button ─────────────────────────────────────────────────────────

class _ExportButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.read<UsageBloc>().add(const ExportCsv()),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          border: Border.all(color: AppColors.cardBorder),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.download_rounded,
              size: 12,
              color: AppColors.textSecondary,
            ),
            SizedBox(width: 6),
            Text(
              'Export CSV',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Charts row ────────────────────────────────────────────────────────────────

class _ChartsRow extends StatelessWidget {
  final UsageLoaded state;
  const _ChartsRow({required this.state});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 17,
          child: ActivityChart(dailyHistory: state.dailyHistory),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 10,
          child: LanguagePie(languages: state.languages),
        ),
      ],
    );
  }
}

// ── Engine section (header + grid) ───────────────────────────────────────────

class _EngineSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accent;
  final List<EngineUsage> engines;
  final String selectedEngine;
  final List<DailyUsageRecord> dailyHistory;

  const _EngineSection({
    required this.title,
    required this.icon,
    required this.accent,
    required this.engines,
    required this.selectedEngine,
    required this.dailyHistory,
  });

  @override
  Widget build(BuildContext context) {
    if (engines.isEmpty) return const SizedBox.shrink();

    final sectionTotal =
        engines.fold<int>(0, (s, e) => s + e.effectiveTokens);
    final maxTokens = engines
        .map((e) => e.effectiveTokens.toDouble())
        .fold<double>(0, (a, b) => a > b ? a : b);
    final allEmpty = engines.every((e) => e.totalCalls == 0);
    final trends = _computeWeekOverWeek(engines, dailyHistory);
    final fmt = NumberFormat.compact();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: title,
          icon: icon,
          accent: accent,
          trailing: Text(
            '${engines.length} engines · ${fmt.format(sectionTotal)} tokens',
            style: const TextStyle(
              color: AppColors.textFaint,
              fontSize: 10,
              fontFamily: 'JetBrains Mono',
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (allEmpty)
          _EmptySection()
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth >= 750
                  ? 3
                  : constraints.maxWidth >= 500
                      ? 2
                      : 1;
              const spacing = 10.0;
              final cardWidth =
                  (constraints.maxWidth - spacing * (cols - 1)) / cols;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: engines.map((e) {
                  final sharePct = sectionTotal > 0
                      ? e.effectiveTokens / sectionTotal * 100
                      : 0.0;
                  return SizedBox(
                    width: cardWidth,
                    child: EngineUsageCard(
                      usage: e,
                      maxTokens: maxTokens,
                      isSelected: e.engine == selectedEngine,
                      trendChangePct: trends[e.engine],
                      sharePct: sharePct,
                    ),
                  );
                }).toList(),
              );
            },
          ),
      ],
    );
  }

  Map<String, double?> _computeWeekOverWeek(
    List<EngineUsage> engines,
    List<DailyUsageRecord> history,
  ) {
    final now = DateTime.now();
    final result = <String, double?>{};
    for (final e in engines) {
      int thisWeek = 0, lastWeek = 0;
      for (final record in history) {
        final daysAgo = now.difference(record.date).inDays;
        final tokens = record.engineTokens[e.engine] ?? 0;
        if (daysAgo < 7) {
          thisWeek += tokens;
        } else if (daysAgo < 14) {
          lastWeek += tokens;
        }
      }
      result[e.engine] =
          lastWeek == 0 ? null : (thisWeek - lastWeek) / lastWeek * 100;
    }
    return result;
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accent;
  final Widget? trailing;

  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.accent,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: accent.withValues(alpha: 0.8)),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            color: accent.withValues(alpha: 0.87),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Divider(color: AppColors.cardBorder, height: 1),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    );
  }
}

class _EmptySection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
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
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: UsageColors.errorRed,
            size: 32,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              color: UsageColors.errorRed,
              fontSize: 13,
            ),
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
}
