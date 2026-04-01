import 'package:flutter/material.dart';
import '../../domain/entities/system_snapshot.dart';

class DiagnosticsPreview extends StatelessWidget {
  final SystemSnapshot? snapshot;

  const DiagnosticsPreview({super.key, this.snapshot});

  @override
  Widget build(BuildContext context) {
    if (snapshot == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.analytics_outlined,
                size: 16,
                color: Colors.blueAccent,
              ),
              const SizedBox(width: 8),
              Text(
                'System Diagnostics (Attached Automatically)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildInfoRow('OS Version', snapshot!.osVersion),
          _buildInfoRow('App Version', snapshot!.appVersion),
          _buildInfoRow('Subscription', snapshot!.subscriptionTier),
          _buildInfoRow(
            'Remaining Quota',
            '${snapshot!.remainingQuota} characters',
          ),
          _buildInfoRow('User', snapshot!.userEmail),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.white38),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 11, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
