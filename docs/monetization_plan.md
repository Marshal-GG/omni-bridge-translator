# Monetization Plan: Omni Bridge

## Overview

Omni Bridge uses a **3-tier paid subscription model** (plus a free tier) to balance server costs with user accessibility. Subscriptions are purchased via Razorpay and reflected instantly in the app through a Firestore listener. All usage is tracked server-side by character count so limits cannot be bypassed on the client.

---

## Subscription Tiers

| Feature | **Free** | **Weekly** | **Plus** | **Pro** |
| :--- | :--- | :--- | :--- | :--- |
| **Price** | ₹0 | ₹49/week | ₹149/month | ₹399/month |
| **Daily Quota** | 10,000 chars | 50,000 chars | 100,000 chars | Unlimited |
| **History Access** | ❌ None | 🕒 Same session | 📅 3 days | ✅ Unlimited |
| **Models** | Standard | High-Speed | Advanced AI | Premium Engines |
| **Live Captions** | Basic | Standard | Advanced | Auto-Correct |
| **Intelligent Context Refresh (5s)** | ❌ | ❌ | ❌ | ✅ |
| **Support** | Community | Standard | Priority | 24/7 Priority |

### Feature Details

- **Intelligent Context Refresh (5s)**: A Pro-only AI feature that retroactively corrects previous translation chunks as more context becomes available mid-session.
- **Tiered History**:
  - **Free**: No history saved between sessions.
  - **Weekly**: History persists only for the current active window/session.
  - **Plus**: Full access to translations from the last 72 hours.
  - **Pro**: Lifetime access to all past translation logs.
- **Own API Key bypass**: Users who supply their own NVIDIA API Key in Settings bypass the daily quota for NVIDIA-backed engines.

---

## Quota Tracking

Usage is tracked by **character count** of the translated output text.

| Counter | Resets | Firestore Field |
|---|---|---|
| Daily | Midnight (local) | `dailyCharsUsed` + `dailyResetAt` |
| Monthly | 1st of each month | `monthlyCharsUsed` + `monthlyResetAt` |
| Lifetime | Never | `lifetimeCharsUsed` |

All counters use **atomic Firestore increments** via `FieldValue.increment()` — concurrent writes are safe. The `SubscriptionService` provides a live `statusStream` so the UI reacts instantly when quotas change.

### Quota Exceeded Behaviour

When a user's `dailyCharsUsed` reaches `dailyLimit`:
1. `lastQuotaExceededAt` is written to Firestore (timestamp of first breach).
2. A `quota_exceeded` event is posted to the RTDB `logs/` stream with `tier`, `dailyLimit`, and `dailyCharsUsed`.
3. The UI surfaces an upgrade prompt (`UpgradeSheet`).

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
  - Weekly: `https://razorpay.me/@omnibridgeweekly`

---

## Technical Implementation

### Firestore (`users/{uid}`)

| Field | Written By | Notes |
|---|---|---|
| `tier` | Webhook / manual | Source of truth for subscription level |
| `dailyCharsUsed` | `SubscriptionService.incrementChars()` | Atomic increment |
| `dailyResetAt` | `SubscriptionService._resetDailyQuota()` | Set on each daily reset |
| `monthlyCharsUsed` | `SubscriptionService.incrementChars()` | Atomic increment |
| `monthlyResetAt` | `SubscriptionService._resetMonthlyQuota()` | Set on each monthly reset |
| `lifetimeCharsUsed` | `SubscriptionService.incrementChars()` | Atomic increment, never resets |
| `subscriptionSince` | `SubscriptionService._logSubscriptionEvent()` | Set once on first paid upgrade |
| `paymentProvider` | `SubscriptionService._logSubscriptionEvent()` | Set once on first paid upgrade |
| `lastQuotaExceededAt` | `SubscriptionService._logQuotaExceeded()` | Updated each time quota is first crossed |
| `createdAt` | `SubscriptionService._initializeUserDoc()` | Set once at account creation |

### WebSocket Metadata
The Python server sends `input_chars` and `output_chars` in translation metadata payloads. The Flutter client reads `output_chars` and passes it to `SubscriptionService.incrementChars()`.

### Enforcement
`SubscriptionService` exposes a live `statusStream`. The `TranslationBloc` (or UI layer) checks `SubscriptionStatus.isExceeded` before starting a translation — if exceeded, it shows `UpgradeSheet` instead of sending the audio.
