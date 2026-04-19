import 'package:equatable/equatable.dart';

/// Snapshot of a user's Razorpay subscription billing state.
/// Read from Firestore `users/{uid}` fields written by the razorpayWebhook
/// Cloud Function.
class BillingInfo extends Equatable {
  /// Current tier (free / trial / pro / enterprise).
  final String tier;

  /// Razorpay subscription lifecycle status.
  /// - `active`    — subscription is live and renewing normally
  /// - `halted`    — renewal failed after all retries, access ended
  /// - `cancelled` — user cancelled, access ends at period end
  /// - `completed` — plan term ended naturally
  /// - `none`      — free/trial user with no subscription history
  final String status;

  /// Razorpay subscription ID (`sub_XXXXX`). Null for free/trial users.
  final String? subscriptionId;

  /// When the user first subscribed (set once on first activation).
  final DateTime? since;

  /// Next billing / quota reset date (`monthlyResetAt`).
  final DateTime? nextBillingAt;

  /// Timestamp of the most recent successful payment.
  final DateTime? lastPaymentAt;

  /// Amount of the most recent payment in paise (÷ 100 = ₹).
  final int? lastPaymentPaise;

  /// Razorpay payment ID of the most recent payment (`pay_XXXXX`).
  final String? lastPaymentId;

  /// When access ended for halted / cancelled / completed subscriptions.
  /// For pending-cancel, this is set to `current_end` by the webhook — the
  /// actual end of the billing period (not the cancel request time).
  final DateTime? endedAt;

  const BillingInfo({
    required this.tier,
    required this.status,
    this.subscriptionId,
    this.since,
    this.nextBillingAt,
    this.lastPaymentAt,
    this.lastPaymentPaise,
    this.lastPaymentId,
    this.endedAt,
  });

  bool get isActive => status == 'active';
  bool get isHalted => status == 'halted';

  /// True when cancelled but paid tier still active (access ongoing until [endedAt]).
  bool get isCancelPending => status == 'cancelled' && isPaidTier;

  /// True when subscription has fully ended (completed or cancelled + tier downgraded).
  bool get isCancelled =>
      (status == 'cancelled' || status == 'completed') && !isPaidTier;

  bool get hasSubscription => status != 'none';
  bool get isPaidTier => tier == 'pro' || tier == 'enterprise';

  /// Last payment formatted as ₹X (e.g. "₹799").
  String? get lastPaymentFormatted {
    if (lastPaymentPaise == null) return null;
    return '₹${(lastPaymentPaise! / 100).toStringAsFixed(0)}';
  }

  static const empty = BillingInfo(tier: 'free', status: 'none');

  @override
  List<Object?> get props => [
    tier,
    status,
    subscriptionId,
    since,
    nextBillingAt,
    lastPaymentAt,
    lastPaymentPaise,
    lastPaymentId,
    endedAt,
  ];
}
