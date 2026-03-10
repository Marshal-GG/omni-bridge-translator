<!--
 Copyright (c) 2026 Omni Bridge. All rights reserved.
 
 Licensed under the PERSONAL STUDY & LEARNING LICENSE v1.0.
 Commercial use and public redistribution of modified versions are strictly prohibited.
 See the LICENSE file in the project root for full license terms.
-->

# Omni Bridge — Firebase Database Schema

## Overview

| Database | Used For |
|---|---|
| **Cloud Firestore** | User profile, subscription quota, session tracking, settings, legal docs, admin lists |
| **Realtime Database (RTDB)** | High-frequency live caption streaming, logs, model usage stats |

---

## Firestore Structure

There are three main root paths in Firestore:
```
users/{uid}/
system/admins
system/monetization
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
 
---
 
### Monetization Configuration — `system/monetization`
 
A singleton document used to manage dynamic pricing, tier names, character limits, and feature gates.
 
```json
{
  "names": {
    "free": "Free",
    "basic": "Basic",
    "plus": "Plus",
    "pro": "Pro"
  },
  "prices": {
    "basic": "₹49",
    "plus": "₹149",
    "pro": "₹399"
  },
  "descriptions": {
    "free": "For occasional use",
    "basic": "For short trips",
    "plus": "For active learners",
    "pro": "For power users"
  },
  "limits": {
    "free": 10000,
    "basic": 50000,
    "plus": 100000,
    "pro": 0
  },
  "features": {
    "free": [
      "10,000 Chars Daily",
      "Standard Models",
      "Basic Live Captions"
    ],
    "basic": [
      "50,000 Chars Daily",
      "Same-Session History",
      "High-Speed Translation",
      "Standard Live Captions"
    ],
    "plus": [
      "100,000 Chars Daily",
      "3-Day History Access",
      "Advanced Live Captions",
      "Priority Support",
      "Offline Model Support"
    ],
    "pro": [
      "Unlimited Daily Chars",
      "Intelligent Context Refresh (5s)",
      "Auto-Correct Live Captions",
      "Unlimited History Access",
      "Premium Translation Engines",
      "24/7 Priority Support"
    ]
  },
  "requirements": {
    "engines": {
      "riva": "basic",
      "llama": "plus"
    },
    "whisper": {
      "base": "free",
      "small": "basic",
      "medium": "plus",
      "large-v3": "pro"
    }
  },
  "order": ["free", "basic", "plus", "pro"],
  "popular": "plus",
  "payment_links": {
    "basic": "https://razorpay.me/@omnibridgemonetization",
    "plus": "https://razorpay.me/@omnibridgeplus",
    "pro": "https://razorpay.me/@omnibridgepro"
  }
}
```
 
| Field | Type | Notes |
|---|---|---|
| `names` | `map` | Display names for each tier |
| `prices` | `map` | Price strings shown in the UI |
| `descriptions` | `map` | Short description text for each plan |
| `limits` | `map` | Daily character limits (0 = unlimited) |
| `features` | `map` | String arrays of features for each plan |
| `requirements` | `map` | Minimum tier required for specific engines or features |
| `order` | `array` | Determines the correct visual order to render plans |
| `popular` | `string` | The ID of the tier to highlight as "Popular" |
| `payment_links` | `map` | Direct checkout links for each paid tier |

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

Created automatically on first login by `SubscriptionService`. Holds subscription tier, rolling usage counters, and monetization metadata. All char counters use atomic Firestore increments.

```json
{
  "tier": "free",
  "dailyResetAt": "2026-03-09T00:00:00Z",
  "monthlyCharsUsed": 38000,
  "monthlyResetAt": "2026-04-01T00:00:00Z",
  "lifetimeCharsUsed": 520400,
  "subscriptionSince": "2026-02-01T00:00:00Z",
  "paymentProvider": "razorpay",
  "lastQuotaExceededAt": "2026-03-08T18:30:00Z",
  "forceLogout": false,
  "createdAt": "2026-01-15T10:22:00Z"
}
```

| Field | Type | Notes |
|---|---|---|
| `tier` | `string` | Subscription tier: `free` \| `basic` \| `plus` \| `pro` |
| `dailyResetAt` | `Timestamp` | When the daily quota next resets (midnight local). Daily usage is tracked in RTDB. |
| `monthlyCharsUsed` | `number` | Characters translated this calendar month (atomic increment) |
| `monthlyResetAt` | `Timestamp` | When the monthly counter next resets (1st of next month) |
| `lifetimeCharsUsed` | `number` | All-time cumulative chars, never resets |
| `subscriptionSince` | `Timestamp?` | When the user first converted from free to paid (set once) |
| `paymentProvider` | `string?` | Payment provider used: `"razorpay"` |
| `lastQuotaExceededAt` | `Timestamp?` | Last time the user hit their daily cap |
| `forceLogout` | `bool` | Set to `true` to force logout all sessions for this user |
| `createdAt` | `Timestamp` | Server timestamp of first sign-in / document creation |

**Daily token limits by tier (Defaults, dynamically updated via `system/monetization`):**
 
| Tier | Limit |
|---|---|
| `free` | 10,000 tokens/day |
| `basic` | 50,000 tokens/day |
| `plus` | 100,000 tokens/day |
| `pro` | Unlimited |
 
> Quota limits, pricing, and feature gate requirements are fetched dynamically from `system/monetization`. Payment links are handled via Razorpay (see `SubscriptionService.openCheckout`). Setting the `tier` field directly in Firestore (or via a backend function) upgrades the user.

---

### 0a. Subscription Events — `users/{uid}/subscription_events/{push-id}`

Written by `SubscriptionService._logSubscriptionEvent()` whenever the user's tier changes. Provides a full audit trail of upgrades and downgrades.

```json
{
  "event": "upgraded",
  "from": "free",
  "to": "plus",
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

> Quota-exceeded events are logged to `users/{uid}/logs/{push-id}` in RTDB (see RTDB Event Logs below) with `event: "quota_exceeded"` and a `data` object containing `tier` and `dailyLimit`.

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
| `forceLogout` | `bool` | `true` triggers a remote logout for this specific session |
| `device.*` | `map` | OS + network snapshot at session start |

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

Written via RTDB REST POSTs. Avoids Firestore write cost for high-frequency streaming data and logs.

### 1. Model Usage Log — `users/{uid}/model_usage/{push-id}`

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

> For Llama / Google, `prompt_tokens`, `completion_tokens` and `total_tokens` are populated.

**Engines:** `riva` | `llama` | `google` | `mymemory` | `whisper`

| Field | Type | Notes |
|---|---|---|
| `engine` | `string` | Which backend handled this translation |
| `model` | `string` | Exact model variant used |
| `latency_ms` | `number` | Round-trip time from send → receive |
| `total_tokens` | `number` | LLM token consumption (0 for Riva) |
| `input_chars` | `number` | Character count of source text |
| `output_chars` | `number` | Character count of translated text |
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
  "total_input_chars": 128940,
  "total_output_chars": 139200,
  "last_used": 1741244995000
}

// users/{uid}/model_stats/llama
{
  "engine": "llama",
  "total_calls": 34,
  "total_tokens": 41200,
  "total_latency_ms": 306000,
  "total_input_chars": 2890,
  "total_output_chars": 3100,
  "last_used": 1741243330000
}

// users/{uid}/model_stats/google
{
  "engine": "google",
  "total_calls": 210,
  "total_tokens": 0,
  "total_latency_ms": 89040,
  "total_input_chars": 18200,
  "total_output_chars": 19500,
  "last_used": 1741240530000
}

// users/{uid}/model_stats/mymemory
{
  "engine": "mymemory",
  "total_calls": 45,
  "total_tokens": 0,
  "total_latency_ms": 32000,
  "total_input_chars": 4500,
  "total_output_chars": 4550,
  "last_used": 1741249800000
}

// users/{uid}/model_stats/whisper
{
  "engine": "whisper",
  "total_calls": 120,
  "total_tokens": 0,
  "total_latency_ms": 96000,
  "total_input_chars": 12000,
  "total_output_chars": 0,
  "last_used": 1741251600000
}
```

> All counters use **atomic increments** via RTDB REST ServerValue syntax (`{".sv": {"increment": amount}}`) — safe for concurrent writes.

---

### 3. Event Logs — `users/{uid}/logs/{push-id}`

General lifecycle events (app open, settings changed, engine switched, etc.).

```json
{
  "event": "settings_saved",
  "data": {
    "translationModel": "llama",
    "transcriptionModel": "google",
    "targetLang": "fr"
  },
  "timestamp": 1741238591000,
  "sessionId": "abc123xyz"
}
```

---

### 4. Error Logs — `users/{uid}/error_logs/{push-id}`

Exceptions caught at runtime. Filtered — noisy widget lifecycle errors are suppressed.

```json
{
  "message": "Failed to connect to Riva ASR server",
  "error": "SocketException: Connection refused (OS Error: 111)",
  "timestamp": 1741239524000,
  "sessionId": "abc123xyz"
}
```

---

### 5. Live Captions — `users/{uid}/captions/{auto-push-id}`

```json
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

### 6. Daily Usage (Telemetry) — `users/{uid}/daily_usage/{YYYY-MM-DD}`

Tracks aggregated telemetry for a specific day. Useful for real-time dashboards answering "How much quota has been consumed today across engines?". Updated atomically on translation completion.

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
| `tokens` | `number` | Total tokens consumed for all models today (incrementally updated) |
| `models/{engine}/tokens` | `number` | Tokens mapped to a specific engine today |
| `models/{engine}/calls` | `number` | Number of successful translations for the engine today |
| `errors/{engine}/failed_calls` | `number` | Non-fatal translation API errors grouped by engine |

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
users/{uid}                              ← root user doc (tier, daily/monthly/lifetime quota, monetization metadata)
    ├── subscription_events/{push-id}    ← tier upgrade / downgrade audit log
    ├── sessions/{sessionId}             ← one doc per app launch
    └── settings/app_preferences         ← single settings doc

system/admins                            ← list of authorized admin emails
system/monetization                      ← dynamic pricing, limits, and feature requirements
legal/{documentId}                       ← markdown content for app policies (terms, privacy, license)

RTDB:
users/{uid}/
    ├── captions/{push-id}               ← live caption stream
    ├── logs/{push-id}                   ← general events (incl. quota_exceeded)
    ├── error_logs/{push-id}             ← runtime exceptions
    ├── model_usage/{push-id}            ← one node per translation call
    ├── model_stats/{engine}             ← engine totals (atomic increments via REST)
    ├── daily_usage/{YYYY-MM-DD}         ← per-day aggregated tracking (tokens, calls, errors)
    └── sessions/{sessionId}             ← real-time mirror of active session state
```
