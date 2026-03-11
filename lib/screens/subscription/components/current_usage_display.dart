import 'package:flutter/material.dart';
import '../../../models/subscription_models.dart';
import 'package:intl/intl.dart';

Widget buildCurrentUsageDisplay({
  required SubscriptionStatus status,
  required NumberFormat formatter,
}) {
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
            '${status.tier.toUpperCase()} UNLIMITED ACCESS ACTIVE',
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
      const SizedBox(height: 6),
      RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.white38, fontSize: 10),
          children: [
            TextSpan(
              text: formatter.format(status.dailyTokensUsed),
              style: const TextStyle(
                color: Colors.tealAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
            const TextSpan(
              text: ' / ',
            ),
            TextSpan(
              text: '${formatter.format(status.dailyLimit)} tokens used',
            ),
          ],
        ),
      ),
    ],
  );
}
