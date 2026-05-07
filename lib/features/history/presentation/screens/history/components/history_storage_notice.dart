import 'package:flutter/material.dart';

import 'package:omni_bridge/core/theme/app_theme.dart';

/// Single-card line that explains how history is stored. Replaces the
/// prototype's "1.2 MB used" copy because today's history is RAM-only —
/// see [docs/04_features/30_history_screen_redesign.md §1].
class HistoryStorageNotice extends StatelessWidget {
  const HistoryStorageNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white(0.02),
        borderRadius: AppShapes.sm,
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.memory_rounded,
                size: 12,
                color: AppColors.textMuted,
              ),
              SizedBox(width: 6),
              Text(
                'Session only',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            'History is held in memory and cleared on logout. Persistent local storage and cloud sync are coming for paid tiers.',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 10.5,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}
