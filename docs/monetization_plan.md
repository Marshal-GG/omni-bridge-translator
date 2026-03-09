# Monetization Plan: Omni Bridge

## Overview

Omni Bridge uses a **3-tier paid subscription model** (plus a free tier) to balance server costs with user accessibility. Subscriptions are purchased via Razorpay and reflected instantly in the app through a Firestore listener. All usage is tracked server-side by LLM token count so limits cannot be bypassed on the client.

---

## Subscription Tiers

| Feature | **Free** | **Basic** | **Plus** | **Pro** |
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
  - **Free**: No history accessible. Clicking History navigates to the History page and triggers an automatic `UpgradeSheet`.
  - **Basic**: History persists for the current active window/session.
  - **Plus**: Access to translations from the last 72 hours.
  - **Pro**: Lifetime access to all past translation logs + Pro-only 5s Context Refresh.
- **Own API Key bypass**: Users who supply their own NVIDIA API Key in Settings bypass the daily quota for NVIDIA-backed engines.

---

## Quota Tracking

Usage is tracked by **character count** of the translated output text, pushed live to RTDB.

| Counter | Resets | Field |
|---|---|---|
| Daily | Midnight (local) | `users/{uid}/daily_usage/{YYYY-MM-DD}/tokens` (RTDB) |
| Monthly | 1st of each month | `monthlyCharsUsed` (Firestore) |
| Lifetime | Never | `lifetimeCharsUsed` (Firestore) |

All counters use **atomic increments** (ServerValue logic in RTDB, `FieldValue.increment()` in Firestore) — concurrent writes are safe. The `SubscriptionService` provides a live `statusStream` so the UI reacts instantly when quotas change.

### Quota Exceeded Behaviour

When a user's daily characters cross their tier's `dailyLimit`:
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
  - Basic: `https://razorpay.me/@omnibridgeweekly`

---

## Technical Implementation

### Firestore & RTDB

| Field | Written By | Notes |
|---|---|---|
| `tier` | Webhook / manual | Source of truth for subscription level |
| `daily_usage/{dt}/tokens` | `TrackingService.logModelUsage()` | Atomic RTDB increment (Daily Quota) |
| `monthlyCharsUsed` | `SubscriptionService.incrementChars()` | Atomic increment |
| `monthlyResetAt` | `SubscriptionService._resetMonthlyQuota()` | Set on each monthly reset |
| `lifetimeCharsUsed` | `SubscriptionService.incrementChars()` | Atomic increment, never resets |
| `subscriptionSince` | `SubscriptionService._logSubscriptionEvent()` | Set once on first paid upgrade |
| `paymentProvider` | `SubscriptionService._logSubscriptionEvent()` | Set once on first paid upgrade |
| `lastQuotaExceededAt` | `SubscriptionService._logQuotaExceeded()` | Updated each time quota is first crossed |
| `createdAt` | `SubscriptionService._initializeUserDoc()` | Set once at account creation |

### Character Counting
The Python server sends character counts in translation metadata payloads. The Flutter client passes it to `SubscriptionService` to track against limits.

### Enforcement
`SubscriptionService` exposes a live `statusStream`. The `TranslationBloc` (or UI layer) checks `SubscriptionStatus.isExceeded` before starting a translation — if exceeded, it shows `UpgradeSheet` instead of sending the audio.

---

## Feature Gating

Beyond quota enforcement, specific features and AI engines are locked behind tiers in the Settings UI and History Panel. Gating is applied in Flutter by reading `SubscriptionService.instance.currentStatus?.tier` at widget-build time.

### AI Translation Engines

| Engine | Minimum Tier | Enforcement |
|---|---|---|
| Google Translate | Free | Always available |
| MyMemory | Free | Always available |
| NVIDIA Riva | Basic+ | Dimmed + 🔒 badge; tap → `UpgradeSheet` |
| Llama 3.1 8B | Basic+ | Dimmed + 🔒 badge; tap → `UpgradeSheet` |

### Whisper Offline Model Sizes

| Whisper Size | Minimum Tier | Enforcement |
|---|---|---|
| Tiny / Base | Free | Always selectable |
| Small (~460 MB) | Basic+ | Disabled `DropdownMenuItem` + 🔒 badge |
| Medium (~1.5 GB) | Plus+ | Disabled `DropdownMenuItem` + 🔒 badge |

### Translation History Panel

| Tier | History Access |
|---|---|
| Free | Blocked — upsell wall with "View Plans" button |
| Basic | Live transcripts (in-memory, session-scoped only) |
| Plus | Live transcripts filtered to the last 72 hours |
| Pro | Live transcripts + **5-second Intelligent Context Refresh column** |

The history button in the overlay header only opens `/history-panel` for Basic+ users; Free users see `UpgradeSheet` directly.
