# Monetization Plan: Omni Bridge

## Overview

Omni Bridge uses a **3-tier paid subscription model** (plus a free tier) to balance server costs with user accessibility. Subscriptions are purchased via Razorpay and reflected instantly in the app through- **Real-time Monitoring**: Daily, **weekly**, and monthly usage is tracked in RTDB and streamed to the UI. All usage is tracked by **token count** (input + output) in RTDB, providing an engine-agnostic metric that scales across local and cloud models.

---

## Subscription Tiers

| Feature | **Free** | **Basic** | **Plus** | **Pro** |
| :--- | :--- | :--- | :--- | :--- |
| **Price** | ₹0 | ₹49/week | ₹149/month | ₹399/month |
| **Daily Quota** | 10,000 tokens | 50,000 tokens | 100,000 tokens | Unlimited |
| **History Access** | ❌ None | 🕒 Same session | 📅 3 days | ✅ Unlimited |
| **Models** | Standard | High-Speed | Advanced AI | Premium Engines |
| **Live Captions** | Basic | Standard | Advanced | Auto-Correct |
| **Intelligent Context Refresh (5s)** | ❌ | ❌ | ❌ | ✅ |
| **Support** | Community | Standard | Priority | 24/7 Priority |

### Feature Details

- **Intelligent Context Refresh (5s)**: A Pro-only AI feature that retroactively corrects previous translation chunks as more context becomes available mid-session.
- **Tiered History**:
  - **Free**: No history accessible. Clicking History navigates to the History page and triggers an automatic `UpgradeSheet`.
  - **Basic**: History persists for the current active window/session.
  - **Plus**: Access to translations from the last 72 hours.
  - **Pro**: Lifetime access to all past translation logs + Pro-only 5s Context Refresh.
- **Own API Key bypass**: Users who supply their own NVIDIA API Key in Settings bypass the daily quota for NVIDIA-backed engines.

---

Usage is tracked by **token count** (Input + Output tokens), pushed live to RTDB. This ensures that even free engines (like Google Translate) still contribute to the daily quota, preventing cost leakage.

| Counter | Resets | Field |
|---|---|---|
| Daily | Midnight (local) | `users/{uid}/daily_usage/{YYYY-MM-DD}/tokens` (RTDB) |
| Weekly | Monday (local) | `users/{uid}/usage/totals/weekly` (RTDB) |
| Monthly | Calendar | `users/{uid}/usage/totals/calendar_monthly` (RTDB) |
| Subscription | Billing-cycle (30 days) | `users/{uid}/usage/totals/subscription_monthly` (RTDB) |
| Lifetime | Never | `users/{uid}/usage/totals/lifetime` (RTDB) |

All counters use **atomic increments** (ServerValue logic in RTDB, `FieldValue.increment()` in Firestore) — concurrent writes are safe. The `SubscriptionService` provides a live `statusStream` so the UI reacts instantly when quotas change.

### Quota Exceeded Behaviour

When a user's daily tokens cross their tier's `dailyLimit`:
1. `lastQuotaExceededAt` is written to Firestore (timestamp of first breach).
2. A `quota_exceeded` event is posted to the RTDB `logs/` stream with `tier` and `dailyLimit`.
3. The UI navigates the user to the History page, where the contextual `UpgradeSheet` is automatically displayed for free-tier users to encourage conversion.

> The quota-exceeded event fires **only once per crossing**, not on every subsequent call, to avoid log spam.

---

## Subscription Event Audit Trail

Every tier change (upgrade or downgrade) is written to `users/{uid}/subscription_events/{push-id}` in Firestore:

```json
{
  "event": "upgraded",
  "from": "free",
  "to": "plus",
  "timestamp": "...",
  "via": "razorpay"
}
```

On the **first paid upgrade**, two additional fields are set once on the root user doc and never overwritten:

| Field | Value |
|---|---|
| `subscriptionSince` | Server timestamp of first conversion |
| `paymentProvider` | `"razorpay"` |

This enables LTV calculations and churn analysis over time.

---

## Payment Integration

- **Primary provider:** Razorpay (optimised for UPI and the Indian market).
- **Flow:** User taps Upgrade → `SubscriptionService.openCheckout()` opens the Razorpay payment link in system browser → payment completes → webhook or manual update sets `tier` in Firestore → Firestore listener updates app state instantly.
- **Razorpay links:**
  - Pro: `https://razorpay.me/@omnibridgepro`
  - Plus: `https://razorpay.me/@omnibridgeplus`
  - Basic: `https://razorpay.me/@omnibridgebasic`

---

## Technical Implementation

### Firestore & RTDB

| Field | Written By | Notes |
|---|---|---|---|
| `tier` | Webhook / manual | **Admin-Protected.** Source of truth for tier. |
| `usage/totals/weekly` | `TrackingService` | Atomic RTDB increment. Reset weekly. |
| `usage/totals/calendar_monthly`| `TrackingService` | **Daily/Monthly total.** Atomic RTDB increment. |
| `usage/totals/subscription_monthly`| `TrackingService` | Atomic RTDB increment. Reset by `SubscriptionService`. |
| `monthlyResetAt` | `SubscriptionService._resetMonthlyQuota()` | Advanced by 30 days on reset (Firestore anchor). |
| `usage/totals/lifetime` | `TrackingService` | Atomic RTDB increment, never resets. |
| `subscriptionSince` | `SubscriptionService._logSubscriptionEvent()` | Set once on first paid upgrade |
| `paymentProvider` | `SubscriptionService._logSubscriptionEvent()` | Set once on first paid upgrade |
| `lastQuotaExceededAt` | `SubscriptionService._logQuotaExceeded()` | Updated each time quota is first crossed |
| `createdAt` | `SubscriptionService._initializeUserDoc()` | Set once at account creation |

### Token Counting
The Python server sends token counts for both **Input** (from ASR) and **Output** (from Translator) in translation metadata payloads. The Flutter client passes these to `SubscriptionService` to track against limits in RTDB.

### Enforcement
- **Client-Side Polling**: `SubscriptionService` polls the RTDB `daily_usage/tokens` node every 3 seconds.
- **Gatekeeping**: `TranslationBloc` checks `SubscriptionStatus.isExceeded` before starting sessions. If exceeded, the app prevents audio capture and displays the `UpgradeSheet`.
- **Backend Rules**: Firestore security rules block unauthorized writes to `tier` and other sensitive fields.

---

## Feature Gating

Beyond quota enforcement, specific features and AI engines are locked behind tiers. Gating is applied in Flutter by calling `SubscriptionService.instance.getRequirement(featureKey)`. This mapping is fetched dynamically from Firestore.

### AI Translation Engines

| Engine | Requirement Key | Default Tier |
|---|---|---|
| Google Translate | `google` | Free |
| MyMemory | `mymemory` | Free |
| NVIDIA Riva | `riva` | Basic+ |
| Llama 3.1 8B | `llama` | Plus+ |

### Whisper Offline Model Sizes

| Whisper Size | Requirement Key | Default Tier |
|---|---|---|
| base / base.en | `whisper-base` | Free |
| small | `whisper-small` | Basic+ |
| medium | `whisper-medium` | Plus+ |
| large-v3 | `whisper-large-v3`| Pro |

### Translation History Panel

| Tier | History Access |
|---|---|
| Free | Blocked — upsell wall with "View Plans" button |
| Basic | Live transcripts (in-memory, session-scoped only) |
| Plus | Live transcripts filtered to the last 72 hours |
| Pro | Live transcripts + **5-second Intelligent Context Refresh column** |

The history button in the overlay header only opens `/history-panel` for Basic+ users; Free users see `UpgradeSheet` directly.
