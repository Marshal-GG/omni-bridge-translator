import 'package:flutter/material.dart';
import 'package:omni_bridge/core/theme/app_theme.dart';
import 'package:omni_bridge/features/startup/presentation/notifiers/update_notifier.dart';

class ShellOverlay extends StatelessWidget {
  final Widget child;

  const ShellOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        // Update notification bar/badge
        ListenableBuilder(
          listenable: UpdateNotifier.instance,
          builder: (context, _) {
            if (!UpdateNotifier.instance.value) return const SizedBox.shrink();

            final isForced = UpdateNotifier.instance.isForced;

            return Positioned(
              top: AppSpacing.md,
              right: AppSpacing.md,
              child: _buildUpdateBadge(context, isForced),
            );
          },
        ),
      ],
    );
  }

  Widget _buildUpdateBadge(BuildContext context, bool isForced) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isForced
              ? AppColors.accentRed.withValues(alpha: 0.1)
              : AppColors.accentCyan.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: (isForced ? AppColors.accentRed : AppColors.accentCyan)
                .withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: (isForced ? AppColors.accentRed : AppColors.accentCyan)
                  .withValues(alpha: 0.1),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isForced
                  ? Icons.priority_high_rounded
                  : Icons.system_update_alt_rounded,
              size: 16,
              color: isForced ? AppColors.accentRed : AppColors.accentCyan,
            ),
            const SizedBox(width: 8),
            Text(
              isForced ? 'Critical Update' : 'Update Available',
              style: TextStyle(
                color: isForced ? AppColors.accentRed : AppColors.accentCyan,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (!isForced) ...[
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => UpdateNotifier.instance.dismiss(),
                icon: const Icon(Icons.close_rounded, size: 14),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: AppColors.accentCyan.withValues(alpha: 0.6),
                hoverColor: AppColors.accentCyan.withValues(alpha: 0.1),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
