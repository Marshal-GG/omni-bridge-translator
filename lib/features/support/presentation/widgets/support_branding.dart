import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

Widget buildSupportBranding(BuildContext context) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      ClipRRect(
        borderRadius: AppShapes.xl,
        child: Image.asset(
          'assets/app/icons/icon.png',
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 56,
              height: 56,
              color: AppColors.white10,
              child: const Icon(
                Icons.help_outline_rounded,
                color: AppColors.accentCyan,
                size: 32,
              ),
            );
          },
        ),
      ),
      const SizedBox(width: 16),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Omni Bridge',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          Text(
            'SUPPORT & FEEDBACK',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.accentCyan,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    ],
  );
}
