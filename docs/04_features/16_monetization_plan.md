# 16 — Monetization Plan

## Overview

Omni Bridge uses a **tiered subscription model** (Free / Trial / Pro / Enterprise) to balance server costs with user accessibility. Subscriptions are purchased via Razorpay and reflected instantly in the app via Firestore real-time listeners. All usage is tracked by **token count** (input + output) in RTDB, providing an engine-agnostic metric that scales across local and cloud models.

---

## Subscription Tiers

All values below are the defaults seeded via the Admin Panel's **Seed System Config**. Every field is dynamically sourced from `system/monetization → tiers` in Firestore — changes take effect without an app update.

| Feature | **Free** | **Trial** | **Pro** | **Enterprise** |
| :--- | :--- | :--- | :--- | :--- |
| **Price** | ₹0 | ₹0 (one-time, 24h) | ₹799/mo | ₹2,499/mo |
| **Daily Quota** | 40,000 tokens | 75,000 tokens | 75,000 tokens | 250,000 tokens |
| **Monthly Quota** | 750,000 tokens | 75,000 tokens | 3,750,000 tokens | 9,000,000 tokens |
| **Transcription Models** | Google Online, Riva ASR | All | Google Online, Whisper tiny–base, Riva | All (Whisper tiny–medium) |
| **Translation Models** | Google Translate only | All | All | All |
| **Microphone Audio** | No | Yes | Yes | Yes |
| **History Access** | None | None | 7-day retention | 30-day retention |
| **Session Duration** | 1 hour | 24 hours | 4 hours | 12 hours |
| **Concurrent Sessions** | 1 | 1 | 2 | 5 |
| **Requests/min** | 20 | 60 | 60 | 120 |

> **Token-to-time estimate**: ~40,000 tokens ≈ 30 minutes of active translation usage.

### Per-Engine Monthly Limits

Paid tiers have per-engine monthly token caps. `google` (Translate) and `online` (ASR) are **exempt** from per-engine caps — they follow only the global daily/monthly quotas.

| Engine | Trial | Pro | Enterprise |
|---|---|---|---|
| `google_api` | no cap | 250,000 | 750,000 |
| `riva-nmt` | no cap | 250,000 | 750,000 |
| `llama` | no cap | 250,000 | 750,000 |
| `whisper-asr` | no cap | 375,000 | 1,125,000 |
| `google`, `online` (ASR) | no cap | no cap | no cap |

### Trial Tier

A **free, one-time 24-hour Trial** tier allows new users to test Pro-level features before committing:

- **Activation**: `SubscriptionService.activateTrial()` — sets `tier: 'trial'`, records `trial_used: true` and `trialExpiresAt` on the user doc.
- **Price**: Free (₹0).
- **Duration**: 24 hours. Configurable via `tiers.trial.trial_duration_hours`.
- **One-time only**: `hasUsedTrial()` checks the `trial_used` flag — once used, it cannot be re-activated.
- **Auto-expiry**: `_checkTrialExpiry()` runs on every user doc snapshot while `tier == 'trial'`. When `trialExpiresAt` is passed, the user is automatically downgraded to the free tier.

---

## Usage Tracking

Usage is tracked by **token count** (Input + Output tokens), pushed live to RTDB.

| Counter | Resets | Field |
|---|---|---|
| Daily | Midnight (local) | `users/{uid}/daily_usage/{YYYY-MM-DD}/tokens` (RTDB) |
| Weekly | Monday (local) | `users/{uid}/usage/totals/weekly` (RTDB) |
| Monthly (Calendar) | 1st of month | `users/{uid}/usage/totals/calendar_monthly` (RTDB) |
| Monthly (Subscription) | Billing-cycle (30 days) | `users/{uid}/usage/totals/subscription_monthly` (RTDB) |
| Lifetime | Never | `users/{uid}/usage/totals/lifetime` (RTDB) |

All counters use **atomic increments** — concurrent writes are safe.

### Quota Exceeded Behaviour

#### Global (Daily / Monthly) Quota Exceeded

1. `lastQuotaExceededAt` is written to Firestore.
2. Translation is paused — `TranslationBloc` checks `SubscriptionStatus.isExceeded`.
3. The UI displays the contextual `UpgradeSheet` for free-tier users.

#### Per-Engine Monthly Limit Exceeded (Hybrid Approach)

1. **First occurrence in the session**: Dialog with "Switch to Google Translate" or "Upgrade Plan".
2. **Subsequent calls**: Silent fallback to `google`. Persistent indicator shown in the translation header.
3. **Session tracking**: `Set<String> _notifiedEngines` tracks which engines have already shown the dialog. Resets on app restart.

---

## Payment Integration

- **Primary provider:** Razorpay (optimised for UPI and the Indian market).
- **Subscription creation:** Programmatic via the `createSubscription` Cloud Function — no static payment links are used.

---

## Cloud Functions

Two Firebase Cloud Functions handle all Razorpay payment operations. Both are deployed to `us-central1` as **Gen 2** (Cloud Run) functions.

| Function | URL | Purpose |
|---|---|---|
| `createSubscription` | `https://createsubscription-f3n57yyena-uc.a.run.app` | Creates a Razorpay subscription for the calling user |
| `cancelSubscription` | `https://cancelsubscription-f3n57yyena-uc.a.run.app` | Cancels the caller's subscription at end of billing period |
| `razorpayWebhook` | `https://razorpaywebhook-f3n57yyena-uc.a.run.app` | Receives Razorpay webhook events and updates Firestore |

### `createSubscription`

**File**: `functions/src/createSubscription.ts`

An authenticated HTTP endpoint. Called by the Flutter app when a user selects a paid plan.

**Auth**: Requires a Firebase ID token in the `Authorization: Bearer <token>` header. The token is verified with `admin.auth().verifyIdToken()` — unauthenticated calls return `401`.

**Request**:
```json
POST /createSubscription
Authorization: Bearer <firebase_id_token>
Content-Type: application/json

{ "tierId": "pro" }
```

**Response**:
```json
{ "url": "https://rzp.io/rzp/..." }
```

**Logic**:
1. Verifies Firebase ID token → extracts `uid` and `email`.
2. Reads `system/monetization → plan_ids[tierId]` to get the Razorpay plan ID.
3. Calls `POST https://api.razorpay.com/v1/subscriptions` with:
   - `plan_id`: the resolved Razorpay plan ID
   - `total_count: 120` (10-year cap, effectively unlimited)
   - `notes: { uid, tier: tierId }` — baked into the subscription object, available on every webhook event
4. Returns the Razorpay `short_url` to the Flutter app.

**Secrets used**:
- `RAZORPAY_KEY_ID` — Razorpay API key ID
- `RAZORPAY_KEY_SECRET` — Razorpay API key secret

### `cancelSubscription`

**File**: `functions/src/cancelSubscription.ts`

Cancels the calling user's Razorpay subscription at the end of the current billing period (`cancel_at_cycle_end: 1`). The user keeps access until `monthlyResetAt`.

**Auth**: Firebase ID token (`Authorization: Bearer <token>`)

**Request**: `{ subscriptionId: "sub_XXXXX" }`

**Response**: `{ ok: true }` or `{ error: "..." }`

**Security**: Cross-checks that the `subscriptionId` belongs to the calling `uid` by querying Firestore before calling Razorpay — prevents users from cancelling other accounts' subscriptions.

**Secrets used**: `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`

The resulting `subscription.cancelled` webhook event is handled by `razorpayWebhook` which downgrades the tier automatically.

---

### `razorpayWebhook`

**File**: `functions/src/razorpayWebhook.ts`

A public HTTP endpoint registered in Razorpay Dashboard → Settings → Webhooks.

**Signature verification**: Every request is verified using HMAC-SHA256 against `RAZORPAY_WEBHOOK_SECRET` before any processing. Invalid signatures return `400`.

**Events handled**:

| Event | Handler | Action |
|---|---|---|
| `payment.captured` | `handlePaymentCaptured` | One-time payment: upgrades tier, resets monthly quota |
| `payment.failed` | `handlePaymentFailed` | Logs only — Flutter handles pending timeout itself |
| `subscription.activated` | `handleSubscriptionActivated` | First charge: sets tier, stores `razorpaySubscriptionId` |
| `subscription.charged` | `handleSubscriptionCharged` | Monthly renewal: resets `monthlyTokensUsed`, extends `monthlyResetAt` |
| `subscription.halted` | `handleSubscriptionTerminated` | Renewal failed: downgrades to free |
| `subscription.cancelled` | `handleSubscriptionTerminated` | User cancelled: downgrades to free |
| `subscription.completed` | `handleSubscriptionTerminated` | Plan ended: downgrades to free |

**UID Resolution** (`resolveUid`): Three strategies tried in order:
1. `notes.uid` — set by `createSubscription` (primary, always present for new subscriptions)
2. `razorpaySubscriptionId` query — covers renewal events after activation
3. Email lookup — fallback for edge cases

**Secrets used**:
- `RAZORPAY_WEBHOOK_SECRET` — HMAC signing secret set in Razorpay Dashboard

---

## End-to-End Payment Flow

```
User taps "Select Plan" (Pro or Enterprise)
 └─ PlanCard._handleCta()
     └─ SubscriptionRemoteDataSource.openCheckout("pro")
         └─ gets Firebase ID token (user.getIdToken())
         └─ POST createSubscription { tierId: "pro" }
             └─ function verifies ID token → uid extracted
             └─ reads plan_ids["pro"] from system/monetization
             └─ POST api.razorpay.com/v1/subscriptions
                 └─ notes: { uid, tier: "pro" } baked in
             └─ returns { url: "https://rzp.io/rzp/..." }
         └─ opens unique URL in system browser
         └─ _paymentPending = true (spinner shown, button disabled)
         └─ 10-minute hard timeout set

User pays in browser → Razorpay calls razorpayWebhook
 └─ HMAC-SHA256 signature verified
 └─ subscription.activated event
     └─ resolveUid: reads notes.uid (always present)
     └─ tier = notes.tier = "pro"
     └─ writes users/{uid}.tier = "pro" to Firestore
     └─ writes razorpaySubscriptionId, subscriptionStatus = "active"
     └─ resets monthlyTokensUsed = 0, monthlyResetAt = now + 30 days

SubscriptionRemoteDataSource._listenToUserDoc() fires (real-time)
 └─ _updateCurrentStatus(tier: "pro")
 └─ statusStream emits new QuotaStatus
 └─ SubscriptionBloc rebuilds → isCurrent: true passed to PlanCard
     └─ PlanCard.didUpdateWidget() detects isCurrent flip
         └─ _paymentPending = false, grace timer cancelled
         └─ button becomes "Current Plan"
```

### Monthly Renewal Flow

```
Razorpay charges user on billing date
 └─ subscription.charged webhook
     └─ resolveUid: notes.uid OR razorpaySubscriptionId query
     └─ resets monthlyTokensUsed = 0
     └─ extends monthlyResetAt = now + 30 days
     └─ writes lastPaymentId, lastPaymentAmountPaise
     └─ app detects monthlyResetAt change → UI refreshes
```

### Cancellation / Failure Flow

```
subscription.halted / subscription.cancelled / subscription.completed
 └─ resolveUid → uid
 └─ tier = "free"
 └─ clears razorpaySubscriptionId
 └─ subscriptionStatus = "halted" / "cancelled" / "completed"
 └─ app detects tier change → UI updates to free tier
```

---

## Payment Pending State & Failure Detection

**File**: `lib/features/subscription/presentation/widgets/plan_card.dart`

`_PlanCardState` implements `WidgetsBindingObserver` to detect when the user returns from the browser.

| State | UI |
|---|---|
| `_paymentPending = true` | Button shows "Awaiting Payment..." + spinner, disabled |
| `isCurrent` flips true | `didUpdateWidget` clears pending immediately — success |
| App resumes, tier unchanged | 30-second grace timer starts |
| Grace timer fires, still no tier change | Orange SnackBar: "Payment not confirmed..." — pending resets |
| No action for 10 minutes | Hard timeout resets pending state |

| Scenario | Outcome |
|---|---|
| Payment succeeds | Webhook fires → tier updates → "Current Plan" within ~2s |
| User cancels in browser | 30s grace → no tier change → SnackBar → button resets |
| Payment fails in browser | Same as cancellation |
| Webhook delayed but valid (within 30s) | `isCurrent` flips before timer fires → success |
| Webhook never fires | 10-minute hard timeout resets pending state |

---

## Firestore Fields

### Written by `createSubscription` + webhook events

| Field | Set on | Notes |
|---|---|---|
| `tier` | `activated`, `halted`, `cancelled`, `completed` | Source of truth |
| `razorpaySubscriptionId` | `activated` | Cleared on termination |
| `razorpayPlanId` | `activated` | For reference only |
| `subscriptionStatus` | All events | `active`, `halted`, `cancelled`, `completed` |
| `monthlyTokensUsed` | `activated`, `charged` | Reset to 0 on each renewal |
| `monthlyResetAt` | `activated`, `charged` | Extended 30 days |
| `subscriptionSince` | `activated` (first time only) | Never overwritten |
| `subscriptionEndedAt` | `halted`, `cancelled`, `completed` | When access ended |
| `lastPaymentId` | `captured`, `charged` | Razorpay payment ID |
| `lastPaymentAmountPaise` | `charged` | Amount in paise |
| `lastPaymentAt` | `captured`, `charged` | Server timestamp |

### Subscription Event Audit Trail

Every tier change is written to `users/{uid}/subscription_events/{push-id}`:

```json
{
  "event": "subscription_activated",
  "to": "pro",
  "via": "razorpay_subscription",
  "subscriptionId": "sub_XXXXX",
  "timestamp": "..."
}
```

---

## Firestore Configuration (`system/monetization`)

All payment-related config lives in a single Firestore document. Seeded via **Admin Panel → Seed System Config**.

### `plan_ids` map

Maps tier IDs to Razorpay plan IDs. Read by `createSubscription` to resolve which plan to subscribe the user to.

```json
{
  "plan_ids": {
    "pro": "plan_SeBEou7uXFDDRT",
    "enterprise": "plan_SeBFJKoDwsl158"
  }
}
```

> Update these values when switching from test to production plans (see [Going Live](#going-live)).

### `function_urls` map

Cloud Function endpoints read by the Flutter app.

```json
{
  "function_urls": {
    "create_subscription": "https://createsubscription-f3n57yyena-uc.a.run.app",
    "cancel_subscription": "https://cancelsubscription-f3n57yyena-uc.a.run.app",
    "resume_subscription": "https://resumesubscription-f3n57yyena-uc.a.run.app"
  }
}
```

---

## Subscription Event Audit Trail

Every tier change (upgrade or downgrade) is written to `users/{uid}/subscription_events/{push-id}` in Firestore. On the **first paid upgrade**, additional fields are set once on the root user doc and never overwritten:

| Field | Value |
|---|---|
| `subscriptionSince` | Server timestamp of first conversion |
| `paymentProvider` | `"razorpay"` |
| `monthlyResetAt` | Anchored to `now + 30 days` (billing cycle start) |

---

## Feature Gating

Feature gating is enforced via `SubscriptionService.canUseModel(modelId)`:
1. **Tier Access**: Is the model in `tiers.{userTier}.allowed_translation_models` or `allowed_transcription_models`?
2. **Kill Switch**: Is `model_overrides.{modelId}.enabled` set to `true`?

Both must pass. Config is fetched dynamically from `system/monetization`.

### AI Translation Engines

| Engine | Model ID | Free | Trial | Pro | Enterprise |
|---|---|---|---|---|---|
| Llama 3.1 8B ⭐ | `llama` | - | Yes | Yes (250K/mo) | Yes (750K/mo) |
| Google Translate | `google` | Yes | Yes | Yes | Yes |
| MyMemory | `mymemory` | - | Yes | Yes | Yes |
| Google Cloud (gRPC) | `google_api` | - | Yes | Yes (250K/mo) | Yes (750K/mo) |
| NVIDIA Riva NMT | `riva-nmt` | - | Yes | Yes (250K/mo) | Yes (750K/mo) |

### Transcription Models

| Model | Model ID | Free | Trial | Pro | Enterprise |
|---|---|---|---|---|---|
| Google Online | `online` | Yes | Yes | Yes | Yes |
| Whisper Tiny | `whisper-tiny` | - | Yes | Yes | Yes |
| Whisper Base | `whisper-base` | - | Yes | Yes | Yes |
| Whisper Small | `whisper-small` | - | - | - | Yes |
| Whisper Medium | `whisper-medium` | - | Yes | - | Yes |
| NVIDIA Riva ASR | `riva-asr` | Yes | Yes | Yes | Yes |

---

## Technical Implementation

### Enforcement

- **Client-Side Polling**: `SubscriptionService` polls RTDB at `usage_poll_interval_seconds` (default 30s).
- **Gatekeeping**: `TranslationBloc` checks `SubscriptionStatus.isExceeded` before starting sessions.
- **Backend Rules**: Firestore security rules block unauthorized writes to `tier` and other sensitive fields.

### Token Counting

The Python server sends token counts for both **Input** (ASR) and **Output** (Translator) in translation metadata. The Flutter client passes these to `UsageMetricsRemoteDataSource.logModelUsage()`.

---

## Going Live (Test → Production)

When you're ready to accept real payments, follow these steps in order. **Do not skip the webhook secret rotation** or real payments will be rejected.

### Step 1 — Create Live Razorpay Plans

1. In Razorpay Dashboard, switch the toggle from **Test Mode** to **Live Mode** (top-left).
2. Go to **Subscriptions → Plans → Create Plan**.
3. Create the same two plans as in test:
   - **Pro Monthly**: ₹799 / month
   - **Enterprise Monthly**: ₹2,499 / month
4. Note down the new **Live plan IDs** (format: `plan_XXXXXXXXXX`).

### Step 2 — Rotate Firebase Secrets

Run each command and paste the **Live** values when prompted:

```bash
# Live Razorpay API Key ID (starts with rzp_live_)
firebase functions:secrets:set RAZORPAY_KEY_ID

# Live Razorpay API Key Secret
firebase functions:secrets:set RAZORPAY_KEY_SECRET

# Live Webhook Signing Secret (generate a new strong secret, e.g. openssl rand -hex 32)
firebase functions:secrets:set RAZORPAY_WEBHOOK_SECRET
```

Get the Live API keys from: Razorpay Dashboard (Live Mode) → Settings → API Keys → Generate Key.

> **Never reuse the test keys in production.** Test and live keys are completely separate credentials.

### Step 3 — Update Razorpay Webhook Secret

In Razorpay Dashboard (Live Mode) → Settings → Webhooks:
- Find your existing webhook (same URL as test: `https://razorpaywebhook-f3n57yyena-uc.a.run.app`)
- Update the **Secret** field to match the new value you set for `RAZORPAY_WEBHOOK_SECRET` in Step 2.
- Ensure all 7 events are still enabled: `payment.captured`, `payment.failed`, `subscription.activated`, `subscription.charged`, `subscription.halted`, `subscription.cancelled`, `subscription.completed`.

### Step 4 — Redeploy Functions

The secrets are loaded at cold-start. Redeploy to pick up the new secret values:

```bash
firebase deploy --only functions
```

### Step 5 — Update Firestore Config

Update `system/monetization` with the Live plan IDs via **Admin Panel → Seed System Config** after updating [admin_panel.dart](../../lib/features/auth/presentation/screens/account/components/admin_panel.dart):

```dart
'plan_ids': {
  'pro': 'plan_LIVE_PRO_ID_HERE',       // from Step 1
  'enterprise': 'plan_LIVE_ENT_ID_HERE', // from Step 1
},
```

Then open the app and tap **Seed System Config** in the Admin Panel.

### Step 6 — Verify

Make a real ₹1 test payment (Razorpay supports ₹1 test in live mode via UPI) and confirm:
1. Firebase Function logs show `subscription.activated` with the correct uid and tier.
2. The app tier updates within ~2 seconds of payment completion.
3. Razorpay Dashboard (Live Mode) shows the webhook delivery as `200 OK`.

### Summary Table

| Item | Test Value | Live Value |
|---|---|---|
| `RAZORPAY_KEY_ID` secret | `rzp_test_...` | `rzp_live_...` |
| `RAZORPAY_KEY_SECRET` secret | test secret | live secret |
| `RAZORPAY_WEBHOOK_SECRET` secret | any string | new strong secret |
| Webhook URL | unchanged | unchanged |
| `plan_ids.pro` in Firestore | `plan_SeBEou7uXFDDRT` | new live plan ID |
| `plan_ids.enterprise` in Firestore | `plan_SeBFJKoDwsl158` | new live plan ID |
| `function_urls.create_subscription` | unchanged | unchanged |
| `function_urls.cancel_subscription` | unchanged | unchanged |
| `function_urls.resume_subscription` | unchanged | unchanged |

> The Cloud Function URLs and the Flutter app code do not change between test and production — only the secrets and plan IDs change.

---

## Razorpay Dashboard Setup Reference

For future reference, here is the full Razorpay configuration for this project:

### Webhook Configuration

- **URL**: `https://razorpaywebhook-f3n57yyena-uc.a.run.app`
- **Secret**: Value of `RAZORPAY_WEBHOOK_SECRET` Firebase secret
- **Active events**:
  - `payment.captured`
  - `payment.failed`
  - `subscription.activated`
  - `subscription.charged`
  - `subscription.halted`
  - `subscription.cancelled`
  - `subscription.completed`

### Plans (Test Mode)

| Plan | ID | Amount | Interval |
|---|---|---|---|
| Pro Monthly | `plan_SeBEou7uXFDDRT` | ₹799 | Monthly |
| Enterprise Monthly | `plan_SeBFJKoDwsl158` | ₹2,499 | Monthly |

> Static subscription links are **not used**. The `createSubscription` function creates a unique subscription per user programmatically.
