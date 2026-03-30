<!--
 Copyright (c) 2026 Omni Bridge. All rights reserved.
 
 Licensed under the PERSONAL STUDY & LEARNING LICENSE v1.0.
 Commercial use and public redistribution of modified versions are strictly prohibited.
 See the LICENSE file in the project root for full license terms.
-->

# 07 — Database Schema

## Overview

| Database | Used For |
|---|---|
| **Cloud Firestore** | User profile, historical usage archives, session tracking, settings, legal docs, admin lists |
| **Realtime Database (RTDB)** | Live captions, logs, real-time usage metrics (daily, monthly, lifetime) |
| **Storage** | (Not used yet) |

---

## Security & Access Control

To protect the integrity of the business model and user sessions without cloud functions, Firestore uses granular **Security Rules**.

| Access Level | Permitted Actions | Restricted Fields |
|---|---|---|
| **Admin** | Full Read/Write on all documents. | None. |
| **User (Owner)** | Read own profile/sessions/settings. Write usage counters and settings. | `tier`, `subscriptionSince`, `paymentProvider`, `forceLogout` (transitions). |
| **Public** | No access. | All. |

> [!IMPORTANT]
> **Field-Level Protection**: Users can never upgrade their own `tier` or change `subscriptionSince`. These must be set via the Firebase Console, Admin Panel, or a backend process.
> 
> **forceLogout Transition**: Users are permitted to write `forceLogout: false` ONLY if the current value is `true`. This allows the client to "reset" the flag after performing a remote logout, while preventing users from un-banning themselves if an admin sets it to `true`.
 
## Build Mode Isolation
 
To prevent session overlap between development (VS Code) and installed versions, Omni Bridge uses **Named Firebase Apps**.
 
| Build Mode | Firebase App Name | Isolation Level |
|---|---|---|
| **Debug** | `OmniBridge-Debug` | Isolated local persistence (Auth tokens, Firestore cache, RTDB local store) |
| **Release** | `OmniBridge-Release` | Isolated local persistence |
 
> [!NOTE]
> While both apps point to the same Firebase Project, they are logically separated on the client. This means logging into the Debug version will **not** share a session with the Release version.

---

## Firestore Structure

There are three main root paths in Firestore:
```
users/{uid}/
system/admins
system/monetization
system/app_version
system/translation_config
legal/{documentId}
```

---

### System Configuration — `system/admins`

A singleton document used to manage administrative access to the platform.

```json
{
  "emails": [
    "user1@example.com",
    "user2@example.com"
  ]
}
```

| Field | Type | Notes |
|---|---|---|
| `emails` | `array` | List of email strings authorized to access the Admin Panel. |

> [!NOTE]
| **Bootstrap Admin**: The email `marshalgcom@gmail.com` is hardcoded as the primary administrator in `firestore.rules` to allow initial system configuration and recovery. |
 
---
 
### Monetization Configuration — `system/monetization`

A singleton document used to manage dynamic pricing, tier configs, model access control, and feature gates. Seeded via the Admin Panel's **System Config** section.

```json
{
  "order": ["free", "trial", "pro", "enterprise"],
  "popular": "pro",
  "usage_poll_interval_seconds": 30,
  "fallback_engine": "google",
  "tiers": {
    "free": {
      "name": "Free",
      "price": "₹0",
      "description": "Basic translation for casual use",
      "display_features": ["Google Translate only", "Google Online ASR", "Desktop audio capture", "20,000 tokens/day · 300K/month"],
      "allowed_transcription_models": ["online"],
      "allowed_translation_models": ["google"],
      "features": {
        "mic_audio": false,
        "history_enabled": false,
        "caption_retention_days": 0,
        "simultaneous_sessions": 1,
        "session_duration_hours": 1
      },
      "quotas": { "daily_tokens": 20000, "monthly_tokens": 300000 },
      "engine_limits": {},
      "rate_limits": { "requests_per_minute": 20, "concurrent_sessions": 1 }
    },
    "trial": {
      "name": "Trial",
      "price": "₹0",
      "description": "Free one-time 24-hour pass — full engine access",
      "is_trial": true,
      "trial_duration_hours": 24,
      "display_features": ["All translation & transcription engines", "Microphone + desktop audio", "50,000 tokens for 24 hours", "One-time per account"],
      "allowed_transcription_models": ["online", "whisper-tiny", "whisper-base", "whisper-small", "whisper-medium", "riva"],
      "allowed_translation_models": ["google", "mymemory", "google_api", "riva", "llama"],
      "features": {
        "mic_audio": true,
        "history_enabled": false,
        "caption_retention_days": 0,
        "simultaneous_sessions": 1,
        "session_duration_hours": 24
      },
      "quotas": { "daily_tokens": 50000, "monthly_tokens": 50000 },
      "engine_limits": {},
      "rate_limits": { "requests_per_minute": 60, "concurrent_sessions": 1 }
    },
    "pro": {
      "name": "Pro",
      "price": "₹799/mo",
      "description": "All engines with generous limits",
      "display_features": ["All translation engines", "Whisper transcription (tiny–medium)", "Microphone + desktop audio", "Caption history (7 days)", "100,000 tokens/day · 1.5M/month", "500K tokens/month per paid engine"],
      "allowed_transcription_models": ["online", "whisper-tiny", "whisper-base", "whisper-small", "whisper-medium", "riva"],
      "allowed_translation_models": ["google", "mymemory", "google_api", "riva", "llama"],
      "features": {
        "mic_audio": true,
        "history_enabled": true,
        "caption_retention_days": 7,
        "simultaneous_sessions": 2,
        "session_duration_hours": 4
      },
      "quotas": { "daily_tokens": 100000, "monthly_tokens": 1500000 },
      "engine_limits": { "google_api": 500000, "riva": 500000, "llama": 500000 },
      "rate_limits": { "requests_per_minute": 60, "concurrent_sessions": 2 }
    },
    "enterprise": {
      "name": "Enterprise",
      "price": "₹2,499/mo",
      "description": "Maximum capacity for power users",
      "display_features": ["Everything in Pro", "Whisper medium + Riva transcription", "Caption history (30 days)", "Up to 5 simultaneous sessions", "500,000 tokens/day · 10M/month", "3.3M tokens/month per paid engine"],
      "allowed_transcription_models": ["online", "whisper-tiny", "whisper-base", "whisper-small", "whisper-medium", "riva"],
      "allowed_translation_models": ["google", "mymemory", "google_api", "riva", "llama"],
      "features": {
        "mic_audio": true,
        "history_enabled": true,
        "caption_retention_days": 30,
        "simultaneous_sessions": 5,
        "session_duration_hours": 12
      },
      "quotas": { "daily_tokens": 500000, "monthly_tokens": 10000000 },
      "engine_limits": { "google_api": 3300000, "riva": 3300000, "llama": 3300000 },
      "rate_limits": { "requests_per_minute": 120, "concurrent_sessions": 5 }
    }
  },
  "model_overrides": {
    "online":         { "enabled": true, "display_name": "Google Speech" },
    "google":         { "enabled": true, "display_name": "Google Translate" },
    "mymemory":       { "enabled": true, "display_name": "MyMemory" },
    "google_api":     { "enabled": true, "display_name": "Google Cloud" },
    "riva":           { "enabled": true, "display_name": "NVIDIA Riva" },
    "llama":          { "enabled": true, "display_name": "Llama 3.1" },
    "whisper-tiny":   { "enabled": true, "display_name": "Whisper Tiny" },
    "whisper-base":   { "enabled": true, "display_name": "Whisper Base" },
    "whisper-small":  { "enabled": true, "display_name": "Whisper Small" },
    "whisper-medium": { "enabled": true, "display_name": "Whisper Medium" }
  },
  "announcements": {
    "active": false,
    "message": "",
    "type": "info",
    "dismiss_key": "",
    "target_tiers": ["free", "trial", "pro", "enterprise"]
  },
  "upgrade_prompts": {
    "show_at_usage_percent": 80,
    "free_trial_days": 7,
    "promo_code_enabled": false,
    "promo_message": "",
    "feature_locked": {
      "title": "Upgrade Your Plan",
      "message": "Get more daily tokens and unlock exclusive features like premium translation engines.",
      "highlights": ["Priority Support"]
    }
  },
  "payment_links": { "trial": "", "pro": "", "enterprise": "" }
}
```

| Field | Type | Notes |
|---|---|---|
| `order` | `array` | Tier IDs in rank order (index 0 = free/default) |
| `popular` | `string` | The ID of the tier to highlight as "Popular" |
| `usage_poll_interval_seconds` | `number` | RTDB usage polling interval (default: 30) |
| `tiers` | `map` | Per-tier config (see below) |
| `model_overrides` | `map` | Global kill switches per model (`enabled: false` disables for all tiers) |
| `announcements` | `map` | Banner config: `active`, `message`, `type`, `dismiss_key`, `target_tiers` |
| `upgrade_prompts` | `map` | Upgrade prompt config: `show_at_usage_percent`, `free_trial_days`, `promo_code_enabled` |
| `payment_links` | `map?` | Razorpay payment URLs keyed by tier ID (e.g., `{"pro": "https://razorpay.me/...", "enterprise": "https://..."}`) |

**Per-Tier Fields** (`tiers.{tierId}`):

| Field | Type | Notes |
|---|---|---|
| `name` | `string` | Display name |
| `price` | `string` | Price string shown in UI (e.g., `"₹799/mo"`) |
| `description` | `string` | Short description |
| `display_features` | `array` | Feature bullet points for subscription UI |
| `allowed_transcription_models` | `array` | Model IDs allowed for ASR (e.g., `["online", "whisper-tiny"]`) |
| `allowed_translation_models` | `array` | Model IDs allowed for translation (e.g., `["google", "mymemory", "google_api"]`) |
| `features` | `map` | Feature flags: `mic_audio`, `history_enabled`, `caption_retention_days`, `simultaneous_sessions`, `session_duration_hours` |
| `quotas` | `map` | Token limits: `daily_tokens`, `monthly_tokens` |
| `engine_limits` | `map` | Per-engine monthly token caps (e.g., `{"google_api": 500000}`). Engines not listed (`google`, `online`) are exempt. When exceeded, hybrid fallback is triggered. |
| `rate_limits` | `map` | Rate limiting: `requests_per_minute`, `concurrent_sessions` |
| `is_trial` | `bool?` | `true` if this tier is a one-time trial |
| `trial_duration_hours` | `number?` | Duration in hours (only relevant when `is_trial` is `true`, default: 24) |

> **Model Access Control**: `SubscriptionService.canUseModel(modelId)` combines two checks: (1) Is the model in the user's tier's `allowed_translation_models` or `allowed_transcription_models`? (2) Is `model_overrides.{modelId}.enabled` set to `true`? Both must pass.
>
> **Engine Limit Enforcement (Hybrid)**: When a paid engine exceeds its per-engine monthly cap:
> 1. **First occurrence**: Translation pauses and a dialog appears offering "Switch to Google Translate" or "Upgrade Plan".
> 2. **Subsequent occurrences** (same session): Silent fallback to `google` engine with a persistent UI chip showing "Using Google Translate (model limit reached)".
>
> Per-engine usage is tracked in RTDB `daily_usage/{date}/models/{engine}/tokens`. Free engines (`google`, `online`) are exempt from per-engine caps.

---

### App Version — `system/app_version`

A singleton document used to manage application updates and forced upgrades.

```json
{
  "min_supported": "1.0.0",
  "latest": "1.0.0",
  "update_url": "",
  "force_update_message": "A new version of Omni Bridge is available. Please update to continue."
}
```

| Field | Type | Notes |
|---|---|---|
| `min_supported` | `string` | The minimum semver required to run the app. If client version is lower, force update screen is shown. |
| `latest` | `string` | The latest available version. Triggers a soft update prompt if client is lower but above `min_supported`. |
| `update_url` | `string` | The URL to open for downloading the new version (e.g. GitHub releases page). |
| `force_update_message` | `string` | Custom message shown on the force update screen. |

---

### Translation Credentials — `system/translation_config`

Stores Google Cloud service account credentials for the gRPC Translation API, and dynamic function IDs for NVIDIA Riva NIM endpoints. Access is restricted by Firestore Security Rules.

```json
{
  "google_credentials": {
    "type": "service_account",
    "project_id": "...",
    "private_key_id": "...",
    "private_key": "...",
    "client_email": "...",
    "client_id": "...",
    "auth_uri": "...",
    "token_uri": "...",
    "auth_provider_x509_cert_url": "...",
    "client_x509_cert_url": "...",
    "universe_domain": "..."
  },
  "riva_nmt_fid": "...",
  "riva_parakeet_fid": "...",
  "riva_canary_fid": "..."
}
```

| Field | Type | Notes |
|---|---|---|
| `google_credentials` | `map` | Full service account dictionary sent to the Python server via WebSocket. |
| `riva_nmt_fid` | `string` | NVIDIA Riva NIM function ID for Neural Machine Translation endpoints. |
| `riva_parakeet_fid` | `string` | NVIDIA Riva NIM function ID for Parakeet ASR models. |
| `riva_canary_fid` | `string` | NVIDIA Riva NIM function ID for Canary ASR models. |

---

### Legal Documents — `legal/{documentId}`

Stores app policies like terms of service and privacy policy to allow dynamic update without an app release.

```json
{
  "content": "# Terms of Service\n\nWelcome to Omni Bridge..."
}
```

| Field | Type | Notes |
|---|---|---|
| `documentId` | `string` | ID, e.g., `"terms_of_service"`, `"privacy_policy"`, `"license"` |
| `content` | `string` | The full Markdown text format of the document. |

---

### 0. User Profile & Subscription — `users/{uid}` (root document)

Created automatically on first login by `SubscriptionService._initializeUserDoc()`. Holds subscription tier, monetization metadata, and billing anchors. **All active usage counters (daily, monthly, lifetime) live exclusively in RTDB** to prevent Firestore write rate-limiting. Firestore is used as a cold-storage archive for completed months/subscription cycles.

```json
{
  "tier": "free",
  "dailyResetAt": "2026-03-09T00:00:00Z",
  "monthlyTokensUsed": 38000,
  "monthlyResetAt": "2026-04-01T00:00:00Z",
  "lifetimeTokensUsed": 520400,
  "subscriptionSince": "2026-02-01T00:00:00Z",
  "paymentProvider": "razorpay",
  "lastQuotaExceededAt": "2026-03-08T18:30:00Z",
  "forceLogout": false,
  "createdAt": "2026-01-15T10:22:00Z"
}
```

| Field | Type | Written at | Notes |
|---|---|---|---|
| `tier` | `string` | Creation | **Admin-Write Only.** Subscription tier: `free` \| `pro` \| `enterprise` |
| `dailyResetAt` | `Timestamp` | Creation | Midnight of the next day (local). Checked on each Firestore snapshot; updated by `_resetDailyQuota()` when crossed. |
| `monthlyTokensUsed` | `number` | creation | (DEPRECATED) Cold storage only. See RTDB `usage/totals`. |
| `monthlyResetAt` | `Timestamp` | creation → First upgrade → Monthly reset | Initially the 1st of next calendar month. On first paid upgrade, anchored to `now + 30 days` (billing-cycle). Each subsequent reset advances it by another 30 days. Used as the anchor for Subscription Rollovers. |
| `lifetimeTokensUsed` | `number` | creation | (DEPRECATED) Cold storage only. See RTDB `usage/totals`. |
| `subscriptionSince` | `Timestamp?` | First upgrade | **Admin-Write Only.** Set once when the user first upgrades from `free` |
| `paymentProvider` | `string?` | First upgrade | **Admin-Write Only.** Payment provider used: `"razorpay"` |
| `lastQuotaExceededAt` | `Timestamp?` | On quota hit | Server timestamp of the most recent daily cap breach |
| `forceLogout` | `bool` | Admin write | **Global** logout flag. Admin sets `true` to kick; rules allow user-reset to `false` only after kick. |
| `trial_used` | `bool?` | Trial activation | Set to `true` when the user activates their one-time trial. Prevents re-activation. |
| `trialExpiresAt` | `Timestamp?` | Trial activation | Timestamp when the trial auto-expires. Checked by `_checkTrialExpiry()` on every user doc snapshot. |
| `trialActivatedAt` | `Timestamp?` | Trial activation | Server timestamp of when the trial was activated. |
| `createdAt` | `Timestamp` | Creation | Server timestamp of first sign-in / document creation |

**Token limits by tier (defaults; dynamically overridden by `system/monetization`):**

| Tier | Daily | Monthly | Engine Limits (per month) | Sessions | Duration |
|---|---|---|---|---|---|
| `free` | 20,000 | 300,000 | None (Google Translate only) | 1 | 1 hour |
| `trial` | 50,000 | 50,000 (one-time) | None | 1 | 24 hours |
| `pro` | 100,000 | 1,500,000 | google_api/riva/llama: 500k each | 2 | 4 hours |
| `enterprise` | 500,000 | 10,000,000 | google_api/riva/llama: 3.3M each | 5 | 12 hours |

> **Token-to-time estimate**: ~20,000 tokens ≈ 30 minutes of active translation usage.
 
> Quota limits, pricing, and feature gate requirements are fetched dynamically from `system/monetization`. Payment links are handled via Razorpay (see `SubscriptionService.openCheckout()`). Setting the `tier` field directly in Firestore (or via a backend function) upgrades the user; the Firestore listener in `_listenToUserDoc()` detects the change and fires a `subscription_events` log automatically.

---

### 0a. Subscription Events — `users/{uid}/subscription_events/{push-id}`

Written by `SubscriptionService._logSubscriptionEvent()` whenever the user's tier changes. Provides a full audit trail of upgrades and downgrades.

```json
{
  "event": "upgraded",
  "from": "free",
  "to": "pro",
  "timestamp": "2026-02-01T00:00:00Z",
  "via": "razorpay"
}
```

| Field | Type | Notes |
|---|---|---|
| `event` | `string` | `"upgraded"` or `"downgraded"` |
| `from` | `string` | Previous tier |
| `to` | `string` | New tier |
| `timestamp` | `Timestamp` | Server timestamp of the change |
| `via` | `string` | Payment provider (`"razorpay"`) |

> Quota-exceeded events are logged to `users/{uid}/logs/{push-id}` in RTDB (see RTDB Event Logs below) with `event: "quota_exceeded"` and a `data` object containing `tier`, `dailyLimit`, and `dailyTokensUsed`. `lastQuotaExceededAt` on the root Firestore user doc is also updated at the same time.

---

### 0b. Usage History (Archives) — `users/{uid}/usage_history/{doc_id}`

Historical usage is archived from RTDB to a **unified** Firestore subcollection during rollovers performed by `SubscriptionService._checkAndPerformRollovers()`. Document IDs are prefixed by period type, and each document includes a `period_type` field for filtering.

#### Calendar Archives — doc ID: `calendar_YYYY_MM`
Archived on the 1st of every month for all users.
```json
{
  "period_type": "calendar",
  "tokens": 45000,
  "archivedAt": "2026-04-01T00:00:05Z"
}
```

#### Weekly Archives — doc ID: `weekly_YYYY_MM_DD`
Archived every Monday for all users.
```json
{
  "period_type": "weekly",
  "tokens": 12500,
  "archivedAt": "2026-03-09T00:00:05Z"
}
```

#### Subscription Archives — doc ID: `subscription_YYYY-MM-DD__YYYY-MM-DD`
Archived on the subscription reset date for paid members.
```json
{
  "period_type": "subscription",
  "tokens": 78200,
  "period": "2026-03-01__2026-03-31",
  "archivedAt": "2026-03-31T18:30:00Z"
}
```

---

### 1. Sessions — `users/{uid}/sessions/{sessionId}`

```json
{
  "sessionId": "abc123xyz",
  "startTime": "2026-03-06T07:30:00Z",
  "endTime": "2026-03-06T09:10:00Z",
  "appReopenedAt": "2026-03-07T08:00:00Z",
  "durationSeconds": 5880,
  "isEnded": true,
  "forceLogout": false,
  "device": {
    "platform": "Windows Desktop",
    "computer_name": "MARSH-PC",
    "user_name": "marsh",
    "os_version": "10.0.22631",
    "product_name": "Windows 11 Home",
    "system_memory_mb": 16384,
    "wifi_ip": "192.168.1.42",
    "wifi_ipv6": "fe80::1a2b:3c4d:5e6f",
    "wifi_name": "\"HomeNetwork\"",
    "wifi_bssid": "AA:BB:CC:DD:EE:FF",
    "wifi_gateway": "192.168.1.1",
    "wifi_submask": "255.255.255.0"
  }
}
```

| Field | Type | Notes |
|---|---|---|
| `sessionId` | `string` | Firestore auto-generated doc ID (copy) |
| `startTime` | `Timestamp` | Server timestamp on session start |
| `endTime` | `Timestamp` | Server timestamp on app close |
| `appReopenedAt` | `Timestamp?` | Timestamp when an existing session is resumed |
| `durationSeconds` | `number` | `endTime - startTime` in seconds (updated on app exit) |
| `isEnded` | `bool` | `false` while running, `true` after user logs out |
| `forceLogout` | `bool` | **Per-session** logout flag. Setting `true` kicks only this specific session (e.g. remotely revoking one device). Detected by `TrackingService` session-doc listener. |
| `device.*` | `map` | OS + network snapshot at session start |

> [!NOTE]
> Two `forceLogout` flags exist at different levels: `users/{uid}.forceLogout` (global — kicks all devices at once) and `users/{uid}/sessions/{sessionId}.forceLogout` (per-session — kicks a single device). Both are monitored by `TrackingService` and call `_handleRemoteLogout()` when triggered.

---

### 2. Settings — `users/{uid}/settings/app_preferences`

Single document synced whenever the user saves settings.

```json
{
  "sourceLang": "en",
  "targetLang": "hi",
  "useMic": true,
  "fontSize": 22.0,
  "isBold": false,
  "opacity": 0.7,
  "translationModel": "google",
  "apiKey": "",
  "transcriptionModel": "google",
  "inputDeviceIndex": 1,
  "outputDeviceIndex": 0,
  "micVolume": 1.0,
  "desktopVolume": 1.2,
  "lastUpdated": "2026-03-06T07:45:00Z"
}
```

| Field | Type | Notes |
|---|---|---|
| `sourceLang` | `string` | ISO 639-1 source language code |
| `targetLang` | `string` | ISO 639-1 target language code |
| `useMic` | `bool` | `true` = mic input, `false` = desktop audio |
| `fontSize` | `number` | Caption font size in px |
| `isBold` | `bool` | Caption bold toggle |
| `opacity` | `number` | Window background opacity (0–1) |
| `translationModel` | `string` | Selected engine: `google` (default) \| `riva` \| `llama` \| `mymemory` |
| `apiKey` | `string` | NVIDIA NIM API key (empty for Google Translate / MyMemory). Stored as plaintext; readable only by the owner via Firestore security rules. |
| `transcriptionModel` | `string` | ASR backend: `google` (default) \| `whisper-tiny` \| `whisper-base` \| `whisper-small` \| `whisper-medium` |
| `inputDeviceIndex` | `number?` | Mic device index (null = system default) |
| `outputDeviceIndex` | `number?` | Desktop audio device index (null = default) |
| `micVolume` | `number` | Mic capture gain (0–2) |
| `desktopVolume` | `number` | Desktop audio gain (0–2) |
| `lastUpdated` | `Timestamp` | Server timestamp of last save |

## Realtime Database (RTDB) Structure

Written via RTDB REST multi-path `PATCH` or `POST` requests. Avoids Firestore write cost for high-frequency streaming data, logs, and all active token usage counters.

### 1. Cumulative Usage (Totals) — `users/{uid}/usage/totals`

The **Single Source of Truth** for current user usage. Polled at an interval sourced from `system/monetization → usage_poll_interval_seconds` (default 30s) by `SubscriptionService`.

```json
{
  "lifetime": 120500,
  "calendar_monthly": 15200,
  "subscription_monthly": 15200,
  "weekly": 5000,
  "last_calendar_month": "2026_03",
  "last_week": "2026-03-03"
}
```

| Field | Type | Notes |
|---|---|---|
| `lifetime` | `number` | All-time tokens used. Atomic increments. |
| `calendar_monthly` | `number` | Tokens used in current calendar month. Resets on 1st. |
| `subscription_monthly` | `number` | Tokens used in current billing cycle (paid tiers). |
| `weekly` | `number` | Tokens used in current week (Monday start). Resets on Monday. |
| `last_calendar_month` | `string` | Tracks current period in RTDB (e.g., `"2026_03"`) to trigger archive on month change. |
| `last_week` | `string` | Tracks current week in RTDB (e.g., `"2026_03_03"`, Monday anchor) to trigger archive on week change. |

---

### 2. Model Usage Log — `users/{uid}/model_usage/{push-id}`

One node written **per translation call**. Never updated after creation.

```json
{
  "engine": "riva",
  "model": "riva-asr-en",
  "latency_ms": 420,
  "prompt_tokens": 0,
  "completion_tokens": 0,
  "total_tokens": 0,
  "input_chars": 87,
  "output_chars": 94,
  "source_lang": "en",
  "target_lang": "hi",
  "fallback_from": null,
  "error": null,
  "sessionId": "abc123xyz",
  "timestamp": 1741239303000
}
```

> For all text-based engines, `total_tokens` is populated (estimated dynamically via heuristical character sizing as `((len(text) + 3) // 4)` where actual token counts aren't available).

**Engines:** `riva` | `llama` | `google` | `google_api` | `mymemory` | `whisper`

| Field | Type | Notes |
|---|---|---|
| `engine` | `string` | Which backend handled this translation |
| `model` | `string` | Exact model variant used |
| `latency_ms` | `number` | Round-trip time from send → receive |
| `total_tokens` | `number` | LLM token consumption (estimated similarly across all engines) |
| `input_tokens` | `number` | Token count of source text |
| `output_tokens` | `number` | Token count of translated text |
| `fallback_from` | `string?` | Set if this was a retry after engine failure |
| `error` | `string?` | Error message if the translation failed |
| `sessionId` | `string` | Links back to the Firestore session document |
| `timestamp` | `number` | RTDB server timestamp (ms since epoch) |

---

### 2. Model Stats (Totals) — `users/{uid}/model_stats/{engine}`

One node **per engine**, updated atomically on every translation. Use this to answer *"how much has this user used each engine?"*

```json
// users/{uid}/model_stats/riva
{
  "engine": "riva",
  "total_calls": 1482,
  "total_tokens": 0,
  "total_latency_ms": 622440,
  "total_input_tokens": 128940,
  "total_output_tokens": 139200,
  "last_used": 1741244995000
}

// users/{uid}/model_stats/llama
{
  "engine": "llama",
  "total_calls": 34,
  "total_tokens": 41200,
  "total_latency_ms": 306000,
  "total_input_tokens": 2890,
  "total_output_tokens": 3100,
  "last_used": 1741243330000
}

// users/{uid}/model_stats/google
{
  "engine": "google",
  "total_calls": 210,
  "total_tokens": 0,
  "total_latency_ms": 89040,
  "total_input_tokens": 18200,
  "total_output_tokens": 19500,
  "last_used": 1741240530000
}

// users/{uid}/model_stats/mymemory
{
  "engine": "mymemory",
  "total_calls": 45,
  "total_tokens": 0,
  "total_latency_ms": 32000,
  "total_input_tokens": 4500,
  "total_output_tokens": 4550,
  "last_used": 1741249800000
}

// users/{uid}/model_stats/whisper
{
  "engine": "whisper",
  "total_calls": 120,
  "total_tokens": 0,
  "total_latency_ms": 96000,
  "total_input_tokens": 12000,
  "total_output_tokens": 0,
  "last_used": 1741251600000
}
```

> All counters are aggregated and updated via client-side total fetching and writing. Atomic increments were removed due to REST API multi-path constraints.

---

### 3. Event Logs — `users/{uid}/logs/{push-id}` *(REMOVED)*

> **No longer written to RTDB.** All operational logging is now console-only via `debugPrint`. The `logEvent()` method in `TrackingService` writes to the console, not RTDB. Server logs go to `logs/server.log` on disk.

---

### 4. Error Logs — `users/{uid}/error_logs/{push-id}` *(REMOVED)*

> **No longer written to RTDB.** All error logging is now console-only via `debugPrint`. The `logError()` method in `TrackingService` writes to the console, not RTDB.

---

### 5. Live Captions — `users/{uid}/captions/{auto-push-id}`

Omni Bridge uses a dual-node strategy for caption streaming to maintain a clean history while providing real-time updates:

1.  **Interim Result (`current_caption`)**: While `isFinal` is `false`, the client **overwrites** this specific node. This prevents RTDB from filling with millions of partial sentence fragments.
2.  **Final Result (`captions/{push-id}`)**: When `isFinal` is `true`, the client **appends** the full sentence to the history.

```json
// Interim: users/{uid}/current_caption
// Final:   users/{uid}/captions/abc123xyz
{
  "originalText": "Good morning everyone",
  "translatedText": "सभी को सुप्रभात",
  "sourceLang": "en",
  "targetLang": "hi",
  "translationModel": "riva",
  "isFinal": true,
  "timestamp": 1741239600000,
  "sessionId": "abc123xyz"
}
```

| Field | Type | Notes |
|---|---|---|
| `originalText` | `string` | Raw transcribed speech |
| `translatedText` | `string` | Output from the AI engine |
| `sourceLang` | `string` | ISO 639-1 code, e.g. `"en"` |
| `targetLang` | `string` | ISO 639-1 code, e.g. `"hi"` |
| `translationModel` | `string` | `riva` / `llama` / `google` / `mymemory` / `whisper` |
| `isFinal` | `bool` | `false` = partial result, `true` = committed |
| `timestamp` | `number` | RTDB server timestamp (ms since epoch) |
| `sessionId` | `string` | Links back to the Firestore session |

---

### 6. Daily Usage (Quota) — `users/{uid}/daily_usage/{YYYY-MM-DD}`

Tracks aggregated usage for a specific calendar day. The path key is the date string (`YYYY-MM-DD` in local time). This is the **primary source** for the user's daily token quota — `SubscriptionService` polls `tokens` every **3 seconds** and surfaces it as `SubscriptionStatus.dailyTokensUsed`.

> [!TIP]
> **Performance Optimization**: To minimize HTTP overhead, the client buffers usage tokens locally and flushes them to this node using a single **multi-path `PATCH`** request. This updates the global `tokens` count and the model-specific `models/{engine}/tokens` counters simultaneously.

```json
{
  "tokens": 14200,
  "last_updated": 1741239600000,
  "models": {
    "llama": {
      "calls": 12,
      "tokens": 4200,
      "last_updated": 1741239600000
    },
    "google": {
      "calls": 45,
      "tokens": 10000,
      "last_updated": 1741238500000
    }
  },
  "errors": {
    "riva": {
      "failed_calls": 2,
      "last_error": "Connection refused",
      "last_error_time": 1741237000000
    }
  }
}
```


| Sub-path | Type | Notes |
|---|---|---|
| `tokens` | `number` | **Total `input_tokens + output_tokens`** for all engines today (primary daily quota counter, polled by `SubscriptionService` at the configured interval) |
| `last_updated` | `number` | RTDB server timestamp of the last write |
| `models/{engine}/tokens` | `number` | `input_tokens + output_tokens` for a specific engine today |
| `models/{engine}/calls` | `number` | Successful translation calls for the engine today |
| `errors/{engine}/failed_calls` | `number` | Non-fatal translation API errors grouped by engine |
| `errors/{engine}/last_error` | `string` | Last error message for the engine |
| `errors/{engine}/last_error_time` | `number` | RTDB timestamp of the last error |

---

### 7. RTDB Session Logs — `users/{uid}/sessions/{sessionId}`

Written on session start, ping, and end to provide a lightweight real-time mirror to the Firestore session document. Highly useful for detecting "currently active" sessions cheaply via RTDB listeners, dropping off if `last_ping_at` goes stale.

```json
{
  "started_at": 1741238000000,
  "last_ping_at": 1741249500000,
  "ended_at": 1741249600000,
  "duration_seconds": 11600
}
```

| Field | Type | Notes |
|---|---|---|
| `started_at` | `number` | Server timestamp when session opened |
| `last_ping_at` | `number?` | Server timestamp updated every **1 minute** by the client |
| `ended_at` | `number?` | Server timestamp when app closed cleanly |
| `duration_seconds` | `number?` | Local duration in seconds, synced periodically and on exit |

---

## Quick Reference — All Paths

```text
Firestore:
users/{uid}                              ← root user doc (tier, billing anchors, metadata)
    ├── usage_history/{doc_id}           ← unified archive (calendar_, weekly_, subscription_ prefixed)
    ├── subscription_events/{push-id}    ← tier audit log
    ├── sessions/{sessionId}             ← session metadata
    └── settings/app_preferences         ← single settings doc
system/admins                            ← admin email whitelist
system/monetization                      ← tiers, model access, kill switches, announcements
system/app_version                       ← application update and version controls
system/translation_config                ← Google Cloud service account credentials
legal/{documentId}                       ← terms of service, privacy policy

RTDB:
users/{uid}/
    ├── usage/totals                     ← live counters (lifetime, calendar, weekly, sub-monthly)
    ├── daily_usage/{YYYY-MM-DD}         ← per-day aggregated tracking
    ├── captions/{push-id}               ← live caption stream
    ├── current_caption                  ← ephemeral interim caption (overwritten, deleted on final)
    ├── model_usage/{push-id}            ← translation call logs
    ├── model_stats/{engine}             ← engine totals
    └── sessions/{sessionId}             ← real-time mirror of active session state
```
