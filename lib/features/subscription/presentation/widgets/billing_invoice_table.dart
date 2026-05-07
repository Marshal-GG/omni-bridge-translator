import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:omni_bridge/core/theme/app_theme.dart';
import 'package:omni_bridge/core/utils/app_logger.dart';
import 'package:omni_bridge/core/widgets/omni_badge.dart';
import 'package:omni_bridge/features/subscription/domain/entities/payment_event.dart';

/// Grid-style invoice list. Replaces the older single-column list and adds the
/// method column + Razorpay-hosted PDF download. Status uses [OmniBadge] so it
/// stays consistent with the rest of the app.
class BillingInvoiceTable extends StatelessWidget {
  final List<PaymentEvent> events;

  const BillingInvoiceTable({required this.events, super.key});

  static const _idFlex = 24;
  static const _dateFlex = 18;
  static const _amountFlex = 14;
  static const _methodFlex = 22;
  static const _statusFlex = 14;
  static const _actionFlex = 8;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: AppShapes.md,
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          const _InvoiceHeader(),
          for (int i = 0; i < events.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                color: AppColors.cardBorder.withValues(alpha: 0.6),
              ),
            _InvoiceRow(event: events[i]),
          ],
        ],
      ),
    );
  }
}

class _InvoiceHeader extends StatelessWidget {
  const _InvoiceHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white(0.02),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppShapes.radiusMd),
          topRight: Radius.circular(AppShapes.radiusMd),
        ),
        border: Border(
          bottom: BorderSide(color: AppColors.cardBorder),
        ),
      ),
      child: const Row(
        children: [
          Expanded(
            flex: BillingInvoiceTable._idFlex,
            child: _HeaderLabel('PAYMENT'),
          ),
          Expanded(
            flex: BillingInvoiceTable._dateFlex,
            child: _HeaderLabel('DATE'),
          ),
          Expanded(
            flex: BillingInvoiceTable._amountFlex,
            child: _HeaderLabel('AMOUNT'),
          ),
          Expanded(
            flex: BillingInvoiceTable._methodFlex,
            child: _HeaderLabel('METHOD'),
          ),
          Expanded(
            flex: BillingInvoiceTable._statusFlex,
            child: _HeaderLabel('STATUS'),
          ),
          Expanded(
            flex: BillingInvoiceTable._actionFlex,
            child: SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _HeaderLabel extends StatelessWidget {
  final String label;
  const _HeaderLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.textDisabled,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  final PaymentEvent event;
  const _InvoiceRow({required this.event});

  Future<void> _download(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      AppLogger.w('Failed to open invoice URL: $e', tag: 'BillingInvoiceTable');
    }
  }

  void _copy(BuildContext context, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied $value'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy');
    final isCharge = event.isCharge;
    final id = event.paymentId ?? '—';
    final method = event.methodSummary ?? _fallbackMethod(event.method);
    final hasInvoice = (event.invoiceUrl ?? '').isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: BillingInvoiceTable._idFlex,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (event.paymentId != null) ...[
                  const SizedBox(height: 2),
                  GestureDetector(
                    onTap: () => _copy(context, id),
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                      _truncateId(id),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textDisabled,
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            flex: BillingInvoiceTable._dateFlex,
            child: Text(
              fmt.format(event.timestamp),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            flex: BillingInvoiceTable._amountFlex,
            child: Text(
              event.amountFormatted ?? '—',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: BillingInvoiceTable._methodFlex,
            child: Text(
              method ?? '—',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            flex: BillingInvoiceTable._statusFlex,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _statusBadge(event, isCharge),
            ),
          ),
          Expanded(
            flex: BillingInvoiceTable._actionFlex,
            child: Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: hasInvoice
                    ? 'Open invoice'
                    : 'Invoice not available',
                onPressed: hasInvoice
                    ? () => _download(context, event.invoiceUrl!)
                    : null,
                icon: Icon(
                  Icons.download_rounded,
                  size: 15,
                  color: hasInvoice
                      ? AppColors.accentTeal
                      : AppColors.textDisabled,
                ),
                constraints: const BoxConstraints(
                  minWidth: 28,
                  minHeight: 28,
                ),
                padding: EdgeInsets.zero,
                splashRadius: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(PaymentEvent event, bool isCharge) {
    if (event.event == 'subscription_cancelled') {
      return const OmniBadge(text: 'CANCELLED', color: AppColors.amber);
    }
    if (event.event == 'subscription_completed' ||
        event.event == 'subscription_halted') {
      return const OmniBadge(text: 'ENDED', color: AppColors.textMuted);
    }
    if (isCharge) {
      return const OmniBadge(text: 'PAID', color: AppColors.accentTeal);
    }
    return const OmniBadge(text: 'NOTE', color: AppColors.textDisabled);
  }

  String? _fallbackMethod(String? method) {
    if (method == null) return null;
    return switch (method) {
      'upi' => 'UPI',
      'card' => 'Card',
      'netbanking' => 'Net Banking',
      'wallet' => 'Wallet',
      _ => method,
    };
  }

  String _truncateId(String s) =>
      s.length > 22 ? '${s.substring(0, 14)}…${s.substring(s.length - 4)}' : s;
}
