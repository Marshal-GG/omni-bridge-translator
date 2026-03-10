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
│   ├── settings/       # Audio devices, languages, model selection (with tier-lock badges)
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
| `AsrWsClient` | WebSocket client to Python server (`ws://127.0.0.1:8765`). Receives JSON caption events. |
| `AsrTextController` | Manages the display buffer — interim vs. final text, rolling captions |
| `TranslationService` | Sends start/stop/settings commands to the WebSocket server |
| `PythonServerManager` | Manages the lifecycle of the local Python WebSocket server (start/stop/restart) |
| `WhisperService` | Manages local Whisper model downloads, status, and deletion |
| `TrackingService` | Logs session stats, hardware metadata, and heartbeat to RTDB (Uses persistent `http.Client`) |
| `SubscriptionService`| Manages dynamic plans, limits, and character usage from Firestore/RTDB (Uses persistent `http.Client`) |
| `AuthService` | Firebase Auth + custom URL schemes for Windows Google Sign-In redirects |

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
| MyMemory | `mymemory` | Free |
| NVIDIA Riva | `riva` | Basic+ |
| Llama 3.1 8B | `llama` | Plus+ |

Locked engines are rendered dimmed with an orange `🔒 Basic+` badge. Tapping a locked option opens `UpgradeSheet`.

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

### Feature-Specific UI Patterns

- **Glassy Aesthetics**: All main windows (Account, Settings, About, History) utilize a `WindowBorder` with a dark gradient background (`#161616` to `#0F0F0F`) and translucent cards.
- **Standardized Headers**: Custom internal headers (e.g., `buildAccountHeader`, `buildHistoryHeader`) replace standard AppBars to provide consistent window management controls (Minimize, Close, Drag) and navigation.
- **Version Tracking**: Every major screen displays a consistent "Version Chip" (e.g., `OMNI BRIDGE V1.0.0`) in the footer or designated areas for easy reference.
- **Account Screen**:
    - **Plan Visualization**: Real-time progress bar shows daily token usage for capped tiers.
    - **Planned Features**: A dedicated "Todo" section informs users of upcoming capabilities (Audio TTS, PDF support, etc.).
