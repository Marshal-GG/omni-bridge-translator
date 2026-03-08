# Omni Bridge — Firebase Database Schema

## Overview

| Database | Used For |
|---|---|
| **Cloud Firestore** | User profile, subscription quota, session tracking, settings |
| **Realtime Database (RTDB)** | High-frequency live caption streaming, logs, model usage stats |

---

## Firestore Structure

All user data lives under a single root path:
```
users/{uid}/
```

---

### 0. User Profile & Subscription — `users/{uid}` (root document)

Created automatically on first login by `SubscriptionService`. Holds subscription tier, rolling usage counters, and monetization metadata. All char counters use atomic Firestore increments.

```json
{
  "tier": "free",
  "dailyCharsUsed": 4200,
  "dailyResetAt": "2026-03-09T00:00:00Z",
  "monthlyCharsUsed": 38000,
  "monthlyResetAt": "2026-04-01T00:00:00Z",
  "lifetimeCharsUsed": 520400,
  "subscriptionSince": "2026-02-01T00:00:00Z",
  "paymentProvider": "razorpay",
  "lastQuotaExceededAt": "2026-03-08T18:30:00Z",
  "createdAt": "2026-01-15T10:22:00Z"
}
```

| Field | Type | Notes |
|---|---|---|
| `tier` | `string` | Subscription tier: `free` \| `weekly` \| `plus` \| `pro` |
| `dailyCharsUsed` | `number` | Characters translated today (atomic increment, resets daily) |
| `dailyResetAt` | `Timestamp` | When the daily quota next resets (midnight local) |
| `monthlyCharsUsed` | `number` | Characters translated this calendar month (atomic increment) |
| `monthlyResetAt` | `Timestamp` | When the monthly counter next resets (1st of next month) |
| `lifetimeCharsUsed` | `number` | All-time cumulative chars, never resets |
| `subscriptionSince` | `Timestamp?` | When the user first converted from free to paid (set once) |
| `paymentProvider` | `string?` | Payment provider used: `"razorpay"` |
| `lastQuotaExceededAt` | `Timestamp?` | Last time the user hit their daily cap |
| `createdAt` | `Timestamp` | Server timestamp of first sign-in / document creation |

**Daily char limits by tier:**

| Tier | Limit |
|---|---|
| `free` | 10,000 chars/day |
| `weekly` | 50,000 chars/day |
| `plus` | 100,000 chars/day |
| `pro` | Unlimited |

> Payment links are handled via Razorpay (see `SubscriptionService.openCheckout`). Setting the `tier` field directly in Firestore (or via a backend function) upgrades the user.

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

> Quota-exceeded events are logged to `users/{uid}/logs/{push-id}` in RTDB (see RTDB Event Logs below) with `event: "quota_exceeded"` and a `data` object containing `tier`, `dailyLimit`, and `dailyCharsUsed`.

---

### 1. Sessions — `users/{uid}/sessions/{sessionId}`

Created on first login per device. Local storage pins the session to the hardware. Resumes on app launch unless `forceLogout` or `isEnded` is true. Updated every **5 minutes** (heartbeat) and on close.

```json
{
  "sessionId": "abc123xyz",
  "startTime": "2026-03-06T07:30:00Z",
  "endTime": "2026-03-06T09:10:00Z",
  "lastPingAt": "2026-03-06T09:05:00Z",
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
| `lastPingAt` | `Timestamp` | Updated every 5 min while app is open |
| `durationSeconds` | `number` | `endTime - startTime` in seconds (also updated on each heartbeat) |
| `isEnded` | `bool` | `false` while running, `true` after user logs out |
| `forceLogout` | `bool` | `true` triggers a remote logout on the client |
| `appReopenedAt` | `Timestamp?` | Appended when an existing session is resumed |
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

## Quick Reference — All Paths

```text
Firestore:
users/{uid}                              ← root user doc (tier, daily/monthly/lifetime quota, monetization metadata)
    ├── subscription_events/{push-id}    ← tier upgrade / downgrade audit log
    ├── sessions/{sessionId}             ← one doc per app launch
    └── settings/app_preferences         ← single settings doc

RTDB:
users/{uid}/
    ├── captions/{push-id}               ← live caption stream
    ├── logs/{push-id}                   ← general events (incl. quota_exceeded)
    ├── error_logs/{push-id}             ← runtime exceptions
    ├── model_usage/{push-id}            ← one node per translation call
    └── model_stats/{engine}             ← engine totals (atomic increments via REST)
```
