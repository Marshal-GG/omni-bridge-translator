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
│   ├── config/         # AppConfig (Google Client ID, secret keys)
│   ├── constants/      # Languages map, themes, strings
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
│   ├── utils/          # App lifecycle, window management helpers
│   ├── widgets/        # Shared reusable widgets
│   └── app_initializer.dart # Firebase init, single-instance, custom URIs, deep link handlers
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
| `SettingsBloc` | User preferences (model, language, devices, opacity, font) |
| `TranslationBloc` | Active translation session, overlay visibility, language overrides |
| `SubscriptionBloc`| Manages real-time subscription state, tier details, and dynamic limits/features from Firestore |

---

## Key Services

| Service | Responsibility |
|---------|---------------|
| `AsrWsClient` | WebSocket client to Python server (`ws://127.0.0.1:8765`). Receives JSON caption events and synchronizes remote server errors to `TrackingService`. |
| `AsrTextController` | Manages the display buffer — interim vs. final text, rolling captions. Features a high-speed **Typing Catch-up Mode** that increases display velocity if the stream moves faster than the UI. |
| `TranslationService` | Sends start/stop/settings commands to the WebSocket server |
| `PythonServerManager` | Manages the lifecycle of the Python WebSocket server. Includes auto-restart resilience with exponential backoff if the server crashes. |
| `WhisperService` | Manages local Whisper model downloads, status, and deletion |
| `TrackingService` | Logs session stats, hardware metadata, and engine-agnostic **token usage** to RTDB. It is the **sole source of truth for incrementing usage** counters (daily, weekly, monthly, lifetime) atomically. 
    - **Sequential Interim Syncing**: For real-time features like live captions, it ensures only one \"current_caption\" write is in flight at a time. This prevents race conditions and ensures chronological consistency in high-frequency data streams.
    - **Usage Aggregation**: Buffers tokens locally and uses multi-path PATCH to reduce RTDB write volume by ~80%.
    - **Robustness**: Wraps all RTDB calls in an exponential backoff retry handler to handle transient `HandshakeException` or network jitter. |
| `SubscriptionService`| Manages real-time subscription state and aggregate token usage. Polled every 3 seconds from RTDB (daily, weekly, monthly, lifetime). Implements **Triple Rollover Logic** (Calendar Month, Weekly, and Subscription Cycle) for archiving usage data to Firestore. |
| `AuthService` | Firebase Auth + custom URL schemes for Windows Google Sign-In redirects. |

---

## Application Flow

```text
Launch
 └─ AppInitializer: Firebase init, single-instance check, protocol registration
     ├─ Deep links (OAuth redirects) routed to AuthService
     ├─ New user  → Splash → Onboarding → Login
     ├─ Logged out → Splash → Login
     └─ Logged in  → Translation Overlay (direct)

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
- **Mini Mode** — collapsed single-line caption
- **Header** — Shows the app logo, `source → target` language badge (clickable to open Settings), an uncluttered daily usage display, and action buttons (Compress, History, Settings) with distinct accent colors to prevent visual conflicts.
- **Display Customization**:
    - **Overlay Opacity**: Adjusted via slider/percent input in Settings.
    - **Font Size**: Adjusted via slider/px input in Settings.
    - **Bold Text**: Toggle for enhanced readability.
    - **Standardized Reset**: A single "Reset to Defaults" button restores both opacity and font size.

---

## Per-Tier Feature Gating

Enforcement is centralized in `SubscriptionService` via the `getRequirement(featureKey)` method. These requirements (e.g., `llama: plus`) are fetched dynamically from Firestore, allowing remote configuration of feature access.

### Translation Engines (Settings → AI Translation Engine)

| Engine | Requirement Key | Default Tier |
|---|---|---|
| Google Translate | `google` | Free |
| Google Cloud | `google_api` | Free |
| MyMemory | `mymemory` | Free |
| NVIDIA Riva | `riva` | Basic+ |
| Llama 3.1 8B | `llama` | Plus+ |

Locked engines are rendered dimmed with an orange `🔒 Basic+` badge. Tapped locked options trigger descriptive tooltips or `UpgradeSheet`.

### Whisper Offline Model Sizes (Settings → Transcription Method)

| Size | Requirement Key | Default Tier |
|---|---|---|
| base | `whisper-base` | Free |
| base.en | `whisper-base.en` | Free |
| small | `whisper-small` | Basic+ |
| medium | `whisper-medium` | Plus+ |
| large-v3 | `whisper-large-v3`| Pro |

Locked sizes are disabled in the `DropdownButton` and show a lock badge. Selecting them opens `UpgradeSheet`.

### History Panel (`/history-panel`)

| Tier | Access |
|---|---|
| Free | Blocked — Custom `TierGateView` shown with "Upgrade to access history" message + automatic `UpgradeSheet` trigger. |
| Basic | Live transcripts (in-memory, session-scoped) |
| Plus | Live transcripts filtered to last 72 hours |
| Pro | Live transcripts + **5-second Context Refresh column** |

The history button in the overlay header and locked engine selections now route all users to `/history-panel`. For Free-tier users, the panel automatically displays the `UpgradeSheet` on entry, providing a contextual upgrade prompt. The panel uses a standardized glassy header (`buildHistoryHeader`) with window controls and a premium dark gradient background.

- **Glassy Aesthetics**: All main windows (Account, Settings, About, History) utilize a `WindowBorder` with a dark gradient background (`#161616` to `#0F0F0F`) and translucent cards.
- **Glassy Header**: A semi-transparent standard header used across all main screens, providing consistent window management controls (Minimize, Close, Drag) and navigation via `bitsdojo_window`.
- **Standardized Window Controls**: Custom minimize/close buttons for a consistent Windows native feel across all screens.
- **Version Tracking**: Every major screen displays a consistent "Version Chip" (e.g., `OMNI BRIDGE V1.0.0`) in the footer or designated areas for easy reference.
- **Account Screen**:
    - **Plan Visualization**: Real-time progress bar shows daily token usage for capped tiers.
    - **Usage Metrics**: Displays verified **MONTHLY** and **LIFETIME** token counts in the subscription card, sourced live from RTDB.
    - **Planned Features**: A dedicated "Todo" section informs users of upcoming capabilities (Audio TTS, PDF support, etc.).

---

## Security Architecture

The app follows a **"Trust but Verify (via Rules)"** model, performing critical enforcement client-side while relying on Firestore Security Rules for backend integrity.

### 1. Quota Enforcement Logic
- **Real-Time Polling**: `SubscriptionService` polls the `/usage/totals` and `/daily_usage` paths in RTDB every 3 seconds. The UI (Account Screen, Overlay Header) reacts immediately to these updates.
- **Triple Rollover Logic**: 
    - **Calendar Rollover**: On month change (detected at launch or runtime), all-time tokens for that month are archived to Firestore (`usage_history_calendar`) and the RTDB counter is reset.
    - **Weekly Rollover**: Every Monday (local), weekly tokens are archived to `usage_history_weekly` and the RTDB counter is reset.
    - **Subscription Rollover**: For paid members, usage is tracked relative to their `monthlyResetAt` date. When crossed, usage is archived to `usage_history_subscription` and the RTDB cycle counter is reset.

### 2. Multi-Engine Translation Hub
The `NimApiClient` (Python) and its client-side orchestration handle multiple engines with built-in resilience:
- **Fallback Logic**: If the primary engine (e.g., `google_api`) fails, the system automatically falls back to a free alternative (`google` free) to maintain service continuity.
- **Access Gating**: Feature access is enforced via `SubscriptionService.tierHasAccess()`, which checks against dynamic requirements from `system/monetization`.

### 3. Remote Session Termination (`forceLogout`)
Two monitoring streams in `TrackingService` enable remote kicks without Cloud Functions:
1. **Global Hook**: Listens to `users/{uid}/forceLogout`.
2. **Session Hook**: Listens to `users/{uid}/sessions/{sessionId}/forceLogout`.

When a kick is triggered, the client resets the flag to `false` (permitted by transition-based security rules) and signs out the user locally.

### 3. Field-Level Protection
Firestore rules block users from modifying their own `tier`, `subscriptionSince`, or `paymentProvider`. This ensures that even if the client is compromised, the user cannot artificially upgrade their account or manipulate billing metadata.
