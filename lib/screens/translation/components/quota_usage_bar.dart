import 'package:flutter/material.dart';
import '../../../core/services/firebase/subscription_service.dart';

Widget buildQuotaUsageBar(SubscriptionStatus status) {
  final color = status.progress > 0.9
      ? Colors.red
      : (status.progress > 0.7 ? Colors.orange : Colors.teal);

  return Container(
    height: 12,
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: Column(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: status.progress,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
      ],
    ),
  );
}
