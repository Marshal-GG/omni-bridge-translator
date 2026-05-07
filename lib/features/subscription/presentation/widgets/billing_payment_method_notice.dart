import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:omni_bridge/core/theme/app_theme.dart';
import 'package:omni_bridge/core/utils/app_logger.dart';
import 'package:omni_bridge/features/subscription/domain/entities/billing_info.dart';

/// One-line summary of the most recent payment method + a "Manage in Razorpay"
/// link. Replaces the prototype's full Payment Methods CRUD because the app
/// doesn't hold card details — Razorpay does (see `docs/04_features/29` §1).
class BillingPaymentMethodNotice extends StatelessWidget {
  final BillingInfo info;
  const BillingPaymentMethodNotice({required this.info, super.key});

  Future<void> _openPortal(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      AppLogger.w('Failed to open Razorpay portal: $e',
          tag: 'BillingPaymentMethodNotice');
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = info.lastPaymentMethodSummary ??
        _fallbackSummary(info.lastPaymentMethod);
    final portalUrl = info.customerPortalUrl;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: AppShapes.md,
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.accentTeal.withValues(alpha: 0.10),
              borderRadius: AppShapes.sm,
              border: Border.all(
                color: AppColors.accentTeal.withValues(alpha: 0.22),
              ),
            ),
            child: Icon(
              Icons.account_balance_wallet_outlined,
              size: 15,
              color: AppColors.accentTeal,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment method',
                  style: TextStyle(
                    color: AppColors.textDisabled,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  summary ?? 'Managed by Razorpay',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (portalUrl != null)
            OutlinedButton.icon(
              onPressed: () => _openPortal(portalUrl),
              icon: const Icon(Icons.open_in_new_rounded, size: 13),
              label: const Text('Manage in Razorpay'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: BorderSide(
                  color: AppColors.white(0.12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                textStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(borderRadius: AppShapes.sm),
              ),
            ),
        ],
      ),
    );
  }

  String? _fallbackSummary(String? method) {
    if (method == null) return null;
    return switch (method) {
      'upi' => 'UPI',
      'card' => 'Card',
      'netbanking' => 'Net Banking',
      'wallet' => 'Wallet',
      _ => method,
    };
  }
}
