import 'package:flutter/material.dart';
import '../../domain/entities/subscription_plan.dart';
import 'package:intl/intl.dart';
import 'package:omni_bridge/features/subscription/data/datasources/subscription_remote_datasource.dart';
import 'package:omni_bridge/core/widgets/omni_card.dart';

Widget buildPlanCard({
  required SubscriptionPlan plan,
  bool isCurrent = false,
  bool trialUsed = false,
  required NumberFormat formatter,
}) {
  final isHighlighted = plan.isTrial || plan.isPopular;
  final accentColor = plan.isTrial
      ? Colors.amberAccent
      : plan.isPopular
      ? Colors.tealAccent
      : Colors.white70;
  final cardBaseColor = plan.isTrial
      ? Colors.amberAccent
      : plan.isPopular
      ? Colors.tealAccent
      : Colors.white;

  return OmniCard(
    baseColor: cardBaseColor,
    hasGlow: isHighlighted,
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Header: Name + Popular Badge ────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              plan.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (plan.isTrial)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amberAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: Colors.amberAccent.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  trialUsed ? 'USED' : 'ONE-TIME',
                  style: TextStyle(
                    color: trialUsed ? Colors.white38 : Colors.amberAccent,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else if (plan.isPopular)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.tealAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: Colors.tealAccent.withValues(alpha: 0.3),
                  ),
                ),
                child: const Text(
                  'POPULAR',
                  style: TextStyle(
                    color: Colors.tealAccent,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),

        // ── Price ───────────────────────────────────────────────────
        Text(
          plan.price,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          plan.description,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),

        const SizedBox(height: 12),
        const Divider(color: Colors.white12),
        const SizedBox(height: 12),

        // ── Quota Summary ──────────────────────────────────────────
        _QuotaRow(
          icon: Icons.today_rounded,
          label: 'Daily',
          value: plan.isUnlimited
              ? 'Unlimited'
              : '${formatter.format(plan.dailyTokens)} tokens',
          accentColor: accentColor,
        ),
        if (plan.isTrial) ...[
          const SizedBox(height: 6),
          _QuotaRow(
            icon: Icons.timer_outlined,
            label: 'Duration',
            value: plan.trialDurationHours >= 24
                ? '${plan.trialDurationHours ~/ 24} day${plan.trialDurationHours ~/ 24 > 1 ? 's' : ''}'
                : '${plan.trialDurationHours}h',
            accentColor: accentColor,
          ),
        ] else if (plan.monthlyTokens != 0) ...[
          const SizedBox(height: 6),
          _QuotaRow(
            icon: Icons.calendar_month_rounded,
            label: 'Monthly',
            value: plan.monthlyTokens < 0
                ? 'Unlimited'
                : '${formatter.format(plan.monthlyTokens)} tokens',
            accentColor: accentColor,
          ),
        ],
        const SizedBox(height: 6),
        _QuotaRow(
          icon: Icons.devices_rounded,
          label: 'Sessions',
          value: '${plan.concurrentSessions} concurrent',
          accentColor: accentColor,
        ),

        const SizedBox(height: 12),
        const Divider(color: Colors.white12),
        const SizedBox(height: 12),

        // ── Features ────────────────────────────────────────────────
        ...plan.features.map(
          (f) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.tealAccent,
                  size: 14,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    f,
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Allowed Models ──────────────────────────────────────────
        if (plan.allowedTranslationModels.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text(
            'TRANSLATION ENGINES',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 8,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: plan.allowedTranslationModels.map((m) {
              final limit = plan.engineLimits[m];
              final suffix = limit != null
                  ? ' (${formatter.format(limit)}/mo)'
                  : '';
              return _ModelChip(
                label:
                    '${SubscriptionRemoteDataSource.instance.getModelDisplayName(m)}$suffix',
              );
            }).toList(),
          ),
        ],
        if (plan.allowedTranscriptionModels.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text(
            'TRANSCRIPTION',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 8,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: plan.allowedTranscriptionModels.map((m) {
              return _ModelChip(
                label: SubscriptionRemoteDataSource.instance.getModelDisplayName(m),
              );
            }).toList(),
          ),
        ],

        const SizedBox(height: 16),

        // ── CTA Button ──────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isCurrent || (plan.isTrial && trialUsed)
                ? null
                : plan.isTrial
                ? () async {
                    final err = await SubscriptionRemoteDataSource.instance
                        .activateTrial();
                    if (err != null) {
                      debugPrint('[Trial] $err');
                    }
                  }
                : () => SubscriptionRemoteDataSource.instance.openCheckout(plan.id),
            style: ElevatedButton.styleFrom(
              backgroundColor: plan.isTrial
                  ? (trialUsed ? Colors.white10 : Colors.amberAccent)
                  : plan.isPopular
                  ? Colors.tealAccent
                  : Colors.white10,
              foregroundColor: plan.isTrial
                  ? (trialUsed ? Colors.white38 : Colors.black)
                  : plan.isPopular
                  ? Colors.black
                  : Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              disabledBackgroundColor: Colors.white.withValues(alpha: 0.05),
            ),
            child: Text(
              isCurrent
                  ? 'Current Plan'
                  : plan.isTrial
                  ? (trialUsed ? 'Trial Used' : 'Start Free Trial')
                  : 'Select Plan',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    ),
  );
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
        Icon(icon, size: 12, color: accentColor.withValues(alpha: 0.7)),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: const TextStyle(color: Colors.white38, fontSize: 10),
        ),
        Text(
          value,
          style: TextStyle(
            color: accentColor,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ModelChip extends StatelessWidget {
  final String label;

  const _ModelChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 8,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
