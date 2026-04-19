import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:omni_bridge/core/navigation/app_router.dart';
import 'package:omni_bridge/core/theme/app_theme.dart';
import 'package:omni_bridge/core/utils/app_logger.dart';
import 'package:omni_bridge/core/widgets/omni_header.dart';
import 'package:omni_bridge/features/shell/presentation/widgets/app_dashboard_shell.dart';
import 'package:omni_bridge/features/subscription/data/datasources/subscription_remote_datasource.dart';
import 'package:omni_bridge/features/subscription/domain/entities/billing_info.dart';
import 'package:omni_bridge/features/subscription/domain/entities/payment_event.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

Color _accentColor(BillingInfo info) {
  if (info.isHalted || info.isCancelPending) return Colors.orange.shade400;
  return switch (info.tier.toLowerCase()) {
    'enterprise' => const Color(0xFFFFD700),
    'pro'        => Colors.tealAccent,
    'trial'      => Colors.purpleAccent,
    _            => Colors.white38,
  };
}

IconData _tierIcon(String tier) => switch (tier.toLowerCase()) {
      'enterprise' => Icons.workspace_premium_rounded,
      'pro'        => Icons.bolt_rounded,
      'trial'      => Icons.hourglass_top_rounded,
      _            => Icons.person_outline_rounded,
    };

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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: ValueListenableBuilder<BillingInfo>(
              valueListenable:
                  SubscriptionRemoteDataSource.instance.billingInfoNotifier,
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
      return _UpsellCard(tier: info.tier);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Hero card ──────────────────────────────────────────────────────
        _HeroCard(info: info),
        const SizedBox(height: 6),

        // ── Alert banner (halted / pending cancel) ─────────────────────────
        if (info.isHalted) ...[
          const SizedBox(height: 10),
          _AlertBanner(
            icon: Icons.warning_amber_rounded,
            color: Colors.orange.shade400,
            title: 'Payment Failed',
            body:
                'Razorpay attempted to renew your subscription but all retries '
                'failed. Re-subscribe below to restore access.',
          ),
        ] else if (info.isCancelPending) ...[
          const SizedBox(height: 10),
          _AlertBanner(
            icon: Icons.schedule_rounded,
            color: Colors.orange.shade400,
            title: 'Cancellation Scheduled',
            body:
                'Your ${info.tier == 'pro' ? 'Pro' : 'Enterprise'} access '
                'continues until ${info.endedAt != null ? DateFormat('d MMM yyyy').format(info.endedAt!) : 'the end of your billing period'}. '
                'After that your account moves to the Free plan.',
          ),
        ],

        const SizedBox(height: 20),

        // ── Subscription details ───────────────────────────────────────────
        _SectionHeader(
          icon: Icons.info_outline_rounded,
          label: 'SUBSCRIPTION DETAILS',
        ),
        const SizedBox(height: 10),
        _DetailsCard(info: info),

        // ── Actions ────────────────────────────────────────────────────────
        if (info.isActive || info.isHalted || info.isCancelled ||
            info.isCancelPending) ...[
          const SizedBox(height: 20),
          _SectionHeader(
            icon: Icons.tune_rounded,
            label: 'ACTIONS',
          ),
          const SizedBox(height: 10),
          _ActionsSection(info: info),
        ],

        // ── Payment history ────────────────────────────────────────────────
        const SizedBox(height: 20),
        _InvoiceSection(),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero card — gradient + left accent bar + stat cells
// ─────────────────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final BillingInfo info;
  const _HeroCard({required this.info});

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor(info);
    final now = DateTime.now();
    final fmt = DateFormat('d MMM');

    // Countdown
    final countdownDate =
        info.isCancelPending ? info.endedAt : info.nextBillingAt;
    final daysLeft =
        countdownDate?.difference(now).inDays.clamp(0, 999);

    // Cycle progress
    double? cycleProgress;
    if ((info.isActive || info.isCancelPending) &&
        info.nextBillingAt != null) {
      final end = info.nextBillingAt!;
      final start = end.subtract(const Duration(days: 30));
      final total = end.difference(start).inMilliseconds;
      final elapsed = now.difference(start).inMilliseconds;
      cycleProgress = (elapsed / total).clamp(0.0, 1.0);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              accent.withValues(alpha: 0.10),
              accent.withValues(alpha: 0.03),
              AppColors.cardBackground,
            ],
            stops: const [0.0, 0.35, 1.0],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accent.withValues(alpha: 0.22)),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left accent bar
              Container(
                width: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accent, accent.withValues(alpha: 0.25)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 1: badge + status + countdown
                      Row(
                        children: [
                          _TierBadge(info: info, accent: accent),
                          const SizedBox(width: 10),
                          _StatusPill(info: info),
                          const Spacer(),
                          if (daysLeft != null)
                            _CountdownChip(
                              days: daysLeft,
                              accent: accent,
                              isCancelPending: info.isCancelPending,
                            ),
                        ],
                      ),

                      // Progress bar
                      if (cycleProgress != null) ...[
                        const SizedBox(height: 14),
                        _GradientProgressBar(
                          progress: cycleProgress,
                          accent: accent,
                          daysLeft: daysLeft ?? 0,
                        ),
                      ],

                      // Stat cells
                      if (info.isActive || info.isCancelPending) ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            if (daysLeft != null)
                              _StatCell(
                                icon: info.isCancelPending
                                    ? Icons.hourglass_bottom_rounded
                                    : Icons.autorenew_rounded,
                                label: info.isCancelPending
                                    ? 'ENDS IN'
                                    : 'RENEWS IN',
                                value: '$daysLeft d',
                                accent: accent,
                              ),
                            if (daysLeft != null)
                              const SizedBox(width: 8),
                            if (info.lastPaymentFormatted != null)
                              _StatCell(
                                icon: Icons.payments_rounded,
                                label: 'AMOUNT',
                                value: info.lastPaymentFormatted!,
                                accent: accent,
                              ),
                            if (info.lastPaymentFormatted != null)
                              const SizedBox(width: 8),
                            if (countdownDate != null)
                              _StatCell(
                                icon: Icons.event_rounded,
                                label: info.isCancelPending
                                    ? 'UNTIL'
                                    : 'NEXT BILL',
                                value: fmt.format(countdownDate),
                                accent: accent,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Alert banner — halted / pending cancel
// ─────────────────────────────────────────────────────────────────────────────

class _AlertBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  const _AlertBanner({
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
        borderRadius: BorderRadius.circular(8),
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
                    fontWeight: FontWeight.w700,
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
// Subscription details card
// ─────────────────────────────────────────────────────────────────────────────

class _DetailsCard extends StatelessWidget {
  final BillingInfo info;
  const _DetailsCard({required this.info});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          if (info.since != null)
            _DetailRow(
              icon: Icons.calendar_today_rounded,
              label: 'Member since',
              value: fmt.format(info.since!),
            ),
          if (info.nextBillingAt != null && info.isActive)
            _DetailRow(
              icon: Icons.autorenew_rounded,
              label: 'Next billing',
              value: fmt.format(info.nextBillingAt!),
            ),
          if (info.endedAt != null && info.isCancelPending)
            _DetailRow(
              icon: Icons.event_available_rounded,
              label: 'Access until',
              value: fmt.format(info.endedAt!),
            ),
          if (info.endedAt != null && (info.isHalted || info.isCancelled))
            _DetailRow(
              icon: Icons.event_busy_rounded,
              label: 'Access ended',
              value: fmt.format(info.endedAt!),
            ),
          if (info.lastPaymentAt != null)
            _DetailRow(
              icon: Icons.payments_rounded,
              label: 'Last payment',
              value: [
                fmt.format(info.lastPaymentAt!),
                if (info.lastPaymentFormatted != null)
                  info.lastPaymentFormatted!,
              ].join('  ·  '),
              copyLabel: info.lastPaymentId,
              copyValue: info.lastPaymentId,
            ),
          if (info.subscriptionId != null)
            _DetailRow(
              icon: Icons.tag_rounded,
              label: 'Subscription ID',
              value: _truncate(info.subscriptionId!),
              copyLabel: info.subscriptionId,
              copyValue: info.subscriptionId,
              isLast: true,
            )
          else
            _DetailRow(
              icon: Icons.account_balance_wallet_rounded,
              label: 'Payment via',
              value: 'Razorpay',
              isLast: true,
            ),
        ],
      ),
    );
  }

  String _truncate(String s) =>
      s.length > 18 ? '${s.substring(0, 12)}…${s.substring(s.length - 4)}' : s;
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? copyValue;
  final String? copyLabel;
  final bool isLast;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.copyValue,
    this.copyLabel,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 12, color: AppColors.textDisabled),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (copyValue != null) ...[
                const SizedBox(width: 8),
                _CopyButton(value: copyValue!, label: copyLabel),
              ],
            ],
          ),
        ),
        if (!isLast)
          Divider(height: 1, color: AppColors.cardBorder.withValues(alpha: 0.6)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Actions section
// ─────────────────────────────────────────────────────────────────────────────

class _ActionsSection extends StatefulWidget {
  final BillingInfo info;
  const _ActionsSection({required this.info});

  @override
  State<_ActionsSection> createState() => _ActionsSectionState();
}

class _ActionsSectionState extends State<_ActionsSection> {
  bool _cancelling = false;
  bool _resuming = false;

  Future<void> _confirmResume() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Resume Subscription?',
            style: TextStyle(color: Colors.white, fontSize: 15)),
        content: const Text(
          'Your subscription will be reactivated on its original billing '
          'schedule. No new subscription is created and you will not be '
          'charged immediately.',
          style: TextStyle(
              color: AppColors.textMuted, fontSize: 12, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Resume',
                style: TextStyle(color: AppColors.accentTeal)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;
    setState(() => _resuming = true);
    final error =
        await SubscriptionRemoteDataSource.instance.resumeSubscription();
    if (!mounted) return;
    setState(() => _resuming = false);

    if (error != null) {
      AppLogger.e('Resume failed: $error');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Subscription reactivated. Welcome back!'),
        backgroundColor: Colors.teal,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _confirmCancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Cancel Subscription?',
            style: TextStyle(color: Colors.white, fontSize: 15)),
        content: Text(
          'You\'ll keep ${widget.info.tier == 'pro' ? 'Pro' : 'Enterprise'} '
          'access until the end of your current billing period. '
          'After that your account moves to the Free tier.',
          style: const TextStyle(
              color: AppColors.textMuted, fontSize: 12, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Plan',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel Subscription',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;
    setState(() => _cancelling = true);
    final error =
        await SubscriptionRemoteDataSource.instance.cancelSubscription();
    if (!mounted) return;
    setState(() => _cancelling = false);

    if (error != null) {
      AppLogger.e('Cancel failed: $error');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ));
    } else {
      final billing =
          SubscriptionRemoteDataSource.instance.billingInfoNotifier.value;
      final until = billing.endedAt != null
          ? ' Access continues until ${DateFormat('d MMM yyyy').format(billing.endedAt!)}.'
          : '';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Cancellation scheduled.$until'),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final isEnterprise = info.tier == 'enterprise';
    final tierName = isEnterprise ? 'Enterprise' : 'Pro';

    // Pending cancel — resume the existing subscription
    if (info.isCancelPending) {
      return _OutlineBtn(
        label: _resuming ? 'Resuming…' : 'Resume Subscription',
        icon: Icons.restart_alt_rounded,
        color: AppColors.accentTeal,
        isLoading: _resuming,
        onTap: _resuming ? null : _confirmResume,
      );
    }

    // Re-subscribe states (halted / fully ended)
    if (info.isHalted || info.isCancelled) {
      return _OutlineBtn(
        label: 'Re-subscribe to $tierName',
        icon: Icons.refresh_rounded,
        color: AppColors.accentTeal,
        onTap: () =>
            Navigator.pushReplacementNamed(context, AppRouter.subscription),
      );
    }

    // Active — upgrade + cancel
    if (info.isActive) {
      return Column(
        children: [
          if (!isEnterprise) ...[
            _OutlineBtn(
              label: 'Upgrade to Enterprise',
              icon: Icons.workspace_premium_rounded,
              color: const Color(0xFFFFD700),
              onTap: () => Navigator.pushReplacementNamed(
                  context, AppRouter.subscription),
            ),
            const SizedBox(height: 8),
          ],
          _OutlineBtn(
            label: _cancelling ? 'Cancelling…' : 'Cancel Subscription',
            icon: Icons.cancel_outlined,
            color: Colors.redAccent,
            isDestructive: true,
            isLoading: _cancelling,
            onTap: _cancelling ? null : _confirmCancel,
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Payment history section
// ─────────────────────────────────────────────────────────────────────────────

class _InvoiceSection extends StatelessWidget {
  const _InvoiceSection();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<PaymentEvent>>(
      valueListenable:
          SubscriptionRemoteDataSource.instance.invoicesNotifier,
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
            _SectionHeader(
              icon: Icons.receipt_long_rounded,
              label: 'PAYMENT HISTORY',
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < visible.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        color:
                            AppColors.cardBorder.withValues(alpha: 0.6),
                      ),
                    _InvoiceRow(event: visible[i]),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  final PaymentEvent event;
  const _InvoiceRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy');
    final isCharge = event.isCharge;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          // Icon
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isCharge
                  ? AppColors.accentTeal.withValues(alpha: 0.08)
                  : AppColors.cardBorder.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              isCharge
                  ? Icons.check_rounded
                  : Icons.info_outline_rounded,
              size: 13,
              color: isCharge
                  ? AppColors.accentTeal
                  : AppColors.textDisabled,
            ),
          ),
          const SizedBox(width: 12),
          // Label + date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  fmt.format(event.timestamp),
                  style: const TextStyle(
                    color: AppColors.textDisabled,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          // Amount
          if (event.amountFormatted != null)
            Text(
              event.amountFormatted!,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          // Payment ID copy button
          if (event.paymentId != null) ...[
            const SizedBox(width: 10),
            _CopyButton(value: event.paymentId!),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Upsell card — free / trial
// ─────────────────────────────────────────────────────────────────────────────

class _UpsellCard extends StatelessWidget {
  final String tier;
  const _UpsellCard({required this.tier});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.accentTeal.withValues(alpha: 0.08),
              AppColors.accentTeal.withValues(alpha: 0.02),
              AppColors.cardBackground,
            ],
            stops: const [0.0, 0.3, 1.0],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: AppColors.accentTeal.withValues(alpha: 0.18)),
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
                      AppColors.accentTeal.withValues(alpha: 0.25)
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.workspace_premium_rounded,
                        size: 32,
                        color: AppColors.accentTeal.withValues(alpha: 0.7),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        tier == 'trial'
                            ? 'You\'re on a free trial'
                            : 'You\'re on the Free plan',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
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
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pushReplacementNamed(
                              context, AppRouter.subscription),
                          icon: const Icon(Icons.arrow_forward_rounded,
                              size: 15),
                          label: const Text('View Plans'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentTeal,
                            foregroundColor: Colors.black,
                            padding:
                                const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                                borderRadius: AppShapes.md),
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable atoms
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 11, color: AppColors.textDisabled),
        const SizedBox(width: 7),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textDisabled,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(child: Divider(color: AppColors.white10, height: 1)),
      ],
    );
  }
}

class _TierBadge extends StatelessWidget {
  final BillingInfo info;
  final Color accent;
  const _TierBadge({required this.info, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_tierIcon(info.tier), size: 11, color: accent),
          const SizedBox(width: 5),
          Text(
            info.tier.toUpperCase(),
            style: TextStyle(
              color: accent,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final BillingInfo info;
  const _StatusPill({required this.info});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM');
    final (color, label) = switch (info.status) {
      'active'    => (Colors.greenAccent, 'Active'),
      'halted'    => (Colors.orange, 'Payment Failed'),
      'cancelled' when info.isCancelPending =>
        (Colors.orange,
            info.endedAt != null
                ? 'Cancels ${fmt.format(info.endedAt!)}'
                : 'Cancelled'),
      'cancelled' => (Colors.redAccent, 'Cancelled'),
      'completed' => (Colors.grey, 'Ended'),
      _           => (Colors.grey, 'Inactive'),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _CountdownChip extends StatelessWidget {
  final int days;
  final Color accent;
  final bool isCancelPending;
  const _CountdownChip(
      {required this.days,
      required this.accent,
      required this.isCancelPending});

  @override
  Widget build(BuildContext context) {
    final urgent = days <= 5;
    final chipColor = urgent ? Colors.orange.shade400 : accent;
    final label = isCancelPending ? '$days d left' : 'Renews in $days d';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: chipColor.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: chipColor, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _GradientProgressBar extends StatelessWidget {
  final double progress;
  final Color accent;
  final int daysLeft;
  const _GradientProgressBar(
      {required this.progress,
      required this.accent,
      required this.daysLeft});

  @override
  Widget build(BuildContext context) {
    final barColor = daysLeft <= 5 ? Colors.orange.shade400 : accent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            Container(
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            if (progress > 0)
              FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: LinearGradient(
                      colors: [
                        barColor.withValues(alpha: 0.5),
                        barColor,
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Billing cycle',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.22),
                fontSize: 9,
              ),
            ),
            Text(
              '$daysLeft days remaining',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.22),
                fontSize: 9,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  const _StatCell({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 9, color: accent.withValues(alpha: 0.6)),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textDisabled,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _OutlineBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool isDestructive;
  final bool isLoading;

  const _OutlineBtn({
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
    this.isDestructive = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: isLoading
            ? SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(
                    strokeWidth: 1.5, color: color),
              )
            : Icon(icon, size: 14, color: color),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.35)),
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape:
              RoundedRectangleBorder(borderRadius: AppShapes.md),
          backgroundColor: isDestructive
              ? color.withValues(alpha: 0.05)
              : Colors.transparent,
        ),
      ),
    );
  }
}

class _CopyButton extends StatefulWidget {
  final String value;
  final String? label;
  const _CopyButton({required this.value, this.label});

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  void _copy() {
    Clipboard.setData(ClipboardData(text: widget.label ?? widget.value));
    setState(() => _copied = true);
    Future.delayed(
        const Duration(seconds: 2),
        () => mounted ? setState(() => _copied = false) : null);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _copy,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: _copied
              ? Colors.greenAccent.withValues(alpha: 0.12)
              : AppColors.cardBorder.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: _copied
                ? Colors.greenAccent.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
        child: Icon(
          _copied ? Icons.check_rounded : Icons.copy_rounded,
          size: 11,
          color: _copied ? Colors.greenAccent : AppColors.textDisabled,
        ),
      ),
    );
  }
}
