import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:omni_bridge/features/usage/domain/repositories/usage_repository.dart';
import 'package:omni_bridge/features/usage/presentation/bloc/usage_bloc.dart';
import 'package:omni_bridge/features/usage/presentation/bloc/usage_event.dart';
import 'package:omni_bridge/features/usage/presentation/bloc/usage_state.dart';
import 'package:omni_bridge/features/usage/domain/entities/engine_usage.dart';
import 'package:omni_bridge/features/usage/presentation/widgets/usage_history_chart.dart';
import 'package:omni_bridge/features/usage/presentation/widgets/usage_donut_chart.dart';
import 'package:omni_bridge/features/usage/presentation/widgets/model_usage_bar_chart.dart';
import 'package:omni_bridge/features/usage/presentation/widgets/usage_header.dart';
import 'package:omni_bridge/features/usage/presentation/widgets/engine_usage_card.dart';
import 'package:get_it/get_it.dart';
import 'package:omni_bridge/core/widgets/omni_window_layout.dart';
import 'package:omni_bridge/core/widgets/omni_card.dart';

import 'package:omni_bridge/core/widgets/omni_branding.dart';
import 'package:omni_bridge/core/widgets/omni_version_chip.dart';

class UsageScreen extends StatefulWidget {
  const UsageScreen({super.key});

  @override
  State<UsageScreen> createState() => _UsageScreenState();
}

class _UsageScreenState extends State<UsageScreen> {


  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => UsageBloc(
        usageRepository: GetIt.I<UsageRepository>(),
      )..add(const LoadUsageStats()),
      child: OmniWindowLayout(
            child: Column(
              children: [
                buildUsageHeader(context),
                const Divider(height: 1, color: Colors.white10),
                Expanded(
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
                                'Error: ${state.message}',
                                style: const TextStyle(color: Colors.redAccent),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  context.read<UsageBloc>().add(
                                    const LoadUsageStats(refresh: true),
                                  );
                                },
                                child: const Text('Try Again'),
                              ),
                            ],
                          ),
                        );
                      }

                      if (state is UsageLoaded) {
                        return RefreshIndicator(
                          onRefresh: () async {
                            context.read<UsageBloc>().add(
                                  const LoadUsageStats(refresh: true),
                                );
                          },
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 32,
                            ),
                            physics: const BouncingScrollPhysics(),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final isNarrow = constraints.maxWidth < 700;

                                return Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 1020),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const OmniBranding(
                                          subtitle: 'USAGE DASHBOARD',
                                          fallbackIcon: Icons.analytics_rounded,
                                        ),
                                        const SizedBox(height: 32),
                                        _buildDashboard(context, state, isNarrow),
                                        const SizedBox(height: 32),

                                        // ── Model Distribution ───────────────
                                        _UsageCard(
                                          icon: Icons.bar_chart_rounded,
                                          title: 'Model Distribution',
                                          child: SizedBox(
                                            height: 240,
                                            child: ModelUsageBarChart(
                                              engineUsage: state.engineUsage,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 32),

                                        // ── Engine Performance ───────────────
                                        const _SectionTitle(
                                          icon: Icons.model_training_rounded,
                                          label: 'Engine Performance',
                                        ),
                                        const SizedBox(height: 12),
                                        _buildEngineSection(
                                          context,
                                          'ASR Engines',
                                          Icons.mic_none_rounded,
                                          const Color(0xFF6366F1),
                                          state.engineUsage
                                              .where((e) => e.type == UsageType.asr)
                                              .toList(),
                                          state.engineUsage,
                                          constraints.maxWidth,
                                        ),
                                        const SizedBox(height: 16),
                                        _buildEngineSection(
                                          context,
                                          'Translation Engines',
                                          Icons.translate_rounded,
                                          const Color(0xFF2DD4BF),
                                          state.engineUsage
                                              .where((e) => e.type == UsageType.translation)
                                              .toList(),
                                          state.engineUsage,
                                          constraints.maxWidth,
                                        ),
                                        const SizedBox(height: 32),

                                        // ── Usage History ────────────────────
                                        _UsageCard(
                                          icon: Icons.timeline_rounded,
                                          title: 'Usage History (Last 30 Days)',
                                          child: UsageHistoryChart(
                                            history: state.dailyHistory,
                                          ),
                                        ),
                                        const SizedBox(height: 48),
                                        const Center(
                                          child: OmniVersionChip(),
                                        ),
                                        const SizedBox(height: 16),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      }

                      return const SizedBox();
                    },
                  ),
                ),
            ],
          ),
        ),
    );
  }

  Widget _buildDashboard(BuildContext context, UsageLoaded state, bool isNarrow) {
    final formatter = NumberFormat.compact();

    final lifetimeCard = _UsageCard(
      icon: Icons.analytics_rounded,
      title: 'Lifetime Usage',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatter.format(state.lifetimeTokens),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isNarrow ? 28 : 36,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.tealAccent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.2)),
                ),
                child: Text(
                  state.tier.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.tealAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const Text(
            'tokens used',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(color: Colors.white10),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _SummaryStat(
                label: 'ASR TOKENS',
                value: formatter.format(state.asrTokens),
                valueColor: const Color(0xFF6366F1),
              ),
              Container(width: 1, height: 32, color: Colors.white10),
              _SummaryStat(
                label: 'TRANS TOKENS',
                value: formatter.format(state.translationTokens),
                valueColor: const Color(0xFF2DD4BF),
              ),
              Container(width: 1, height: 32, color: Colors.white10),
              _SummaryStat(
                label: 'THIS MONTH',
                value: formatter.format(state.monthlyTokens),
              ),
            ],
          ),
        ],
      ),
    );

    final breakdownCard = _UsageCard(
      icon: Icons.donut_large_rounded,
      title: 'Type Breakdown',
      child: SizedBox(
        height: 140,
        child: UsageDonutChart(
          asrTokens: state.asrTokens,
          translationTokens: state.translationTokens,
        ),
      ),
    );

    if (isNarrow) {
      return Column(
        children: [
          lifetimeCard,
          const SizedBox(height: 16),
          breakdownCard,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: lifetimeCard),
        const SizedBox(width: 16),
        Expanded(flex: 2, child: breakdownCard),
      ],
    );
  }

  Widget _buildEngineSection(
    BuildContext context,
    String title,
    IconData icon,
    Color accentColor,
    List<EngineUsage> engines,
    List<EngineUsage> allEngines,
    double maxWidth,
  ) {
    if (engines.isEmpty) return const SizedBox.shrink();

    final maxTokens = allEngines
        .map((e) => e.effectiveTokens)
        .fold(0.0, (a, b) => a > b ? a : b.toDouble());

    // Column count based on available width
    int cols = 5;
    if (maxWidth < 500) {
      cols = 2;
    } else if (maxWidth < 750) {
      cols = 3;
    } else if (maxWidth < 950) {
      cols = 4;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: accentColor.withValues(alpha: 0.8)),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // LayoutBuilder+Wrap: cards get equal width, height is content-driven
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 8.0;
            final cardWidth = (constraints.maxWidth - spacing * (cols - 1)) / cols;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: engines
                  .map(
                    (e) => SizedBox(
                      width: cardWidth,
                      child: EngineUsageCard(usage: e, maxTokens: maxTokens),
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

// ── Shared styled card container ──────────────────────────────────────────────

class _UsageCard extends StatelessWidget {
  final Widget child;
  final IconData? icon;
  final String? title;

  const _UsageCard({
    required this.child,
    this.icon,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OmniCard(
        padding: const EdgeInsets.all(20),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null && title != null) ...[
            Row(
              children: [
                Icon(icon!, size: 14, color: Colors.tealAccent),
                const SizedBox(width: 8),
                Text(
                  title!,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          child,
        ],
      ),
     ),
    );
  }
}

// ── Section title with trailing divider ───────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SectionTitle({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.tealAccent),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(child: Divider(color: Colors.white10, height: 1)),
      ],
    );
  }
}

// ── Summary stat ──────────────────────────────────────────────────────────────

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _SummaryStat({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ],
    );
  }
}
