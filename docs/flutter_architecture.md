<!--
 Copyright (c) 2026 Omni Bridge. All rights reserved.
 
 Licensed under the PERSONAL STUDY & LEARNING LICENSE v1.0.
 Commercial use and public redistribution of modified versions are strictly prohibited.
 See the LICENSE file in the project root for full license terms.
-->

# Flutter App Architecture

## Overview

The Omni Bridge client is a Flutter desktop app (Windows-first) that serves as the UI and orchestration layer. It connects to a local Python WebSocket server for audio capture, ASR, and translation.

State management: **BLoC pattern** throughout.

---

## Directory Structure

```
lib/
├── core/
│   ├── blocs/          # Global BLoCs (AuthBloc)
│   ├── config/         # AppConfig (Google Client ID, secret keys), ServerConfig (host/port for Python backend)
│   ├── constants/      # Languages map, themes, strings, model_language_support.dart
│   ├── routes/         # Named route configuration
│   ├── services/       # Orchestration layer
│   │   ├── firebase/   # AuthService, SubscriptionService, TrackingService (Persistent RTDB connections)
│   │   ├── asr_text_controller.dart
│   │   ├── asr_ws_client.dart
│   │   ├── history_service.dart
│   │   ├── python_server_manager.dart
│   │   ├── translation_service.dart
│   │   ├── update_service.dart
│   │   └── whisper_service.dart
│   ├── navigation/     # GlobalNavigator (programmatic navigation via global key)
│   ├── theme/          # AppTheme (Dark Material 3, teal accent #00BCD4)
│   ├── utils/          # App lifecycle, window management helpers
│   ├── widgets/        # Shared reusable widgets
│   ├── app_initializer.dart # Firebase init, single-instance, custom URIs, deep link handlers
│   ├── window_manager.dart  # Bitsdojo window configuration, size/position
│   └── tray_manager.dart    # Windows system tray icon and menu
├── models/             # Consolidated data models
│   ├── app_settings.dart
│   ├── caption_model.dart
│   ├── history_entry.dart
│   ├── subscription_models.dart
│   └── tracking_models.dart
├── screens/
│   ├── account/        # User profile (name, email, sign-in method badge)
│   ├── about/          # Version info, update checker, links
│   ├── history/        # Caption history panel (tier-gated: Basic+ entry, Pro-only 5s column. Features a custom glassy `history_header.dart`)
│   ├── login/          # Sign-in screen (Google, Email, Guest)
│   ├── settings/       # Tab-based user preferences (Translation, Display, Input & Output)
│   ├── startup/        # Splash screen + onboarding slides
│   ├── subscription/   # Subscription screen + functional component widgets + BLoC + UpgradeSheet
│   └── translation/    # Live caption overlay + header + BLoC
├── app.dart            # MaterialApp wrapper + initial routing
└── main.dart           # Entry point (delegates to AppInitializer, configures update checker)
```

---

## Key BLoCs

| BLoC | Responsibility |
|------|---------------|
| `AuthBloc` | Firebase Auth state — Google, Email/Password, Guest |
| `SettingsBloc` | User preferences (model, language, devices, opacity, font). Computes `translationCompatibilityError` on every language/model change and emits it in state. |
| `TranslationBloc` | Active translation session, overlay visibility, language overrides |
| `SubscriptionBloc`| Manages real-time subscription state, tier details, and dynamic limits/features from Firestore |

---

## Key Services

| Service | Responsibility |
|---------|---------------|
| `AsrWsClient` | High-level wrapper around `TranslationService`. Pre-connects on construction, dispatches caption events to `AsrTextController`, routes usage stats to `TrackingService.logModelUsage()`, and feeds final captions to `HistoryService`. Soft-stop keeps the WebSocket open for fast toggle; hard-stop (dispose) tears down the connection on app shutdown. |
| `AsrTextController` | Manages the display buffer — interim vs. final text, rolling captions. Features a high-speed **Typing Catch-up Mode** that increases display velocity if the stream moves faster than the UI. |
| `TranslationService` | Low-level WebSocket client to `ws://{host}:{port}/captions`. Handles connection lifecycle, exponential backoff reconnection (2s–15s), and sends start/stop/settings/volume commands as JSON payloads. Exposes a `captions` stream of `CaptionMessage` objects. |
| `PythonServerManager` | Manages the lifecycle of the Python WebSocket server. Includes auto-restart resilience with exponential backoff if the server crashes. |
| `WhisperService` | Manages local Whisper model downloads, status, and deletion |
| `TrackingService` | Logs session stats, hardware metadata, and engine-agnostic **token usage** to RTDB. It is the **sole source of truth for incrementing usage** counters (daily, weekly, monthly, lifetime) atomically.
    - **Secure Session Storage**: Uses `flutter_secure_storage` (Windows DPAPI) to store and rotate encrypted session identifiers.
    - **Google Cloud Credentials**: `getGoogleCredentials()` fetches the service account JSON string from Firestore (`system/translation_config → googleCredentialsJson`), caches it in `flutter_secure_storage`, and returns it for the Python server's gRPC client. Supports `forceRefresh` to bypass cache on credential rotation.
    - **Sequential Interim Syncing**: For real-time features like live captions, it ensures only one `current_caption` write is in flight at a time.
    - **Usage Aggregation**: Buffers tokens locally and uses multi-path PATCH to reduce RTDB write volume by ~80%.
    - **Event & Error Logging**: `logEvent()` and `logError()` are console-only (`debugPrint`). RTDB `logs`/`error_logs` paths are not written to — operational logs belong to `server.log` on disk.
    - **Automatic Data Cleanup** (fire-and-forget on every session start): (1) RTDB `captions` older than the tier's retention window (sourced from `tiers.{tier}.features.caption_retention_days` in `system/monetization`). (2) RTDB `daily_usage` date entries older than **90 days** (fetched via `shallow=true`, deleted via multi-path PATCH). (3) Firestore `sessions` documents older than **30 days** (batch delete).
    - **Robustness**: Wraps all RTDB calls in an exponential backoff retry handler to handle transient `HandshakeException` or network jitter. |
| `SubscriptionService`| Manages real-time subscription state, aggregate token usage, and **tier-based model access control**. Polls RTDB every **N seconds** (configurable via `system/monetization → usage_poll_interval_seconds`, default 30s) — an initial fetch runs immediately on sign-in. If the poll interval changes in Firestore, the timer restarts automatically. Implements **Triple Rollover Logic** (Calendar Month, Weekly, and Subscription Cycle) — all three archive to the unified `users/{uid}/usage_history` subcollection. Reads tier configs from the `tiers` map in `system/monetization` and exposes `canUseModel()`, `allowedTranslationModels()`, `allowedTranscriptionModels()`, `isModelEnabled()`, `engineLimits()`, `engineMonthlyLimit()`, `tierFeatures`, `activeAnnouncement`, `appVersionConfig`, and `upgradePromptConfig` getters. Supports a **one-time Trial tier** via `activateTrial()`, `hasUsedTrial()`, and `_checkTrialExpiry()` — the trial auto-expires after a configurable duration. |
| `HistoryService` | Stores caption history entries (transcription + translation) for the in-app history panel. Configured per session with source/target languages. Entries are added by `AsrWsClient` on every final caption. |
| `UpdateService` | Checks for new app versions via the GitHub Releases API. Compares the remote `tag_name` against the local version from `package_info_plus`. Surfaces `UpdateStatus.available` to show an update badge in the overlay header. |
| `AuthService` | Firebase Auth + custom URL schemes for Windows Google Sign-In redirects. Exposes `currentUser` ValueNotifier and public `auth`/`firestore` getters used by UI components like `AdminPanel`. |

---

## Language Compatibility Validation

All model language support is centralised in `lib/core/constants/model_language_support.dart` — the single Dart source of truth. No screen or BLoC defines its own language sets.

| Symbol | Purpose |
|---|---|
| `rivaTranslationLangs` | Languages supported by Riva NMT (both source and target must be in set) |
| `llamaLangs` | `null` — Llama is unrestricted |
| `translationLangsFor(model)` | Returns the supported set for a model, or `null` if unrestricted |
| `translationCompatibilityError(model, source, target)` | Returns a human-readable error string if the combo is unsupported, otherwise `null` |

`SettingsBloc` calls `translationCompatibilityError()` on every `_onUpdateTempSetting` and `_onSyncTempSettings` event and stores the result in `SettingsState.translationCompatibilityError`.

**UI effects** (in `settings/`):
- **`languages_tab.dart`**: Displays a red error banner below the translation model dropdown when `translationCompatibilityError != null`.
- **`settings_footer.dart`**: Save button is disabled (`onPressed: null`) while any compatibility error is present — users cannot save an unsupported language/model combination.

---

## Application Flow

```text
Launch
 └─ AppInitializer: Firebase init, single-instance check, protocol registration
     ├─ Deep links (OAuth redirects) routed to AuthService
      ├─ New user (Logged out) → AppInitializer → Splash → Onboarding → Login
      └─ Return user (Logged in) → AppInitializer → Translation Overlay (Direct)

Settings
 └─ SettingsBloc syncs preferences to Firestore on save

Start Translation
 └─ TranslationBloc sends `start` command via AsrWsClient
     └─ Overlay window opens (bitsdojo_window)
         └─ AsrTextController buffers caption events
             └─ UI reacts via BlocBuilder

Stop Translation
 └─ TranslationBloc sends `stop` command
     └─ Overlay hides, session stats written to RTDB
```

---

## Overlay UI

- **Always-on-top, frameless, draggable** window using `bitsdojo_window` + `window_manager`
- **Transparent background** via `flutter_acrylic`
- **Keyboard Shortcuts** — handled by a `Focus` widget wrapping the overlay:

  | Key | Action |
  |-----|--------|
  | `Space` | Toggle translation running/stopped |
  | `Ctrl+M` | Toggle mini (shrink) mode |
  | `Ctrl+H` | Open history panel |
  | `Escape` | Minimize window |

- **Mini Mode** — collapsed single-line caption
- **Header** — Shows the app logo, `source → target` language badge (clickable to open Settings), an uncluttered daily usage display, and action buttons (Compress, History, Settings) with distinct accent colors to prevent visual conflicts.
- **Display Customization**:
    - **Overlay Opacity**: Adjusted via slider/percent input in Settings.
    - **Font Size**: Adjusted via slider/px input in Settings.
    - **Bold Text**: Toggle for enhanced readability.
    - **Standardized Reset**: A single "Reset to Defaults" button restores both opacity and font size.

---

## Per-Tier Feature Gating

Enforcement is centralized in `SubscriptionService` via the `canUseModel(modelId)` method, which combines two checks:
1. **Tier access**: Is the model in `tiers.{userTier}.allowed_translation_models` or `allowed_transcription_models`?
2. **Kill switch**: Is `model_overrides.{modelId}.enabled` set to `true`?

Both must pass. All config is fetched dynamically from `system/monetization → tiers` — changes take effect without an app update.

### Translation Engines (Settings → AI Translation Engine)

| Engine | Free | Pro | Enterprise |
|---|---|---|---|
| Google Translate (`google`) | yes | yes | yes |
| MyMemory (`mymemory`) | yes | yes | yes |
| Google Cloud gRPC (`google_api`) | - | yes | yes |
| NVIDIA Riva (`riva`) | - | yes | yes |
| Llama 3.1 8B (`llama`) | - | yes | yes |

Locked engines are blocked via `onBeforeChange` in the dropdown — `canUseModel()` returns `false`, preventing selection.

### Transcription Models (Settings → Transcription Method)

| Model | Free | Pro | Enterprise |
|---|---|---|---|
| Google Online (`online`) | yes | yes | yes |
| Whisper Tiny (`whisper-tiny`) | - | yes | yes |
| Whisper Base (`whisper-base`) | - | yes | yes |
| Whisper Small (`whisper-small`) | - | yes | yes |
| Whisper Medium (`whisper-medium`) | - | - | yes |
| NVIDIA Riva (`riva`) | - | - | yes |

Locked transcription options render with reduced opacity and a lock icon. The `_TranscriptionOption` widget accepts a `locked` parameter that disables tap interaction.

### Per-Engine Monthly Limits

Paid tiers have per-engine monthly token caps defined in `tiers.{tier}.engine_limits`. When a paid engine (e.g., `google_api`) exceeds its cap, the client falls back to `google` (free engine) and shows a toast notification. Exposed via `SubscriptionService.engineLimits()` and `engineMonthlyLimit(engineId)`.

### Model Kill Switches

Admins can disable any model globally via `model_overrides.{modelId}.enabled = false` in `system/monetization`. This takes effect immediately for all tiers — useful during outages or quota exhaustion on external APIs.

### UI Details

- **Glassy Aesthetics**: All main windows (Account, Settings, About, History) utilize a `WindowBorder` with a dark gradient background (`#161616` to `#0F0F0F`) and translucent cards.
- **Glassy Header**: A semi-transparent standard header used across all main screens, providing consistent window management controls (Minimize, Close, Drag) and navigation via `bitsdojo_window`.
- **Account Screen**:
    - **Plan Visualization**: Real-time progress bar shows daily token usage for capped tiers.
    - **Usage Metrics**: Displays verified **MONTHLY** and **LIFETIME** token counts in the subscription card, sourced live from RTDB.
    - **Admin Panel**: Visible to admin-listed emails only. Contains: Admin Identity management, User Plan management, and **System Config** (seed button to populate the `system/monetization` document with default tier configs, model overrides, announcements, and version control).

---

## Security Architecture

The app follows a **"Trust but Verify (via Rules)"** model, performing critical enforcement client-side while relying on Firestore Security Rules for backend integrity.

### 1. Quota Enforcement Logic
- **Polling**: `SubscriptionService` polls the `/usage/totals` and `/daily_usage` paths in RTDB at an interval sourced from `system/monetization → usage_poll_interval_seconds` (default 30s, immediate fetch on sign-in). If the interval is updated in Firestore, the timer restarts automatically. The UI (Account Screen, Overlay Header) reflects updates within one poll cycle. Note: `firebase_database` SDK listeners are not used on Windows because the Flutter Windows Pigeon bridge does not support named Firebase app instances; REST polling is the reliable alternative. Includes retry logic with exponential backoff for transient connection errors.
- **Triple Rollover Logic**: 
    - **Calendar Rollover**: On month change (detected at launch or runtime), all-time tokens for that month are archived to Firestore (`usage_history_calendar`) and the RTDB counter is reset.
    - **Weekly Rollover**: Every Monday (local), weekly tokens are archived to `usage_history_weekly` and the RTDB counter is reset.
    - **Subscription Rollover**: For paid members, usage is tracked relative to their `monthlyResetAt` date. When crossed, usage is archived to `usage_history_subscription` and the RTDB cycle counter is reset.

### 2. Multi-Engine Translation Hub
The `InferenceOrchestrator` (Python) and its client-side orchestration handle multiple engines with built-in resilience:
- **Fallback Logic**: If the primary engine (e.g., `google_api`) fails, the system automatically falls back to a free alternative (`google` free) to maintain service continuity.
- **Access Gating**: Feature access is enforced via `SubscriptionService.canUseModel(modelId)`, which combines tier-based allow lists (`tiers.{tier}.allowed_translation_models`) with global kill switches (`model_overrides.{model}.enabled`). Both checks must pass.

### 3. Google Cloud Credential Protection
Google Cloud service account credentials follow a secure pipeline:
1. **Storage**: The full service account JSON is stored as a string field (`googleCredentialsJson`) in Firestore `system/translation_config`.
2. **Access Control**: Firestore Security Rules restrict reads to admins and users whose tier includes `google_api` in `allowed_translation_models` (via the `tierAllowsModel()` rule helper).
3. **Client Caching**: `TrackingService.getGoogleCredentials()` fetches the JSON from Firestore, caches it in `flutter_secure_storage` (Windows DPAPI), and supports `forceRefresh` to bypass cache on credential rotation.
4. **Transport**: The JSON string is sent to the Python server via WebSocket (`google_credentials_json` key).
5. **Server Usage**: `GoogleCloudModel` parses the JSON and initializes a gRPC `TranslationServiceClient` via `Credentials.from_service_account_info()`. Error logging is sanitized — only `type(e).__name__` is logged, never the credential content.

### 4. Secure Local Storage
The application uses `flutter_secure_storage` as its primary mechanism for persistent, encrypted local storage. This is used for sensitive data such as:
- **Session Identifiers**: Stored with environment-specific prefixes (`debug_` or `release_`) to ensure complete session isolation between builds.
- **Google Cloud Credentials**: Cached service account JSON string, keyed with environment prefix.

### Legacy Cleanup
To maintain a "zero-legacy" codebase, all usage of the insecure `shared_preferences` package has been removed. Testing data and legacy keys (like `has_seen_onboarding`) are no longer managed by the application code. Instead, developers can use the [clear_app_data.ps1](../scripts/clear_app_data.ps1) script to purge this information from the Windows Registry when a fresh state is required.

### 5. Field-Level Protection
Firestore rules block users from modifying their own `tier`, `subscriptionSince`, or `paymentProvider`. This ensures that even if the client is compromised, the user cannot artificially upgrade their account or manipulate billing metadata.

---

## Remote Configuration (`system/monetization`)

`SubscriptionService` maintains a real-time Firestore listener on `system/monetization`. All behavioural and pricing parameters are read from this document, allowing changes to take effect without a client update.

### Top-Level Fields

| Field | Type | Purpose |
|---|---|---|
| `order` | `List<String>` | Tier IDs in rank order (index 0 = free/default) |
| `popular` | `String` | Tier ID highlighted as "popular" in the UI |
| `usage_poll_interval_seconds` | `int` | RTDB usage polling interval in seconds (default: `30`) |

### `tiers` — Per-Tier Configuration

Each tier (e.g., `free`, `pro`, `enterprise`) is a nested map under `tiers`:

| Field | Type | Purpose |
|---|---|---|
| `tiers.{id}.name` | `String` | Display name |
| `tiers.{id}.price` | `String` | Display price string (e.g., `"₹399/month"`) |
| `tiers.{id}.description` | `String` | Short tier description |
| `tiers.{id}.display_features` | `List<String>` | Feature bullet points for the subscription UI |
| `tiers.{id}.allowed_transcription_models` | `List<String>` | Model IDs this tier can use for ASR (e.g., `["google", "riva", "whisper"]`) |
| `tiers.{id}.allowed_translation_models` | `List<String>` | Model IDs this tier can use for translation (e.g., `["google", "mymemory", "google_api", "riva", "llama"]`) |
| `tiers.{id}.features` | `Map` | Structured feature flags (e.g., `caption_retention_days`, `history_access`, `context_refresh`) |
| `tiers.{id}.quotas` | `Map` | Token limits: `daily_tokens`, `monthly_tokens` (`-1` = unlimited) |
| `tiers.{id}.engine_limits` | `Map` | Per-engine monthly token caps (e.g., `{"google_api": 100000}`). Engines not listed follow overall quotas only. |
| `tiers.{id}.rate_limits` | `Map` | Rate limiting: `requests_per_minute`, `concurrent_sessions` |

### `model_overrides` — Global Kill Switches

| Field | Type | Purpose |
|---|---|---|
| `model_overrides.{modelId}.enabled` | `bool` | `false` disables the model globally for all tiers (useful during outages) |
| `model_overrides.{modelId}.reason` | `String?` | Optional human-readable reason for disabling |

### Other Top-Level Maps

| Field | Type | Purpose |
|---|---|---|
| `announcements` | `Map?` | Active announcement banner config (`message`, `type`, `dismissible`, `action_url`) |
| `upgrade_prompts` | `Map?` | Dynamic upgrade prompt messaging per trigger |
| `app_version` | `Map?` | Version control: `minimum_version`, `latest_version`, `update_url`, `force_update` |
| `payment_links` | `Map?` | Razorpay payment URLs keyed by tier ID (e.g., `{"pro": "https://...", "enterprise": "https://..."}`) |

> **Legacy Compatibility**: `SubscriptionService` reads from the `tiers` structure when available. If `tiers` is absent, it falls back to the legacy flat structure (`limits`, `names`, `prices`, `features`, `requirements`) for backward compatibility.

---

## Data Retention

All cleanup runs **fire-and-forget on every session start** (`TrackingService.startSession`). No Cloud Functions or cron jobs are required.

### RTDB

| Path | Retention | Mechanism |
|---|---|---|
| `captions` | Tier-based (from `tiers.{tier}.features.caption_retention_days`; default 30d) | Client-side delete via multi-path PATCH with `null` values |
| `daily_usage/{YYYY-MM-DD}` | 90 days | Keys fetched with `shallow=true`, date-parsed, old entries deleted via multi-path PATCH |
| `sessions/{sessionId}` | Transient — not cleaned (small, bounded by session count) | N/A |
| `current_caption` | Ephemeral — deleted automatically on every final caption | `DELETE` request in `syncLiveCaption` |
| `usage/totals` | Forever | Aggregate counters, never grows large |
| `model_stats` | Forever | Aggregate counters, never grows large |
| `logs` | **Not written** — removed | Was RTDB, now console-only (`debugPrint`) |
| `error_logs` | **Not written** — removed | Was RTDB, now console-only (`debugPrint`) |

### Firestore

| Collection | Retention | Mechanism |
|---|---|---|
| `users/{uid}/sessions` | 30 days | Batch delete on session start (queries `startTime < now - 30d`) |
| `users/{uid}/usage_history` | Forever (calendar/subscription) · 3 months for weekly (TTL pending) | Unified archive collection. Doc IDs are prefixed: `calendar_YYYY_MM`, `weekly_YYYY_MM_DD`, `subscription_YYYY-MM-DD__YYYY-MM-DD`. Each doc has a `period_type` field (`calendar`, `weekly`, `subscription`) for filtering. |
| `users/{uid}/settings` | Forever | Single document, always overwritten |
| `users/{uid}/subscription_events` | Forever | Billing audit trail |
| `users/{uid}` | Forever | Account data |
| `system/*` | Forever | Config and legal documents |
