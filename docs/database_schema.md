# Omni Bridge — Firebase Database Schema

## Overview

| Database | Used For |
|---|---|
| **Cloud Firestore** | Session tracking, settings, logs, model usage stats |
| **Realtime Database (RTDB)** | High-frequency live caption streaming |

---

## Firestore Structure

All user data lives under a single root path:
```
users/{uid}/
```

---

### 1. Sessions — `users/{uid}/sessions/{sessionId}`

Created on every app launch. Updated every **5 minutes** (heartbeat) and on close.

```json
{
  "sessionId": "abc123xyz",
  "startTime": "2026-03-06T07:30:00Z",
  "endTime": "2026-03-06T09:10:00Z",
  "lastPingAt": "2026-03-06T09:05:00Z",
  "durationSeconds": 5880,
  "isEnded": true,
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
| `durationSeconds` | `number` | `endTime - startTime` in seconds |
| `isEnded` | `bool` | `false` while running, `true` after close |
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
| `fontSize` | `number` | Caption font size in pts |
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

### 3. Model Usage Log — `users/{uid}/model_usage/{auto-id}`

One document written **per translation call**. Never updated after creation.

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
  "timestamp": "2026-03-06T08:15:03Z"
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
| `sessionId` | `string` | Links back to the session document |

---

### 4. Model Stats (Totals) — `users/{uid}/model_stats/{engine}`

One document **per engine**, updated atomically on every translation. Use this to answer *"how much has this user used each engine?"*

```json
// users/{uid}/model_stats/riva
{
  "engine": "riva",
  "total_calls": 1482,
  "total_tokens": 0,
  "total_latency_ms": 622440,
  "total_input_chars": 128940,
  "total_output_chars": 139200,
  "last_used": "2026-03-06T09:09:55Z"
}

// users/{uid}/model_stats/llama
{
  "engine": "llama",
  "total_calls": 34,
  "total_tokens": 41200,
  "total_latency_ms": 306000,
  "total_input_chars": 2890,
  "total_output_chars": 3100,
  "last_used": "2026-03-05T14:22:10Z"
}

// users/{uid}/model_stats/google
{
  "engine": "google",
  "total_calls": 210,
  "total_tokens": 0,
  "total_latency_ms": 89040,
  "total_input_chars": 18200,
  "total_output_chars": 19500,
  "last_used": "2026-03-06T07:55:30Z"
}

// users/{uid}/model_stats/mymemory
{
  "engine": "mymemory",
  "total_calls": 45,
  "total_tokens": 0,
  "total_latency_ms": 32000,
  "total_input_chars": 4500,
  "total_output_chars": 4550,
  "last_used": "2026-03-07T10:30:00Z"
}

// users/{uid}/model_stats/whisper
{
  "engine": "whisper",
  "total_calls": 120,
  "total_tokens": 0,
  "total_latency_ms": 96000,
  "total_input_chars": 12000,
  "total_output_chars": 0,
  "last_used": "2026-03-07T11:00:00Z"
}
```

> All counters use **atomic `FieldValue.increment()`** — safe for concurrent writes.

---

### 5. Event Logs — `users/{uid}/logs/{auto-id}`

General lifecycle events (app open, settings changed, engine switched, etc.).

```json
{
  "event": "settings_saved",
  "data": {
    "translationModel": "llama",
    "transcriptionModel": "google",
    "targetLang": "fr"
  },
  "timestamp": "2026-03-06T08:03:11Z",
  "sessionId": "abc123xyz"
}
```

---

### 6. Error Logs — `users/{uid}/error_logs/{auto-id}`

Exceptions caught at runtime. Filtered — noisy widget lifecycle errors are suppressed.

```json
{
  "message": "Failed to connect to Riva ASR server",
  "error": "SocketException: Connection refused (OS Error: 111)",
  "timestamp": "2026-03-06T08:18:44Z",
  "sessionId": "abc123xyz"
}
```

---

## Realtime Database (RTDB) Structure

Path: `users/{uid}/captions/{auto-push-id}`

Written via a REST POST on every caption event. Avoids Firestore write cost for high-frequency streaming data.

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

## Quick Reference — All Firestore Paths

```
users/
└── {uid}/
    ├── sessions/
    │   └── {sessionId}            ← one doc per app launch
    ├── settings/
    │   └── app_preferences        ← single settings doc
    ├── model_usage/
    │   └── {auto-id}              ← one doc per translation call
    ├── model_stats/
    │   ├── riva                   ← engine totals (atomic increments)
    │   ├── llama
    │   ├── google
    │   ├── mymemory
    │   └── whisper
    ├── logs/
    │   └── {auto-id}              ← general events
    └── error_logs/
        └── {auto-id}              ← runtime exceptions

RTDB:
users/{uid}/captions/{push-id}     ← live caption stream
```
