import 'package:flutter/material.dart';
import 'package:omni_bridge/data/models/subscription_models.dart';
import 'package:omni_bridge/data/services/firebase/subscription_service.dart';
import 'package:intl/intl.dart';

Widget buildCurrentUsageDisplay({
  required SubscriptionStatus status,
  required NumberFormat formatter,
}) {
  final tierName = SubscriptionService.instance.getNameForTier(status.tier).toUpperCase();

  if (status.isUnlimited) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded, color: Colors.tealAccent, size: 16),
          const SizedBox(width: 8),
          Text(
            '$tierName UNLIMITED ACCESS ACTIVE',
            style: const TextStyle(
              color: Colors.tealAccent,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Daily Quota Usage',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          Text(
            '${(status.progress * 100).toInt()}%',
            style: const TextStyle(
              color: Colors.tealAccent,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: status.progress,
          backgroundColor: Colors.white10,
          color: status.progress > 0.9 ? Colors.redAccent : Colors.tealAccent,
          minHeight: 5,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        '${formatter.format(status.dailyTokensUsed)} / ${formatter.format(status.dailyLimit)} today',
        style: const TextStyle(color: Colors.white38, fontSize: 10),
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _UsageBadge(
            label: 'WEEKLY',
            value: formatter.format(status.weeklyTokensUsed),
          ),
          _UsageBadge(
            label: 'MONTHLY',
            value: formatter.format(status.monthlyTokensUsed),
          ),
          _UsageBadge(
            label: 'LIFETIME',
            value: formatter.format(status.lifetimeTokensUsed),
          ),
        ],
      ),
    ],
  );
}

class _UsageBadge extends StatelessWidget {
  final String label;
  final String value;

  const _UsageBadge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.tealAccent,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
