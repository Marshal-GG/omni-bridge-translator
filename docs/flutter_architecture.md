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
│   ├── constants/      # Languages map, themes, strings
│   ├── routes/         # Named route configuration
│   ├── services/       # TranslationService, AsrWsClient, AsrTextController, TrackingService, AuthService, SubscriptionService
│   ├── utils/          # App lifecycle, window management helpers
│   ├── widgets/        # Shared reusable widgets
│   └── app_initializer.dart # Firebase init, single-instance, custom URIs, deep link handlers
├── models/             # Settings model, user model, HistoryEntry
├── screens/
│   ├── account/        # User profile (name, email, sign-in method badge)
│   ├── about/          # Version info, update checker, links
│   ├── history/        # Caption history panel (tier-gated: Weekly+ entry, Pro-only 5s column. Features a custom glassy `history_header.dart`)
│   ├── login/          # Sign-in screen (Google, Email, Guest)
│   ├── settings/       # Audio devices, languages, model selection (with tier-lock badges)
│   ├── startup/        # Splash screen + onboarding slides
│   ├── subscription/   # Subscription screen + UpgradeSheet bottom sheet
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

---

## Key Services

| Service | Responsibility |
|---------|---------------|
| `AsrWsClient` | WebSocket client to Python server (`ws://127.0.0.1:8765`). Receives JSON caption events. |
| `AsrTextController` | Manages the display buffer — interim vs. final text, rolling captions |
| `TranslationService` | Sends start/stop/settings commands to the WebSocket server |
| `TrackingService` | Logs session stats and translation metadata to Firestore / RTDB |
| `SubscriptionService` | Manages subscription tier, daily/monthly/lifetime quota counters, tier-change event audit, quota-exceeded logging |
| `AuthService` | Firebase Auth + custom URL schemes (`omni-bridge://` and reversed iOS Client ID) for Windows Google Sign-In redirects |

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
- **Header** — shows `source → target` language badge (clickable to open Settings) and colorized TealAccent icons.
- **Display Customization**:
    - **Overlay Opacity**: Adjusted via slider/percent input in Settings.
    - **Font Size**: Adjusted via slider/px input in Settings.
    - **Bold Text**: Toggle for enhanced readability.
    - **Standardized Reset**: A single "Reset to Defaults" button restores both opacity and font size.

---

## Per-Tier Feature Gating

Feature access is enforced in the UI layer by reading `SubscriptionService.instance.currentStatus?.tier`. The overlay always sees the latest tier via a live Firestore stream.

### Translation Engines (Settings → AI Translation Engine)

| Engine | Minimum Tier |
|---|---|
| Google Translate | Free |
| MyMemory | Free |
| NVIDIA Riva | Weekly+ |
| Llama 3.1 8B | Weekly+ |

Locked engines are rendered dimmed with an orange `🔒 Weekly+` badge. Tapping a locked option opens `UpgradeSheet`.

### Whisper Offline Model Sizes (Settings → Transcription Method)

| Size | Minimum Tier |
|---|---|
| Tiny / Base | Free |
| Small (~460 MB) | Weekly+ |
| Medium (~1.5 GB) | Plus+ |

Locked sizes are disabled in the `DropdownButton` and show a lock badge. Selecting them opens `UpgradeSheet`.

### History Panel (`/history-panel`)

| Tier | Access |
|---|---|
| Free | Blocked — Custom `TierGateView` shown with "Upgrade to access history" message + automatic `UpgradeSheet` trigger. |
| Weekly | Live transcripts (in-memory, session-scoped) |
| Plus | Live transcripts filtered to last 72 hours |
| Pro | Live transcripts + **5-second Context Refresh column** |

The history button in the overlay header and locked engine selections now route all users to `/history-panel`. For Free-tier users, the panel automatically displays the `UpgradeSheet` on entry, providing a contextual upgrade prompt. The panel uses a standardized glassy header (`buildHistoryHeader`) with window controls and a premium dark gradient background.

### Feature-Specific UI Patterns

- **Glassy Aesthetics**: All main windows (Account, Settings, About, History) utilize a `WindowBorder` with a dark gradient background (`#161616` to `#0F0F0F`) and translucent cards.
- **Standardized Headers**: Custom internal headers (e.g., `buildAccountHeader`, `buildHistoryHeader`) replace standard AppBars to provide consistent window management controls (Minimize, Close, Drag) and navigation.
- **Version Tracking**: Every major screen displays a consistent "Version Chip" (e.g., `OMNI BRIDGE V1.0.0`) in the footer or designated areas for easy reference.
- **Account Screen**:
    - **Plan Visualization**: Real-time progress bar shows daily character usage for capped tiers.
    - **Planned Features**: A dedicated "Todo" section informs users of upcoming capabilities (Audio TTS, PDF support, etc.).
