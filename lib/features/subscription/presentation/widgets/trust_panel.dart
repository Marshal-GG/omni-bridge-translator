import 'package:flutter/material.dart';

import 'package:omni_bridge/core/theme/app_theme.dart';

class TrustPanel extends StatelessWidget {
  const TrustPanel({super.key});

  static const _items = [
    _TrustItem(
      icon: Icons.bolt_rounded,
      title: 'On-device first',
      body: 'Whisper runs locally. Cloud calls only happen when you opt in.',
    ),
    _TrustItem(
      icon: Icons.lock_rounded,
      title: 'Razorpay secured',
      body:
          'UPI, cards, netbanking, wallets. No card data ever touches our servers.',
    ),
    _TrustItem(
      icon: Icons.refresh_rounded,
      title: 'Cancel any time',
      body: 'Access continues until period end. No retention games.',
    ),
    _TrustItem(
      icon: Icons.language_rounded,
      title: '100+ languages',
      body: 'Real-time translation across every major language pair.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WHY OMNI BRIDGE',
          style: TextStyle(
            color: AppColors.amber.withValues(alpha: 0.85),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            border: Border.all(color: AppColors.cardBorder),
            borderRadius: AppShapes.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < _items.length; i++) ...[
                if (i > 0) const SizedBox(height: 14),
                _TrustRow(item: _items[i]),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        const _MoneyBackCard(),
      ],
    );
  }
}

class _TrustItem {
  final IconData icon;
  final String title;
  final String body;
  const _TrustItem({
    required this.icon,
    required this.title,
    required this.body,
  });
}

class _TrustRow extends StatelessWidget {
  final _TrustItem item;

  const _TrustRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.white(0.04),
            border: Border.all(color: AppColors.cardBorder),
            borderRadius: AppShapes.sm,
          ),
          alignment: Alignment.center,
          child: Icon(item.icon, size: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.body,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MoneyBackCard extends StatelessWidget {
  const _MoneyBackCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.teal(0.10),
            AppColors.teal(0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.teal(0.30)),
        borderRadius: AppShapes.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '7-DAY MONEY-BACK',
            style: TextStyle(
              color: AppColors.accentTeal,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          RichText(
            text: const TextSpan(
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                height: 1.5,
              ),
              children: [
                TextSpan(text: 'Don’t love Pro? Email '),
                TextSpan(
                  text: 'support@omnibridge.marshalx.dev',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                TextSpan(
                  text: ' within 7 days of your first charge for a full refund.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
