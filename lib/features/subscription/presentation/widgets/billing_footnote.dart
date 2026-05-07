import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:omni_bridge/core/theme/app_theme.dart';
import 'package:omni_bridge/core/utils/app_logger.dart';

/// Disclaimer at the bottom of the Billing screen — explains why no card data
/// shows in-app and points users at billing support. Mirrors the prototype's
/// footnote block.
class BillingFootnote extends StatelessWidget {
  static const _email = 'billing@omnibridge.marshalx.dev';

  const BillingFootnote({super.key});

  Future<void> _launchEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: _email,
      query: 'subject=Billing question',
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (e) {
      AppLogger.w('Failed to launch mailto: $e', tag: 'BillingFootnote');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: AppShapes.md,
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.shield_outlined,
                size: 13,
                color: AppColors.textDisabled,
              ),
              const SizedBox(width: 8),
              Text(
                'Payments and refunds',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text.rich(
            TextSpan(
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                height: 1.55,
              ),
              children: [
                TextSpan(
                  text:
                      'All payments are processed by Razorpay. Your card and UPI details never reach Omni Bridge — Razorpay holds them on its PCI-DSS-compliant infrastructure. ',
                ),
                TextSpan(
                  text:
                      'Refunds are processed within 7 business days to the original payment method. ',
                ),
                TextSpan(
                  text: 'Questions about an invoice? Email ',
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: _launchEmail,
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.mail_outline_rounded,
                  size: 12,
                  color: AppColors.accentTeal,
                ),
                const SizedBox(width: 6),
                Text(
                  _email,
                  style: const TextStyle(
                    color: AppColors.accentTeal,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.accentTeal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
