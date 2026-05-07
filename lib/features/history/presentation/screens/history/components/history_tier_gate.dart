import 'package:flutter/material.dart';

import 'package:omni_bridge/core/navigation/app_router.dart';
import 'package:omni_bridge/core/theme/app_theme.dart';

/// Tier-locked placeholder shown either as the full screen body (free tier)
/// or as the centre-column body when the active stream is gated to a higher
/// tier (5-sec re-translations on Pro+).
class HistoryTierGate extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String requiredTier;

  const HistoryTierGate({
    required this.icon,
    required this.title,
    required this.body,
    required this.requiredTier,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 56),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: AppShapes.md,
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.amber.withValues(alpha: 0.10),
              shape: BoxShape.circle,
              border:
                  Border.all(color: AppColors.amber.withValues(alpha: 0.30)),
            ),
            child: Icon(icon, size: 28, color: AppColors.amber),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.amber.withValues(alpha: 0.14),
              borderRadius: AppShapes.sm,
              border: Border.all(
                color: AppColors.amber.withValues(alpha: 0.45),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 12,
                  color: AppColors.amber,
                ),
                const SizedBox(width: 6),
                Text(
                  'Requires $requiredTier',
                  style: const TextStyle(
                    color: AppColors.amber,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context)
                .pushReplacementNamed(AppRouter.subscription),
            icon: const Icon(Icons.compare_arrows_rounded, size: 13),
            label: const Text('View Plans'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accentTeal,
              side: BorderSide(
                color: AppColors.accentTeal.withValues(alpha: 0.4),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: AppShapes.sm),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
