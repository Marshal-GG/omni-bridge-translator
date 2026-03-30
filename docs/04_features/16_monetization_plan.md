# 16 — Monetization Plan

## Overview

Omni Bridge uses a **tiered subscription model** (Free / Pro / Enterprise) with an optional one-time **Trial** to balance server costs with user accessibility. Subscriptions are purchased via Razorpay and reflected instantly in the app. **Real-time Monitoring**: Daily, **weekly**, and monthly usage is tracked in RTDB and streamed to the UI. All usage is tracked by **token count** (input + output) in RTDB, providing an engine-agnostic metric that scales across local and cloud models.

---

## Subscription Tiers

All values below are the defaults seeded via the Admin Panel's **System Config**. Every field is dynamically sourced from `system/monetization → tiers` in Firestore — changes take effect without an app update.

| Feature | **Free** | **Pro** | **Enterprise** |
| :--- | :--- | :--- | :--- |
| **Price** | Free | ₹799/mo | ₹2,499/mo |
| **Daily Quota** | 20,000 tokens | 100,000 tokens | 500,000 tokens |
| **Monthly Quota** | 300,000 tokens | 1,500,000 tokens | 10,000,000 tokens |
| **Transcription Models** | Google Online only | All (Google, Whisper tiny–medium, Riva) | All (Google, Whisper tiny–medium, Riva) |
| **Translation Models** | Google Translate only | All (Google, MyMemory, Google Cloud gRPC, Riva, Llama) | All |
| **Google Translate & ASR** | ✅ (only available engines) | ✅ Unlimited (no per-model cap) | ✅ Unlimited (no per-model cap) |
| **Microphone Audio** | No | Yes | Yes |
| **History Access** | None | 7-day retention | 30-day retention |
| **Session Duration** | 1 hour | 4 hours | 12 hours |
| **Concurrent Sessions** | 1 | 2 | 5 |
| **Requests/min** | 20 | 60 | 120 |

> **Token-to-time estimate**: ~20,000 tokens ≈ 30 minutes of active translation usage.

### Per-Engine Monthly Limits

Paid tiers have per-engine monthly token caps. `google` (Translate) and `online` (ASR) are **exempt** from per-engine caps — they follow only the global daily/monthly quotas. When a paid engine's cap is exceeded, the client uses a **hybrid fallback behaviour** (see [Quota Exceeded Behaviour](#quota-exceeded-behaviour)).

| Engine | Pro | Enterprise |
|---|---|---|
| `google_api` | 500,000 | 3,300,000 |
| `riva` | 500,000 | 3,300,000 |
| `llama` | 500,000 | 3,300,000 |
| All other paid models | 500,000 / model | 3,300,000 / model |

Per-engine usage is tracked in RTDB at `daily_usage/{date}/models/{engine}/tokens`.

### Trial Tier

A **free, one-time 24-hour Trial** tier allows new users to test Pro-level features before committing:

- **Activation**: `SubscriptionService.activateTrial()` — sets `tier: 'trial'`, records `trial_used: true` and `trialExpiresAt` on the user doc.
- **Price**: Free (₹0).
- **Duration**: 24 hours. Configurable via `tiers.trial.trial_duration_hours`.
- **One-time only**: `hasUsedTrial()` checks the `trial_used` flag — once used, it cannot be re-activated.
- **Auto-expiry**: `_checkTrialExpiry()` runs on every user doc snapshot while `tier == 'trial'`. When `trialExpiresAt` is passed, the user is automatically downgraded to the free tier.

### Feature Details

- **Tiered History**:
  - **Free**: No history accessible. Clicking History triggers an automatic `UpgradeSheet`.
  - **Pro**: Caption history with 7-day retention.
  - **Enterprise**: Caption history with 30-day retention.
- **Own API Key bypass**: Users who supply their own NVIDIA API Key in Settings bypass the daily quota for NVIDIA-backed engines.
- **Model Access Control**: All tier-based model access is defined dynamically in `system/monetization → tiers.{tier}.allowed_translation_models` and `allowed_transcription_models`. Enforced client-side via `SubscriptionService.canUseModel()`. Admins can disable any model globally via `model_overrides.{modelId}.enabled = false`.

---

## Usage Tracking

Usage is tracked by **token count** (Input + Output tokens), pushed live to RTDB. This ensures that even free engines (like Google Translate) still contribute to the daily quota, preventing cost leakage.

| Counter | Resets | Field |
|---|---|---|
| Daily | Midnight (local) | `users/{uid}/daily_usage/{YYYY-MM-DD}/tokens` (RTDB) |
| Weekly | Monday (local) | `users/{uid}/usage/totals/weekly` (RTDB) |
| Monthly (Calendar) | 1st of month | `users/{uid}/usage/totals/calendar_monthly` (RTDB) |
| Monthly (Subscription) | Billing-cycle (30 days) | `users/{uid}/usage/totals/subscription_monthly` (RTDB) |
| Lifetime | Never | `users/{uid}/usage/totals/lifetime` (RTDB) |

All counters use **atomic increments** (ServerValue logic in RTDB, `FieldValue.increment()` in Firestore) — concurrent writes are safe. The `SubscriptionService` provides a live `statusStream` so the UI reacts within one poll cycle when quotas change.

### Quota Exceeded Behaviour

#### Global (Daily / Monthly) Quota Exceeded

When a user's daily tokens cross their tier's `dailyLimit` or their monthly tokens cross the `monthlyLimit`:
1. `lastQuotaExceededAt` is written to Firestore (timestamp of first breach).
2. Translation is paused — `TranslationBloc` checks `SubscriptionStatus.isExceeded`.
3. The UI displays the contextual `UpgradeSheet` for free-tier users to encourage conversion.

> The quota-exceeded event fires **only once per crossing**, not on every subsequent call, to avoid log spam.

#### Per-Engine Monthly Limit Exceeded (Hybrid Approach)

When a specific paid engine's monthly token cap is reached:

1. **First occurrence in the session**: Translation is paused and a dialog appears:
   - Title: "Model Token Limit Reached"
   - Body: "You've used all your {ModelDisplayName} tokens for this billing cycle."
   - CTA 1: **"Switch to Google Translate"** → switches the active engine to `google` and resumes.
   - CTA 2: **"Upgrade Plan"** → navigates to Settings (subscription section).
2. **Subsequent calls in the same session**: The app **silently falls back** to `google` (free engine) to avoid repeatedly blocking the user. A persistent indicator appears in the translation header: *"Using Google Translate — {OriginalModel} limit reached"*.
3. **Session tracking**: An in-memory `Set<String> _notifiedEngines` tracks which engines have already shown the dialog. This resets on app restart.

---

## Subscription Event Audit Trail

Every tier change (upgrade or downgrade) is written to `users/{uid}/subscription_events/{push-id}` in Firestore:

```json
{
  "event": "upgraded",
  "from": "free",
  "to": "pro",
  "timestamp": "...",
  "via": "razorpay"
}
```

On the **first paid upgrade**, additional fields are set once on the root user doc and never overwritten:

| Field | Value |
|---|---|
| `subscriptionSince` | Server timestamp of first conversion |
| `paymentProvider` | `"razorpay"` |
| `monthlyResetAt` | Anchored to `now + 30 days` (billing cycle start) |

This enables LTV calculations and churn analysis over time.

---

## Payment Integration

- **Primary provider:** Razorpay (optimised for UPI and the Indian market).
- **Flow:** User taps Upgrade → `SubscriptionService.openCheckout(tierId)` reads the payment URL from `system/monetization → payment_links.{tierId}` → opens in system browser → payment completes → webhook or manual admin update sets `tier` in Firestore → Firestore listener updates app state instantly.
- **Dynamic links:** Payment URLs are stored in `system/monetization → payment_links` map, keyed by tier ID (e.g., `pro`, `enterprise`). No URLs are hardcoded in the client.

---

## Technical Implementation

### Firestore & RTDB

| Field | Written By | Notes |
|---|---|---|
| `tier` | Webhook / manual | **Admin-Protected.** Source of truth for tier. |
| `usage/totals/weekly` | `TrackingService` | Atomic RTDB increment. Reset weekly. |
| `usage/totals/calendar_monthly`| `TrackingService` | Atomic RTDB increment. Reset on 1st of month. |
| `usage/totals/subscription_monthly`| `TrackingService` | Atomic RTDB increment. Reset by `SubscriptionService`. |
| `monthlyResetAt` | `SubscriptionService._resetMonthlyQuota()` | Advanced by 30 days on reset (Firestore anchor). |
| `usage/totals/lifetime` | `TrackingService` | Atomic RTDB increment, never resets. |
| `subscriptionSince` | `SubscriptionService._logSubscriptionEvent()` | Set once on first paid upgrade |
| `paymentProvider` | `SubscriptionService._logSubscriptionEvent()` | Set once on first paid upgrade |
| `lastQuotaExceededAt` | `SubscriptionService._logQuotaExceeded()` | Updated each time quota is first crossed |
| `createdAt` | `SubscriptionService._initializeUserDoc()` | Set once at account creation |
| `trial_used` | `SubscriptionService.activateTrial()` | Set to `true` on first trial activation |
| `trialExpiresAt` | `SubscriptionService.activateTrial()` | Timestamp when trial auto-expires |

### Token Counting
The Python server sends token counts for both **Input** (from ASR) and **Output** (from Translator) in translation metadata payloads. The Flutter client passes these to `TrackingService.logModelUsage()` to track against limits in RTDB.

### Enforcement
- **Client-Side Polling**: `SubscriptionService` polls RTDB `daily_usage/tokens` and `usage/totals` at an interval sourced from `system/monetization → usage_poll_interval_seconds` (default **30s**). An initial fetch runs immediately on sign-in. If the interval is updated in Firestore, the timer restarts automatically.
- **Gatekeeping**: `TranslationBloc` checks `SubscriptionStatus.isExceeded` before starting sessions. If exceeded, the app prevents audio capture and displays the `UpgradeSheet`.
- **Per-Engine Enforcement**: `SubscriptionService.engineLimits()` and `engineMonthlyLimit(engineId)` expose per-engine monthly caps from `tiers.{tier}.engine_limits`. When exceeded, the client uses the hybrid fallback approach (dialog once, then silent switch to `google`).
- **Backend Rules**: Firestore security rules block unauthorized writes to `tier` and other sensitive fields.

---

## Feature Gating

Beyond quota enforcement, specific features and AI engines are locked behind tiers. Gating is enforced via `SubscriptionService.canUseModel(modelId)`, which performs a dual check:
1. **Tier Access**: Is the model in `tiers.{userTier}.allowed_translation_models` or `allowed_transcription_models`?
2. **Kill Switch**: Is `model_overrides.{modelId}.enabled` set to `true`?

Both must pass. All config is fetched dynamically from `system/monetization` — changes take effect without an app update.

### AI Translation Engines

| Engine | Model ID | Free | Pro | Enterprise |
|---|---|---|---|---|
| Google Translate | `google` | Yes | Yes (unlimited) | Yes (unlimited) |
| MyMemory | `mymemory` | - | Yes | Yes |
| Google Cloud (gRPC) | `google_api` | - | Yes (500K/mo cap) | Yes (3.3M/mo cap) |
| NVIDIA Riva | `riva` | - | Yes (500K/mo cap) | Yes (3.3M/mo cap) |
| Llama 3.1 8B | `llama` | - | Yes (500K/mo cap) | Yes (3.3M/mo cap) |

Locked engines are blocked via `onBeforeChange` in the dropdown — `canUseModel()` returns `false`, preventing selection.

### Transcription Models

| Model | Model ID | Free | Pro | Enterprise |
|---|---|---|---|---|
| Google Online | `online` | Yes | Yes (unlimited) | Yes (unlimited) |
| Whisper Tiny | `whisper-tiny` | - | Yes | Yes |
| Whisper Base | `whisper-base` | - | Yes | Yes |
| Whisper Small | `whisper-small` | - | Yes | Yes |
| Whisper Medium | `whisper-medium` | - | Yes | Yes |
| NVIDIA Riva | `riva` | - | Yes | Yes |

Locked transcription options render with reduced opacity and a lock icon. The `_TranscriptionOption` widget accepts a `locked` parameter that disables tap interaction.

### Model Kill Switches

Admins can disable any model globally via `model_overrides.{modelId}.enabled = false` in `system/monetization`. This takes effect immediately for all tiers — useful during outages or quota exhaustion on external APIs.

### Translation History Panel

| Tier | History Access |
|---|---|
| Free | Blocked — upsell wall with "View Plans" button |
| Pro | Caption history with 7-day retention |
| Enterprise | Caption history with 30-day retention |

The history button in the overlay header only opens `/history-panel` for Pro+ users; Free users see `UpgradeSheet` directly.
