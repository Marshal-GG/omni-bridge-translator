import 'package:flutter/material.dart';
import '../../domain/entities/subscription_plan.dart';
import 'package:intl/intl.dart';
import 'package:omni_bridge/features/subscription/data/datasources/subscription_remote_datasource.dart';
import 'package:omni_bridge/core/widgets/omni_card.dart';
import 'package:omni_bridge/core/utils/app_logger.dart';

Widget buildPlanCard({
  required SubscriptionPlan plan,
  bool isCurrent = false,
  bool trialUsed = false,
  required NumberFormat formatter,
}) {
  return _PlanCard(
    plan: plan,
    isCurrent: isCurrent,
    trialUsed: trialUsed,
    formatter: formatter,
  );
}

// ── Stateful card ─────────────────────────────────────────────────────────────

class _PlanCard extends StatefulWidget {
  final SubscriptionPlan plan;
  final bool isCurrent;
  final bool trialUsed;
  final NumberFormat formatter;

  const _PlanCard({
    required this.plan,
    required this.isCurrent,
    required this.trialUsed,
    required this.formatter,
  });

  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard> {
  bool _expanded = false;

  SubscriptionPlan get plan => widget.plan;
  NumberFormat get fmt => widget.formatter;

  Color get _accentColor => plan.isTrial
      ? Colors.amberAccent
      : plan.isPopular
      ? Colors.tealAccent
      : Colors.white70;

  @override
  Widget build(BuildContext context) {
    final cardBaseColor = plan.isTrial
        ? Colors.amberAccent
        : plan.isPopular
        ? Colors.tealAccent
        : Colors.white;

    return OmniCard(
      baseColor: cardBaseColor,
      hasGlow: plan.isTrial || plan.isPopular,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          const SizedBox(height: 4),
          _buildPrice(),
          const SizedBox(height: 2),
          Text(
            plan.description,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 10),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 10),
          _buildQuota(),
          const SizedBox(height: 10),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 10),
          _buildFeatures(),
          _buildToggle(),
          if (_expanded) ...[
            const SizedBox(height: 8),
            _buildExpandedDetails(),
          ],
          const SizedBox(height: 12),
          _buildCta(),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          plan.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (plan.isTrial)
          _Badge(
            label: widget.trialUsed ? 'USED' : 'ONE-TIME',
            color: Colors.amberAccent,
            dim: widget.trialUsed,
          )
        else if (plan.isPopular)
          const _Badge(label: 'POPULAR', color: Colors.tealAccent),
      ],
    );
  }

  // ── Price ───────────────────────────────────────────────────────────────────

  Widget _buildPrice() {
    return Text(
      plan.price,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  // ── Quota ───────────────────────────────────────────────────────────────────

  Widget _buildQuota() {
    return Column(
      children: [
        _QuotaRow(
          icon: Icons.today_rounded,
          label: 'Daily',
          value: plan.isUnlimited
              ? 'Unlimited'
              : '${fmt.format(plan.dailyTokens)} tokens',
          accentColor: _accentColor,
        ),
        if (plan.isTrial) ...[
          const SizedBox(height: 4),
          _QuotaRow(
            icon: Icons.timer_outlined,
            label: 'Duration',
            value: plan.trialDurationHours >= 24
                ? '${plan.trialDurationHours ~/ 24} day${plan.trialDurationHours ~/ 24 > 1 ? 's' : ''}'
                : '${plan.trialDurationHours}h',
            accentColor: _accentColor,
          ),
        ] else if (plan.monthlyTokens != 0) ...[
          const SizedBox(height: 4),
          _QuotaRow(
            icon: Icons.calendar_month_rounded,
            label: 'Monthly',
            value: plan.monthlyTokens < 0
                ? 'Unlimited'
                : '${fmt.format(plan.monthlyTokens)} tokens',
            accentColor: _accentColor,
          ),
        ],
        const SizedBox(height: 4),
        _QuotaRow(
          icon: Icons.devices_rounded,
          label: 'Sessions',
          value: '${plan.concurrentSessions} concurrent',
          accentColor: _accentColor,
        ),
      ],
    );
  }

  // ── Features ─────────────────────────────────────────────────────────────────

  Widget _buildFeatures() {
    return Column(
      children: plan.features.map((f) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                Icons.check_circle_rounded,
                color: plan.isTrial ? Colors.amberAccent : Colors.tealAccent,
                size: 12,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                f,
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }

  // ── Show/Hide details toggle ──────────────────────────────────────────────────

  Widget _buildToggle() {
    final hasEngines = plan.allowedTranslationModels.isNotEmpty ||
        plan.allowedTranscriptionModels.isNotEmpty;
    if (!hasEngines) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _expanded ? 'Hide details' : 'Show details',
                style: TextStyle(
                  color: _accentColor.withValues(alpha: 0.7),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 3),
              Icon(
                _expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 13,
                color: _accentColor.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Expanded details ──────────────────────────────────────────────────────────

  Widget _buildExpandedDetails() {
    final src = SubscriptionRemoteDataSource.instance;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (plan.allowedTranslationModels.isNotEmpty) ...[
            _SectionLabel(label: 'TRANSLATION ENGINES', color: _accentColor),
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: plan.allowedTranslationModels.map((m) {
                final limit = plan.engineLimits[m];
                final suffix = limit != null
                    ? ' (${fmt.format(limit)}/mo)'
                    : '';
                return _DetailChip(
                  label: '${src.getModelDisplayName(m)}$suffix',
                  color: _accentColor,
                );
              }).toList(),
            ),
          ],
          if (plan.allowedTranslationModels.isNotEmpty &&
              plan.allowedTranscriptionModels.isNotEmpty)
            const SizedBox(height: 10),
          if (plan.allowedTranscriptionModels.isNotEmpty) ...[
            _SectionLabel(label: 'TRANSCRIPTION ENGINES', color: _accentColor),
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: _collapseWhisperModels(plan.allowedTranscriptionModels)
                  .map((m) => _DetailChip(
                        label: m == 'whisper'
                            ? 'Whisper (all variants)'
                            : src.getModelDisplayName(m),
                        color: _accentColor,
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ── CTA ───────────────────────────────────────────────────────────────────────

  Widget _buildCta() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: widget.isCurrent || (plan.isTrial && widget.trialUsed)
            ? null
            : plan.isTrial
            ? () async {
                final err = await SubscriptionRemoteDataSource.instance
                    .activateTrial();
                if (err != null) {
                  AppLogger.e(
                    'Trial activation failed',
                    error: err,
                    tag: 'Trial',
                  );
                }
              }
            : () => SubscriptionRemoteDataSource.instance.openCheckout(plan.id),
        style: ElevatedButton.styleFrom(
          backgroundColor: plan.isTrial
              ? (widget.trialUsed ? Colors.white10 : Colors.amberAccent)
              : plan.isPopular
              ? Colors.tealAccent
              : Colors.white10,
          foregroundColor: plan.isTrial
              ? (widget.trialUsed ? Colors.white38 : Colors.black)
              : plan.isPopular
              ? Colors.black
              : Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 11),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.05),
        ),
        child: Text(
          widget.isCurrent
              ? 'Current Plan'
              : plan.isTrial
              ? (widget.trialUsed ? 'Trial Used' : 'Start Free Trial')
              : 'Select Plan',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final bool dim;

  const _Badge({required this.label, required this.color, this.dim = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: dim ? Colors.white38 : color,
          fontSize: 8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _QuotaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accentColor;

  const _QuotaRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 11, color: accentColor.withValues(alpha: 0.7)),
        const SizedBox(width: 5),
        Text(
          '$label: ',
          style: const TextStyle(color: Colors.white38, fontSize: 10),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: accentColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color color;

  const _SectionLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: color.withValues(alpha: 0.5),
        fontSize: 8,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final String label;
  final Color color;

  const _DetailChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color.withValues(alpha: 0.8),
          fontSize: 9,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

List<String> _collapseWhisperModels(List<String> models) {
  final result = <String>[];
  var whisperAdded = false;
  for (final m in models) {
    if (m.startsWith('whisper-')) {
      if (!whisperAdded) {
        result.add('whisper');
        whisperAdded = true;
      }
    } else {
      result.add(m);
    }
  }
  return result;
}
