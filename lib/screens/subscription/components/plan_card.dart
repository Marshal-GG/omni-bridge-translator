import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/firebase/subscription_service.dart';

Widget buildPlanCard({
  required SubscriptionPlan plan,
  bool isCurrent = false,
  required NumberFormat formatter,
}) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: plan.isPopular
          ? Colors.tealAccent.withValues(alpha: 0.05)
          : Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: plan.isPopular
            ? Colors.tealAccent.withValues(alpha: 0.3)
            : Colors.white.withValues(alpha: 0.08),
        width: 1,
      ),
      boxShadow: plan.isPopular
          ? [
              BoxShadow(
                color: Colors.tealAccent.withValues(alpha: 0.08),
                blurRadius: 25,
                spreadRadius: 2,
              ),
            ]
          : null,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
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
            if (plan.isPopular)
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              plan.price,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          plan.description,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 12),
        const Divider(color: Colors.white12),
        const SizedBox(height: 12),
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
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isCurrent
                ? null
                : () => SubscriptionService.instance.openCheckout(plan.id),
            style: ElevatedButton.styleFrom(
              backgroundColor: plan.isPopular
                  ? Colors.tealAccent
                  : Colors.white10,
              foregroundColor: plan.isPopular ? Colors.black : Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              disabledBackgroundColor: Colors.white.withValues(alpha: 0.05),
            ),
            child: Text(
              isCurrent ? 'Current Plan' : 'Select Plan',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    ),
  );
}
