import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

Widget buildSupportFooter(BuildContext context) {
  return Wrap(
    spacing: AppSpacing.sm,
    runSpacing: 6.0,
    alignment: WrapAlignment.center,
    children: [
      _buildFooterLink(context, 'FAQ', AppColors.accentCyan, () {
        Navigator.of(context).pushNamed('/help-center');
      }),
      _buildFooterLink(context, 'Settings', AppColors.translationTeal, () {
        Navigator.pushNamed(context, '/settings-overlay');
      }),
      _buildFooterLink(context, 'Account', AppColors.accentCyan, () {
        Navigator.pushNamed(context, '/account');
      }),
      _buildFooterLink(context, 'About', AppColors.translationTeal, () {
        Navigator.pushNamed(context, '/about');
      }),
      _buildFooterLink(context, 'Plans', AppColors.accentCyan, () {
        Navigator.pushNamed(context, '/subscription');
      }),
    ],
  );
}

Widget _buildFooterLink(
  BuildContext context,
  String text,
  Color color,
  VoidCallback onTap,
) {
  return SizedBox(
    height: 36,
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
        side: BorderSide(color: color.withValues(alpha: 0.3), width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: AppShapes.md),
        foregroundColor: color.withValues(alpha: 0.9),
      ),
      child: Text(
        text,
        style: AppTextStyles.body.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    ),
  );
}
