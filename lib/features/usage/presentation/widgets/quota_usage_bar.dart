import 'package:flutter/material.dart';
import 'package:omni_bridge/features/usage/domain/entities/quota_status.dart';

Widget buildQuotaUsageBar(QuotaStatus status) {
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
