import 'package:equatable/equatable.dart';

/// A single entry from `users/{uid}/subscription_events`.
/// Used to build the payment history list on the Billing screen.
class PaymentEvent extends Equatable {
  /// Webhook event type, e.g. `subscription_activated`, `subscription_renewed`,
  /// `subscription_cancelled`, `subscription_completed`, `upgraded`.
  final String event;

  /// Razorpay payment ID (`pay_XXXXX`). Present on charge events; null otherwise.
  final String? paymentId;

  /// Payment amount in paise. Divide by 100 for ₹.
  final int? amountPaise;

  /// Server timestamp of the event.
  final DateTime timestamp;

  /// Razorpay subscription ID (`sub_XXXXX`).
  final String? subscriptionId;

  /// Payment method type — `'upi' | 'card' | 'netbanking' | 'wallet'` — written
  /// by `razorpayWebhook` from `payment.entity.method`. Null for non-charge
  /// events and for legacy events written before the field was added.
  final String? method;

  /// Human-friendly summary of the method, e.g. `'UPI · maya@okhdfcbank'` or
  /// `'Card · HDFC •• 4421'`. Derived server-side from `payment.entity` —
  /// nullable because Razorpay doesn't always include the underlying detail.
  final String? methodSummary;

  /// Razorpay-hosted invoice PDF URL. Opened externally via `url_launcher`;
  /// the app never generates its own invoices.
  final String? invoiceUrl;

  const PaymentEvent({
    required this.event,
    required this.timestamp,
    this.paymentId,
    this.amountPaise,
    this.subscriptionId,
    this.method,
    this.methodSummary,
    this.invoiceUrl,
  });

  bool get isCharge =>
      amountPaise != null && amountPaise! > 0 && paymentId != null;

  String? get amountFormatted {
    if (amountPaise == null) return null;
    return '₹${(amountPaise! / 100).toStringAsFixed(0)}';
  }

  String get label => switch (event) {
        'subscription_activated' => 'First payment',
        'subscription_renewed' => 'Renewal',
        'upgraded' => 'Upgraded',
        'subscription_cancelled' => 'Cancellation scheduled',
        'subscription_completed' => 'Subscription ended',
        'downgraded' => 'Downgraded',
        _ => event,
      };

  @override
  List<Object?> get props => [event, paymentId, amountPaise, timestamp, subscriptionId];
}
