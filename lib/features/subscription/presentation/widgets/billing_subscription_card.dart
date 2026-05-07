import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:omni_bridge/core/di/di.dart';
import 'package:omni_bridge/core/navigation/app_router.dart';
import 'package:omni_bridge/core/theme/app_theme.dart';
import 'package:omni_bridge/core/utils/app_logger.dart';
import 'package:omni_bridge/features/subscription/domain/entities/billing_info.dart';
import 'package:omni_bridge/features/subscription/domain/repositories/i_subscription_repository.dart';
import 'package:omni_bridge/features/subscription/domain/usecases/cancel_subscription_usecase.dart';
import 'package:omni_bridge/features/subscription/domain/usecases/resume_subscription_usecase.dart';

/// Left half of the Billing screen's hero row. Combines the tier-tinted
/// gradient header, key/value grid, and primary subscription actions
/// (Cancel / Resume / Re-subscribe) in one card. Replaces the older
/// `_HeroCard` + `_DetailsCard` + `_ActionsSection` triplet.
class BillingSubscriptionCard extends StatefulWidget {
  final BillingInfo info;
  final Color tierAccent;

  const BillingSubscriptionCard({
    required this.info,
    required this.tierAccent,
    super.key,
  });

  @override
  State<BillingSubscriptionCard> createState() =>
      _BillingSubscriptionCardState();
}

class _BillingSubscriptionCardState extends State<BillingSubscriptionCard> {
  bool _hovered = false;
  bool _cancelling = false;
  bool _resuming = false;

  Future<void> _confirmCancel() async {
    final info = widget.info;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: AppShapes.lg),
        title: const Text(
          'Cancel Subscription?',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
        ),
        content: Text(
          'You\'ll keep ${info.tier == 'pro' ? 'Pro' : 'Enterprise'} access '
          'until the end of your current billing period. After that your '
          'account moves to the Free tier.',
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Keep Plan',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Cancel Subscription',
              style: TextStyle(color: AppColors.accentRed),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;
    setState(() => _cancelling = true);
    final error = await sl<CancelSubscriptionUseCase>()();
    if (!mounted) return;
    setState(() => _cancelling = false);

    if (error != null) {
      AppLogger.e('Cancel failed: $error');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error),
        backgroundColor: AppColors.accentRed,
        behavior: SnackBarBehavior.floating,
      ));
    } else {
      final billing = sl<ISubscriptionRepository>().billingInfoNotifier.value;
      final until = billing.endedAt != null
          ? ' Access continues until ${DateFormat('d MMM yyyy').format(billing.endedAt!)}.'
          : '';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Cancellation scheduled.$until'),
        backgroundColor: AppColors.amber,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ));
    }
  }

  Future<void> _confirmResume() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: AppShapes.lg),
        title: const Text(
          'Resume Subscription?',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
        ),
        content: const Text(
          'Your subscription will be reactivated on its original billing '
          'schedule. No new subscription is created and you will not be '
          'charged immediately.',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Resume',
              style: TextStyle(color: AppColors.accentTeal),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;
    setState(() => _resuming = true);
    final error = await sl<ResumeSubscriptionUseCase>()();
    if (!mounted) return;
    setState(() => _resuming = false);

    if (error != null) {
      AppLogger.e('Resume failed: $error');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error),
        backgroundColor: AppColors.accentRed,
        behavior: SnackBarBehavior.floating,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Subscription reactivated. Welcome back!'),
        backgroundColor: AppColors.accentTeal,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final accent = widget.tierAccent;
    final fmt = DateFormat('d MMM yyyy');
    final tierName = _tierName(info.tier);
    final priceText = _priceText(info);

    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform:
            Matrix4.identity()..translateByDouble(0, _hovered ? -3 : 0, 0, 1),
        child: ClipRRect(
          borderRadius: AppShapes.md,
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
              borderRadius: AppShapes.md,
              border: Border.all(color: accent.withValues(alpha: 0.22)),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Header(
                            tierName: tierName,
                            priceText: priceText,
                            accent: accent,
                            tierIcon: _tierIcon(info.tier),
                            statusInfo: info,
                          ),
                          const SizedBox(height: 14),
                          _renewalLine(info, accent, fmt),
                          const SizedBox(height: 16),
                          _kvGrid(info, fmt),
                          const SizedBox(height: 18),
                          _actionButtons(info, accent),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _renewalLine(BillingInfo info, Color accent, DateFormat fmt) {
    final (icon, color, text) = _renewalDescription(info, accent, fmt);
    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  (IconData, Color, String) _renewalDescription(
    BillingInfo info,
    Color accent,
    DateFormat fmt,
  ) {
    if (info.isHalted) {
      return (
        Icons.warning_amber_rounded,
        AppColors.amber,
        'Renewal failed. Re-subscribe to restore access.',
      );
    }
    if (info.isCancelPending && info.endedAt != null) {
      return (
        Icons.schedule_rounded,
        AppColors.amber,
        'Cancels on ${fmt.format(info.endedAt!)} — access continues until then.',
      );
    }
    if (info.isCancelled) {
      return (
        Icons.event_busy_rounded,
        AppColors.textDisabled,
        info.endedAt != null
            ? 'Ended ${fmt.format(info.endedAt!)}'
            : 'Subscription ended',
      );
    }
    if (info.isActive && info.nextBillingAt != null) {
      return (
        Icons.autorenew_rounded,
        accent,
        'Renews automatically on ${fmt.format(info.nextBillingAt!)}',
      );
    }
    return (Icons.info_outline_rounded, AppColors.textMuted, '');
  }

  Widget _kvGrid(BillingInfo info, DateFormat fmt) {
    final rows = <List<_Kv>>[];

    final r1 = <_Kv>[];
    if (info.since != null) {
      r1.add(_Kv(label: 'Started', value: fmt.format(info.since!)));
    }
    if (info.lastPaymentFormatted != null) {
      r1.add(_Kv(
        label: 'Last paid',
        value: info.lastPaymentAt != null
            ? '${info.lastPaymentFormatted!} · ${fmt.format(info.lastPaymentAt!)}'
            : info.lastPaymentFormatted!,
      ));
    }
    if (r1.isNotEmpty) rows.add(r1);

    final r2 = <_Kv>[];
    if (info.subscriptionId != null) {
      r2.add(_Kv(
        label: 'Subscription ID',
        value: info.subscriptionId!,
        copyValue: info.subscriptionId,
        truncate: true,
      ));
    }
    if (info.customerId != null) {
      r2.add(_Kv(
        label: 'Customer ID',
        value: info.customerId!,
        copyValue: info.customerId,
        truncate: true,
      ));
    }
    if (r2.isNotEmpty) rows.add(r2);

    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (int i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int j = 0; j < rows[i].length; j++) ...[
                if (j > 0) const SizedBox(width: 14),
                Expanded(child: rows[i][j]),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _actionButtons(BillingInfo info, Color accent) {
    if (info.isCancelPending) {
      return _PrimaryAction(
        label: _resuming ? 'Resuming…' : 'Resume Subscription',
        icon: Icons.restart_alt_rounded,
        color: AppColors.accentTeal,
        isLoading: _resuming,
        onTap: _resuming ? null : _confirmResume,
      );
    }

    if (info.isHalted || info.isCancelled) {
      return _PrimaryAction(
        label: 'Re-subscribe to ${_tierName(info.tier)}',
        icon: Icons.refresh_rounded,
        color: AppColors.accentTeal,
        onTap: () => Navigator.pushReplacementNamed(
          context,
          AppRouter.subscription,
        ),
      );
    }

    if (info.isActive) {
      final isEnterprise = info.tier == 'enterprise';
      return Row(
        children: [
          Expanded(
            child: _SecondaryAction(
              label: isEnterprise ? 'Compare Plans' : 'Upgrade',
              icon: isEnterprise
                  ? Icons.compare_arrows_rounded
                  : Icons.workspace_premium_rounded,
              color: isEnterprise ? AppColors.textSecondary : accent,
              onTap: () => Navigator.pushReplacementNamed(
                context,
                AppRouter.subscription,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SecondaryAction(
              label: _cancelling ? 'Cancelling…' : 'Cancel',
              icon: Icons.cancel_outlined,
              color: AppColors.accentRed,
              isLoading: _cancelling,
              onTap: _cancelling ? null : _confirmCancel,
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  IconData _tierIcon(String tier) => switch (tier.toLowerCase()) {
        'enterprise' => Icons.workspace_premium_rounded,
        'pro' => Icons.bolt_rounded,
        'trial' => Icons.hourglass_top_rounded,
        _ => Icons.person_outline_rounded,
      };

  String _tierName(String tier) => switch (tier.toLowerCase()) {
        'pro' => 'Pro',
        'enterprise' => 'Enterprise',
        'trial' => 'Trial',
        _ => 'Free',
      };

  String _priceText(BillingInfo info) {
    if (info.lastPaymentFormatted != null) {
      return '${info.lastPaymentFormatted!} / month';
    }
    return _tierName(info.tier);
  }
}

class _Header extends StatelessWidget {
  final String tierName;
  final String priceText;
  final Color accent;
  final IconData tierIcon;
  final BillingInfo statusInfo;

  const _Header({
    required this.tierName,
    required this.priceText,
    required this.accent,
    required this.tierIcon,
    required this.statusInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: AppShapes.sm,
            border: Border.all(color: accent.withValues(alpha: 0.28)),
          ),
          child: Icon(tierIcon, size: 17, color: accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tierName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                priceText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _StatusPill(info: statusInfo),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final BillingInfo info;
  const _StatusPill({required this.info});

  @override
  Widget build(BuildContext context) {
    final (color, label) = _statusFor(info);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: AppShapes.sm,
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  (Color, String) _statusFor(BillingInfo info) {
    return switch (info.status) {
      'active' => (AppColors.accentTeal, 'ACTIVE'),
      'halted' => (AppColors.amber, 'HALTED'),
      'cancelled' when info.isCancelPending => (AppColors.amber, 'CANCELLING'),
      'cancelled' => (AppColors.accentRed, 'CANCELLED'),
      'completed' => (AppColors.textDisabled, 'ENDED'),
      _ => (AppColors.textDisabled, 'INACTIVE'),
    };
  }
}

class _Kv extends StatelessWidget {
  final String label;
  final String value;
  final String? copyValue;
  final bool truncate;

  const _Kv({
    required this.label,
    required this.value,
    this.copyValue,
    this.truncate = false,
  });

  String _displayValue() {
    if (!truncate) return value;
    if (value.length <= 18) return value;
    return '${value.substring(0, 12)}…${value.substring(value.length - 4)}';
  }

  void _copy(BuildContext context) {
    if (copyValue == null) return;
    Clipboard.setData(ClipboardData(text: copyValue!));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied $copyValue'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textDisabled,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Flexible(
              child: Text(
                _displayValue(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (copyValue != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _copy(context),
                behavior: HitTestBehavior.opaque,
                child: Icon(
                  Icons.copy_rounded,
                  size: 11,
                  color: AppColors.textDisabled,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool isLoading;

  const _PrimaryAction({
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
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
                child: CircularProgressIndicator(strokeWidth: 1.5, color: color),
              )
            : Icon(icon, size: 14, color: color),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(vertical: 11),
          shape: RoundedRectangleBorder(borderRadius: AppShapes.sm),
        ),
      ),
    );
  }
}

class _SecondaryAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool isLoading;

  const _SecondaryAction({
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: isLoading
          ? SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: color),
            )
          : Icon(icon, size: 13, color: color),
      label: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.30)),
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: AppShapes.sm),
      ),
    );
  }
}
