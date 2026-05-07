import 'package:flutter/material.dart';

import 'package:omni_bridge/core/di/di.dart';
import 'package:omni_bridge/core/navigation/app_router.dart';
import 'package:omni_bridge/core/theme/app_theme.dart';
import 'package:omni_bridge/core/widgets/omni_header.dart';
import 'package:omni_bridge/features/shell/presentation/widgets/app_dashboard_shell.dart';
import 'package:omni_bridge/features/subscription/domain/entities/billing_info.dart';
import 'package:omni_bridge/features/subscription/domain/entities/payment_event.dart';
import 'package:omni_bridge/features/subscription/domain/repositories/i_subscription_repository.dart';
import 'package:omni_bridge/features/subscription/domain/usecases/get_billing_period_summary.dart';
import 'package:omni_bridge/features/subscription/presentation/widgets/billing_footnote.dart';
import 'package:omni_bridge/features/subscription/presentation/widgets/billing_invoice_table.dart';
import 'package:omni_bridge/features/subscription/presentation/widgets/billing_payment_method_notice.dart';
import 'package:omni_bridge/features/subscription/presentation/widgets/billing_subscription_card.dart';
import 'package:omni_bridge/features/subscription/presentation/widgets/billing_usage_card.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

Color _accentColor(BillingInfo info) {
  if (info.isHalted || info.isCancelPending) return AppColors.amber;
  return switch (info.tier.toLowerCase()) {
    'enterprise' => AppColors.splashPurple,
    'pro' => AppColors.accentTeal,
    'trial' => AppColors.amber,
    _ => AppColors.textDisabled,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Root screen
// ─────────────────────────────────────────────────────────────────────────────

class BillingScreen extends StatelessWidget {
  const BillingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppDashboardShell(
      currentRoute: AppRouter.billing,
      header: OmniHeader(
        title: 'Billing',
        icon: Icons.receipt_long_rounded,
        onBack: () => Navigator.pop(context),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: ValueListenableBuilder<BillingInfo>(
              valueListenable:
                  sl<ISubscriptionRepository>().billingInfoNotifier,
              builder: (context, info, _) => _BillingBody(info: info),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Body — routes to the right layout per state
// ─────────────────────────────────────────────────────────────────────────────

class _BillingBody extends StatelessWidget {
  final BillingInfo info;
  const _BillingBody({required this.info});

  @override
  Widget build(BuildContext context) {
    if (!info.isPaidTier && !info.hasSubscription) {
      return const _UpsellLayout();
    }

    final accent = _accentColor(info);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _HeroBlock(),
        const SizedBox(height: 20),
        if (info.isHalted)
          _StatusBanner(
            icon: Icons.warning_amber_rounded,
            color: AppColors.amber,
            title: 'Payment failed',
            body:
                'Razorpay attempted to renew your subscription but all retries '
                'failed. Re-subscribe below to restore access.',
          ),
        if (info.isCancelPending)
          _StatusBanner(
            icon: Icons.schedule_rounded,
            color: AppColors.amber,
            title: 'Cancellation scheduled',
            body:
                'Your ${info.tier == 'pro' ? 'Pro' : 'Enterprise'} access continues until the end of the current billing period.',
          ),
        if (info.isHalted || info.isCancelPending) const SizedBox(height: 16),

        // ── Hero row: subscription card + usage card ────────────────────────
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 7,
                child: BillingSubscriptionCard(
                  info: info,
                  tierAccent: accent,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 9,
                child: BillingUsageCard(
                  summary: sl<GetBillingPeriodSummary>().call(
                    billingInfoOverride: info,
                  ),
                  tierAccent: accent,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        BillingPaymentMethodNotice(info: info),
        const SizedBox(height: 24),

        // ── Invoices ────────────────────────────────────────────────────────
        const _InvoiceSection(),

        const SizedBox(height: 16),
        const BillingFootnote(),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero block — title + subtitle + Compare Plans
// ─────────────────────────────────────────────────────────────────────────────

class _HeroBlock extends StatelessWidget {
  const _HeroBlock();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Billing',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Subscription, usage, and invoices for your Omni Bridge account.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context)
              .pushReplacementNamed(AppRouter.subscription),
          icon: const Icon(Icons.compare_arrows_rounded, size: 14),
          label: const Text('Compare Plans'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            side: BorderSide(color: AppColors.white(0.10)),
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status banner — halted / pending cancel
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const _StatusBanner({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: AppShapes.md,
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Invoice section — header label + table
// ─────────────────────────────────────────────────────────────────────────────

class _InvoiceSection extends StatelessWidget {
  const _InvoiceSection();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<PaymentEvent>>(
      valueListenable: sl<ISubscriptionRepository>().invoicesNotifier,
      builder: (context, events, _) {
        final visible = events
            .where((e) =>
                e.isCharge ||
                e.event == 'subscription_activated' ||
                e.event == 'subscription_cancelled' ||
                e.event == 'subscription_completed' ||
                e.event == 'upgraded' ||
                e.event == 'downgraded')
            .toList();

        if (visible.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.receipt_long_rounded,
                  size: 12,
                  color: AppColors.textDisabled,
                ),
                const SizedBox(width: 8),
                Text(
                  'INVOICES',
                  style: TextStyle(
                    color: AppColors.textDisabled,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Divider(color: AppColors.white10, height: 1),
                ),
              ],
            ),
            const SizedBox(height: 12),
            BillingInvoiceTable(events: visible),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Upsell layout — free / trial without subscription history
// ─────────────────────────────────────────────────────────────────────────────

class _UpsellLayout extends StatelessWidget {
  const _UpsellLayout();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _HeroBlock(),
        const SizedBox(height: 20),
        ClipRRect(
          borderRadius: AppShapes.md,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.accentTeal.withValues(alpha: 0.08),
                  AppColors.accentTeal.withValues(alpha: 0.02),
                  AppColors.cardBackground,
                ],
                stops: const [0.0, 0.3, 1.0],
              ),
              borderRadius: AppShapes.md,
              border: Border.all(
                color: AppColors.accentTeal.withValues(alpha: 0.18),
              ),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.accentTeal,
                          AppColors.accentTeal.withValues(alpha: 0.25),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.workspace_premium_rounded,
                            size: 36,
                            color: AppColors.accentTeal.withValues(alpha: 0.7),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'No active subscription',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Upgrade to Pro or Enterprise to unlock all engines, '
                            'higher quotas, and translation history.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: 220,
                            child: ElevatedButton.icon(
                              onPressed: () => Navigator.pushReplacementNamed(
                                context,
                                AppRouter.subscription,
                              ),
                              icon: const Icon(
                                Icons.arrow_forward_rounded,
                                size: 15,
                              ),
                              label: const Text('View Plans'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accentTeal,
                                foregroundColor: AppColors.black,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: AppShapes.md,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const BillingFootnote(),
      ],
    );
  }
}
