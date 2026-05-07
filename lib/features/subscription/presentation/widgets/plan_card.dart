import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/entities/subscription_plan.dart';
import '../bloc/subscription_state.dart';
import 'package:intl/intl.dart';
import 'package:omni_bridge/core/di/di.dart';
import 'package:omni_bridge/core/theme/app_theme.dart';
import 'package:omni_bridge/features/subscription/domain/repositories/i_subscription_repository.dart';
import 'package:omni_bridge/core/widgets/omni_card.dart';

Widget buildPlanCard({
  required SubscriptionPlan plan,
  bool isCurrent = false,
  bool trialUsed = false,
  BillingCycle billingCycle = BillingCycle.monthly,
  required NumberFormat formatter,
}) {
  return _PlanCard(
    plan: plan,
    isCurrent: isCurrent,
    trialUsed: trialUsed,
    billingCycle: billingCycle,
    formatter: formatter,
  );
}

// ── Stateful card ─────────────────────────────────────────────────────────────

class _PlanCard extends StatefulWidget {
  final SubscriptionPlan plan;
  final bool isCurrent;
  final bool trialUsed;
  final BillingCycle billingCycle;
  final NumberFormat formatter;

  const _PlanCard({
    required this.plan,
    required this.isCurrent,
    required this.trialUsed,
    required this.billingCycle,
    required this.formatter,
  });

  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard> with WidgetsBindingObserver {
  bool _ctaLoading = false;
  bool _paymentPending = false;
  bool _hovered = false;
  Timer? _pendingTimeout;
  Timer? _resumeGraceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(_PlanCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Tier confirmed by webhook — clear pending state
    if (!oldWidget.isCurrent && widget.isCurrent && _paymentPending) {
      _pendingTimeout?.cancel();
      setState(() => _paymentPending = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pendingTimeout?.cancel();
    _resumeGraceTimer?.cancel();
    super.dispose();
  }

  /// When the user returns from the browser after a pending payment, give the
  /// webhook 30 seconds to write the tier. If it doesn't arrive, assume the
  /// payment was cancelled or failed and reset so the user can retry.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _paymentPending) {
      _resumeGraceTimer?.cancel();
      _resumeGraceTimer = Timer(const Duration(seconds: 30), () {
        if (!mounted || !_paymentPending) return;
        setState(() => _paymentPending = false);
        _pendingTimeout?.cancel();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Payment not confirmed. If you completed payment, it may take a moment — otherwise please try again.',
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 6),
          ),
        );
      });
    }
  }

  void _startPendingTimeout() {
    _pendingTimeout?.cancel();
    _pendingTimeout = Timer(const Duration(minutes: 10), () {
      if (mounted) setState(() => _paymentPending = false);
    });
  }

  SubscriptionPlan get plan => widget.plan;
  NumberFormat get fmt => widget.formatter;

  Color get _accentColor {
    if (plan.id == 'enterprise') return AppColors.splashPurple;
    if (plan.isTrial) return Colors.amberAccent;
    if (plan.isPopular) return Colors.tealAccent;
    return Colors.white70;
  }

  @override
  Widget build(BuildContext context) {
    final cardBaseColor = plan.id == 'enterprise'
        ? AppColors.splashPurple
        : plan.isTrial
        ? Colors.amberAccent
        : plan.isPopular
        ? Colors.tealAccent
        : Colors.white;

    final card = OmniCard(
      baseColor: cardBaseColor,
      hasGlow: false,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 4),
          _buildPrice(),
          const SizedBox(height: 2),
          Text(
            plan.description,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 10),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 10),
          _buildQuota(),
          const SizedBox(height: 10),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 10),
          Expanded(child: _buildFeatures()),
          const SizedBox(height: 12),
          _buildCta(),
        ],
      ),
    );

    final showPopularRibbon = plan.isPopular;
    final showCurrentRibbon = widget.isCurrent && !plan.isPopular;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: _hovered
            ? (Matrix4.identity()..translateByDouble(0, -3, 0, 1))
            : Matrix4.identity(),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            card,
            if (showPopularRibbon)
              Positioned(
                top: -8,
                left: 0,
                right: 0,
                child: Center(
                  child: _PlanRibbon(
                    label: 'MOST POPULAR',
                    accent: Colors.tealAccent,
                    solid: true,
                  ),
                ),
              ),
            if (showCurrentRibbon)
              Positioned(
                top: -8,
                left: 0,
                right: 0,
                child: Center(
                  child: _PlanRibbon(
                    label: 'YOUR PLAN',
                    accent: _accentColor,
                    solid: false,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          plan.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (plan.isTrial)
          _Badge(
            label: widget.trialUsed ? 'USED' : 'ONE-TIME',
            color: Colors.amberAccent,
            dim: widget.trialUsed,
          ),
      ],
    );
  }

  // ── Price ───────────────────────────────────────────────────────────────────

  Widget _buildPrice() {
    final pricing = _pricingFor(plan, widget.billingCycle);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                pricing.displayPrice,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  pricing.displayPeriod,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ),
            ),
          ],
        ),
        if (pricing.discountPercent > 0)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'Save ${pricing.discountPercent}% billed yearly',
              style: TextStyle(
                color: _accentColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }

  // ── Quota ───────────────────────────────────────────────────────────────────

  Widget _buildQuota() {
    return Column(
      children: [
        _QuotaRow(
          icon: Icons.today_rounded,
          label: 'Daily',
          value: plan.isUnlimited
              ? 'Unlimited'
              : '${fmt.format(plan.dailyTokens)} tokens',
          accentColor: _accentColor,
        ),
        if (plan.isTrial) ...[
          const SizedBox(height: 4),
          _QuotaRow(
            icon: Icons.timer_outlined,
            label: 'Duration',
            value: plan.trialDurationHours >= 24
                ? '${plan.trialDurationHours ~/ 24} day${plan.trialDurationHours ~/ 24 > 1 ? 's' : ''}'
                : '${plan.trialDurationHours}h',
            accentColor: _accentColor,
          ),
        ] else if (plan.monthlyTokens != 0) ...[
          const SizedBox(height: 4),
          _QuotaRow(
            icon: Icons.calendar_month_rounded,
            label: 'Monthly',
            value: plan.monthlyTokens < 0
                ? 'Unlimited'
                : '${fmt.format(plan.monthlyTokens)} tokens',
            accentColor: _accentColor,
          ),
        ],
        const SizedBox(height: 4),
        _QuotaRow(
          icon: Icons.devices_rounded,
          label: 'Sessions',
          value: '${plan.concurrentSessions} concurrent',
          accentColor: _accentColor,
        ),
      ],
    );
  }

  // ── Features ─────────────────────────────────────────────────────────────────

  Widget _buildFeatures() {
    return Column(
      children: plan.features.map((f) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                Icons.check_circle_rounded,
                color: plan.isTrial ? Colors.amberAccent : Colors.tealAccent,
                size: 12,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                f,
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }

  // ── CTA ───────────────────────────────────────────────────────────────────────

  Future<void> _handleCta() async {
    setState(() => _ctaLoading = true);
    final err = plan.isTrial
        ? await sl<ISubscriptionRepository>().activateTrial()
        : await sl<ISubscriptionRepository>().openCheckout(plan.id);
    if (!mounted) return;
    setState(() => _ctaLoading = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (!plan.isTrial) {
      // Checkout URL opened — wait for webhook to confirm payment
      setState(() => _paymentPending = true);
      _startPendingTimeout();
    }
  }

  Widget _buildCta() {
    final isDisabled = widget.isCurrent || (plan.isTrial && widget.trialUsed);
    final isPending = _paymentPending && !widget.isCurrent;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isDisabled || _ctaLoading || isPending ? null : _handleCta,
        style: ElevatedButton.styleFrom(
          backgroundColor: plan.isTrial
              ? (widget.trialUsed ? Colors.white10 : Colors.amberAccent)
              : plan.isPopular
              ? Colors.tealAccent
              : Colors.white10,
          foregroundColor: plan.isTrial
              ? (widget.trialUsed ? Colors.white38 : Colors.black)
              : plan.isPopular
              ? Colors.black
              : Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 11),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          disabledBackgroundColor: isPending
              ? _accentColor.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.05),
          disabledForegroundColor: isPending
              ? _accentColor.withValues(alpha: 0.6)
              : null,
        ),
        child: _ctaLoading
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: plan.isPopular || plan.isTrial
                      ? Colors.black54
                      : Colors.white54,
                ),
              )
            : isPending
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: _accentColor.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'Awaiting Payment...',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _accentColor.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              )
            : Text(
                widget.isCurrent
                    ? 'Current Plan'
                    : plan.isTrial
                    ? (widget.trialUsed ? 'Trial Used' : 'Start Free Trial')
                    : 'Select Plan',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700),
              ),
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final bool dim;

  const _Badge({required this.label, required this.color, this.dim = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: dim ? Colors.white38 : color,
          fontSize: 8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _QuotaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accentColor;

  const _QuotaRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 11, color: accentColor.withValues(alpha: 0.7)),
        const SizedBox(width: 5),
        Text(
          '$label: ',
          style: const TextStyle(color: Colors.white38, fontSize: 10),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: accentColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── Ribbon ────────────────────────────────────────────────────────────────────

class _PlanRibbon extends StatelessWidget {
  final String label;
  final Color accent;
  final bool solid;

  const _PlanRibbon({
    required this.label,
    required this.accent,
    required this.solid,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: solid ? accent : AppColors.bgDeepest,
        borderRadius: AppShapes.sm,
        border: solid
            ? null
            : Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
          color: solid ? AppColors.black : accent,
        ),
      ),
    );
  }
}

// ── Pricing helper ────────────────────────────────────────────────────────────

class _PlanPricing {
  final String displayPrice;
  final String displayPeriod;
  final int discountPercent;

  const _PlanPricing(
    this.displayPrice,
    this.displayPeriod,
    this.discountPercent,
  );
}

_PlanPricing _pricingFor(SubscriptionPlan plan, BillingCycle cycle) {
  if (cycle == BillingCycle.yearly) {
    if (plan.id == 'pro') return const _PlanPricing('₹6,990', 'per year', 27);
    if (plan.id == 'enterprise') {
      return const _PlanPricing('₹49,990', 'per year', 17);
    }
  }
  final period = plan.isTrial
      ? '24 hours'
      : plan.id == 'free'
      ? 'forever'
      : 'per month';
  return _PlanPricing(plan.price, period, 0);
}

