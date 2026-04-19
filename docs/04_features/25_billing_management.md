# 25 — Billing & Subscription Management

## Overview

The Billing screen (`/billing`) is a dedicated dashboard page for managing an active Razorpay subscription. It is separate from the Subscription screen (`/subscription`) which handles plan selection and initial checkout.

| Screen | Route | Purpose |
|---|---|---|
| Subscription | `/subscription` | Plan selection, trial activation, new subscriptions |
| **Billing** | `/billing` | Manage existing subscription — status, cancel, payment history |

---

## Billing Screen — UI

### Active Subscriber

```
┌─ Status Card ──────────────────────────────────────────────┐
│  [PRO]  ● Active                       Renews in 14 days   │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ (progress bar) ━━━━━  │
│  📅 Member since       17 Apr 2026                          │
│  🔄 Next billing       17 May 2026  ·  ₹799                 │
│  💳 Last payment       17 Apr 2026  ·  ₹799  ·  pay_XXXXX  │
│  🏷  Subscription ID    sub_XXXXX  [copy]                    │
│  💰 Payment via        Razorpay                             │
└─────────────────────────────────────────────────────────────┘

┌─ Actions ───────────────────────────────────────────────────┐
│  [Upgrade to Enterprise →]                                  │
│  [Cancel Subscription]  ← confirmation dialog               │
└─────────────────────────────────────────────────────────────┘

PAYMENT HISTORY
17 Apr 2026   ₹799   First payment   pay_XXXXX  [copy]
```

### Pending Cancel (cancelled, access ongoing)

```
┌─ Status Card ──────────────────────────────────────────────┐
│  [PRO]  ● Cancels 17 May             Access ends in 29 days │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ (progress bar) ━━━━━  │
│  📅 Member since       17 Apr 2026                          │
│  ⏰ Access until        17 May 2026                         │
│  💳 Last payment       17 Apr 2026  ·  ₹799  ·  pay_XXXXX  │
│  🏷  Subscription ID    sub_XXXXX  [copy]                    │
└─────────────────────────────────────────────────────────────┘

┌─ Cancellation Scheduled ────────────────────────────────────┐
│  ⏱  Your Pro access continues until 17 May 2026.           │
│     After that your account moves to the Free plan.         │
└─────────────────────────────────────────────────────────────┘

PAYMENT HISTORY
...
```

### Payment Halted

```
┌─ Status Card ──────────────────────────────────────────────┐
│  [PRO]  ● Payment Failed                                    │
│  Access ended  17 Apr 2026                                  │
└─────────────────────────────────────────────────────────────┘

┌─ Payment Failed ────────────────────────────────────────────┐
│  ⚠  Razorpay attempted renewal but all retries failed.      │
│  [Re-subscribe to Pro]                                      │
└─────────────────────────────────────────────────────────────┘
```

### Cancelled / Completed (access ended)

```
┌─ Status Card ──────────────────────────────────────────────┐
│  [PRO]  ● Cancelled    Subscription ended  17 May 2026      │
└─────────────────────────────────────────────────────────────┘

  Your Pro subscription ended on 17 May 2026.
  [Re-subscribe to Pro]   [View All Plans →]
```

### Free / Trial User

Simple upsell card with a "View Plans" button pointing to `/subscription`.

---

## State Machine

```
subscriptionStatus  +  tier         →  Card shown
──────────────────────────────────────────────────────────────
active              +  pro/enterprise  →  _StatusCard + _ActionsCard
halted              +  free            →  _StatusCard + _HaltedCard
cancelled           +  pro/enterprise  →  _StatusCard + _PendingCancelCard  ← access ongoing
cancelled           +  free            →  _StatusCard + _CancelledCard      ← access ended
completed           +  free            →  _StatusCard + _CancelledCard
none                +  free/trial      →  _UpsellCard
```

`BillingInfo` getters that drive this:

```dart
bool get isActive       => status == 'active';
bool get isHalted       => status == 'halted';
bool get isCancelPending => status == 'cancelled' && isPaidTier;
bool get isCancelled    => (status == 'cancelled' || status == 'completed') && !isPaidTier;
bool get isPaidTier     => tier == 'pro' || tier == 'enterprise';
bool get hasSubscription => status != 'none';
```

---

## Cancel Subscription Flow

```
User taps "Cancel Subscription"
 └─ Confirmation dialog shown
     └─ Confirmed → datasource.cancelSubscription()
         └─ Gets Firebase ID token
         └─ POST cancelSubscription Cloud Function
             └─ Verifies token, checks subscription belongs to caller
             └─ POST api.razorpay.com/v1/subscriptions/{id}/cancel
                  { cancel_at_cycle_end: 1 }   ← user keeps access until period ends
             └─ Returns 200 { ok: true }
         └─ OPTIMISTIC UPDATE: billingInfoNotifier.value set to
              status:'cancelled', endedAt: nextBillingAt (best estimate)
         └─ Billing screen immediately shows _PendingCancelCard
         └─ SnackBar: "Cancellation scheduled. Access continues until 17 May 2026."

Razorpay fires subscription.cancelled (within seconds)
 └─ handleSubscriptionCancelled():
     - subscriptionStatus: 'cancelled'
     - subscriptionEndedAt: entity.current_end  ← real billing period end (Unix ts)
     - tier: UNCHANGED — user keeps paid access
     - razorpaySubscriptionId: kept (not deleted)
 └─ Firestore snapshot updates billingInfoNotifier with accurate endedAt

Razorpay fires subscription.completed (at period end)
 └─ handleSubscriptionTerminated('completed'):
     - tier: 'free'
     - subscriptionStatus: 'completed'
     - subscriptionEndedAt: now
     - razorpaySubscriptionId: deleted
 └─ BillingInfo.isCancelled → true, _CancelledCard shown
```

> `cancel_at_cycle_end: 1` is mandatory. `0` revokes immediately — never use `0`.

---

## Resume Subscription Flow

Applies when `isCancelPending == true` (status `cancelled`, tier still paid). Reactivates the **same** Razorpay subscription — no new subscription created, no immediate charge, original billing schedule preserved.

```
User taps "Resume Subscription"
 └─ Confirmation dialog shown
     └─ Confirmed → datasource.resumeSubscription()
         └─ Reads function_urls.resume_subscription from system/monetization
         └─ Gets Firebase ID token
         └─ POST resumeSubscription Cloud Function
             └─ Verifies token, checks subscription belongs to caller
             └─ POST api.razorpay.com/v1/subscriptions/{id}/resume
                  { resume_at: "now" }   ← reactivates on original billing schedule
             └─ Writes subscriptionStatus:'active', deletes subscriptionEndedAt (Firestore)
             └─ Returns 200 { ok: true }
         └─ OPTIMISTIC UPDATE: billingInfoNotifier.value set to
              status:'active', endedAt: null
         └─ Billing screen immediately reverts to _StatusCard + _ActionsCard
         └─ SnackBar: "Subscription reactivated."

Firestore snapshot arrives (from Cloud Function direct write)
 └─ billingInfoNotifier updated — status:'active', endedAt removed
 └─ Billing screen fully reflects active state

Razorpay fires subscription.activated or subscription.charged on next billing cycle
 └─ Normal charge flow (no special handling needed)
```

> The `resume_at: "now"` parameter is required. Omitting it defaults to end-of-cycle, which does not reactivate immediately.

---

## Data Sources

All fields read from `users/{uid}` in Firestore. Written by `razorpayWebhook` Cloud Function.

| Firestore Field | `BillingInfo` field | Shown as | Written by |
|---|---|---|---|
| `tier` | `tier` | Plan badge | webhook / admin |
| `subscriptionStatus` | `status` | Status pill | webhook |
| `subscriptionSince` | `since` | Member since | webhook — first activation |
| `monthlyResetAt` | `nextBillingAt` | Next billing / Access until | webhook — activated + charged |
| `lastPaymentAt` | `lastPaymentAt` | Last payment date | webhook — activated + charged + captured |
| `lastPaymentAmountPaise` | `lastPaymentPaise` | Last payment amount (÷ 100 = ₹) | webhook — activated + charged + captured |
| `lastPaymentId` | `lastPaymentId` | Last payment ID (`pay_XXXXX`) | webhook — activated + charged + captured |
| `razorpaySubscriptionId` | `subscriptionId` | Subscription ID (`sub_XXXXX`) | webhook — activated |
| `subscriptionEndedAt` | `endedAt` | Access until / Access ended | webhook — cancelled (`current_end`) · halted/completed (`now`) |

Payment history is read from the `subscription_events` subcollection into `invoicesNotifier`.

---

## BillingInfo Entity

**File**: `lib/features/subscription/domain/entities/billing_info.dart`

```dart
class BillingInfo {
  final String tier;            // free | trial | pro | enterprise
  final String status;          // active | halted | cancelled | completed | none
  final String? subscriptionId; // razorpaySubscriptionId (sub_XXXXX)
  final DateTime? since;        // subscriptionSince
  final DateTime? nextBillingAt;// monthlyResetAt
  final DateTime? lastPaymentAt;
  final int? lastPaymentPaise;  // ÷ 100 for ₹ display
  final String? lastPaymentId;  // pay_XXXXX
  final DateTime? endedAt;      // subscriptionEndedAt
}
```

`status == 'none'` — free/trial user, no subscription history.

---

## PaymentEvent Entity

**File**: `lib/features/subscription/domain/entities/payment_event.dart`

Maps one `subscription_events` subcollection document. Used for payment history list.

```dart
class PaymentEvent {
  final String event;        // subscription_activated | subscription_renewed | ...
  final String? paymentId;   // pay_XXXXX
  final int? amountPaise;
  final DateTime timestamp;
  final String? subscriptionId;

  bool get isCharge => amountPaise != null && amountPaise! > 0 && paymentId != null;
  String? get amountFormatted => '₹${amountPaise! / 100}';
  String get label => ... // human readable label per event type
}
```

---

## Cloud Functions

### `cancelSubscription`

**File**: `functions/src/cancelSubscription.ts`  
**URL**: `https://cancelsubscription-f3n57yyena-uc.a.run.app`

- **Auth**: Firebase ID token (`Authorization: Bearer <token>`)
- **Request**: `{ subscriptionId: "sub_XXXXX" }`
- **Response**: `{ ok: true }` or `{ error: "..." }`
- **Razorpay call**: `POST /v1/subscriptions/{id}/cancel` with `{ cancel_at_cycle_end: 1 }`
- **Security**: cross-checks `subscriptionId` belongs to calling `uid` via Firestore query

### `createSubscription`

**File**: `functions/src/createSubscription.ts`  
**URL**: `https://createsubscription-f3n57yyena-uc.a.run.app`

- Reads `plan_ids[tierId]` from `system/monetization`
- Calls `POST /v1/subscriptions` with `notes: { uid, tier }`
- Returns `{ url: short_url }` — Flutter opens this in the browser

### `resumeSubscription`

**File**: `functions/src/resumeSubscription.ts`  
**URL**: `https://resumesubscription-f3n57yyena-uc.a.run.app`

- **Auth**: Firebase ID token (`Authorization: Bearer <token>`)
- **Request**: `{ subscriptionId: "sub_XXXXX" }`
- **Response**: `{ ok: true }` or `{ error: "..." }`
- **Razorpay call**: `POST /v1/subscriptions/{id}/resume` with `{ resume_at: "now" }`
- **Security**: cross-checks `subscriptionId` belongs to calling `uid` via Firestore query
- **Firestore write**: sets `subscriptionStatus:'active'`, deletes `subscriptionEndedAt` — Flutter UI updates immediately without waiting for a webhook

### `razorpayWebhook`

**File**: `functions/src/razorpayWebhook.ts`  
**URL**: `https://razorpaywebhook-f3n57yyena-uc.a.run.app`

Handles 7 events. Key behaviour per event:

| Event | Firestore root doc | `subscription_events` doc |
|---|---|---|
| `payment.captured` | `tier`, `lastPaymentId`, `lastPaymentAt`, `lastPaymentAmountPaise` | `upgraded`, `paymentId`, `amountPaise` |
| `subscription.activated` | `tier`, `razorpaySubscriptionId`, `razorpayPlanId`, `subscriptionStatus:'active'`, `lastPaymentId`, `lastPaymentAt`, `lastPaymentAmountPaise` | `subscription_activated`, `paymentId`, `amountPaise` |
| `subscription.charged` | `monthlyResetAt`, `subscriptionStatus:'active'`, `lastPaymentId`, `lastPaymentAt`, `lastPaymentAmountPaise` | `subscription_renewed`, `paymentId`, `amountPaise` |
| `subscription.cancelled` | `subscriptionStatus:'cancelled'`, `subscriptionEndedAt: current_end` (tier **unchanged**) | `subscription_cancelled`, `accessEndsAt` |
| `subscription.halted` | `tier:'free'`, `subscriptionStatus:'halted'`, `subscriptionEndedAt: now`, deletes `razorpaySubscriptionId` | `subscription_halted` |
| `subscription.completed` | `tier:'free'`, `subscriptionStatus:'completed'`, `subscriptionEndedAt: now`, deletes `razorpaySubscriptionId` | `subscription_completed` |

---

## Notifiers on `SubscriptionRemoteDataSource`

| Notifier | Type | Updated when |
|---|---|---|
| `billingInfoNotifier` | `ValueNotifier<BillingInfo>` | Every Firestore `users/{uid}` snapshot + optimistic cancel + optimistic resume |
| `invoicesNotifier` | `ValueNotifier<List<PaymentEvent>>` | Once per login — reads `subscription_events` (24 entries, newest first) |

---

## Navigation

- **Route**: `/billing`
- **Nav rail**: Billing tile between Subscription and Usage Analytics — icon `Icons.receipt_long_rounded`
- **Window mode**: dashboard
- **Back button**: shown in `OmniHeader` via `onBack: () => Navigator.pop(context)`

---

## Key Files

| File | Role |
|---|---|
| `lib/features/subscription/domain/entities/billing_info.dart` | Billing state snapshot entity |
| `lib/features/subscription/domain/entities/payment_event.dart` | Single payment history entry entity |
| `lib/features/subscription/data/datasources/subscription_remote_datasource.dart` | `_listenToUserDoc` reads all billing fields · `_loadInvoices` reads subcollection · `cancelSubscription()` + `resumeSubscription()` with optimistic updates |
| `lib/features/subscription/presentation/screens/billing_screen.dart` | Full billing UI — status card, countdown, progress bar, actions, pending-cancel banner, resume button, invoice history |
| `lib/core/navigation/app_router.dart` | `/billing` route registration |
| `lib/features/shell/presentation/widgets/app_navigation_rail.dart` | Billing nav tile |
| `functions/src/cancelSubscription.ts` | Cloud Function — Razorpay cancel API |
| `functions/src/resumeSubscription.ts` | Cloud Function — Razorpay resume API (reactivates same subscription) |
| `functions/src/createSubscription.ts` | Cloud Function — Razorpay subscription creation |
| `functions/src/razorpayWebhook.ts` | Cloud Function — all 7 Razorpay webhook events |

---

## Remaining Gaps / Future Work

### 1. Upgrade flow pre-selection (LOW)

"Upgrade to Enterprise" button pushes to `/subscription` without pre-selecting Enterprise. Pass an `initialTier` argument to `SubscriptionScreen` if needed.

### 2. Downgrade (Enterprise → Pro) — no path (LOW)

Razorpay does not support mid-cycle plan changes. Approach for v1: cancel + re-subscribe. No UI surface yet.

### 3. Invoice PDF download (LOW)

Razorpay provides `invoice_url` via `GET /v1/invoices?subscription_id=...`. Not stored. Would require a Cloud Function proxy to avoid exposing API keys to the client.
