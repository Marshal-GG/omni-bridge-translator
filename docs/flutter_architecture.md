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
│   ├── services/       # TranslationService, AsrWsClient, AsrTextController, TrackingService, AuthService
│   ├── utils/          # App lifecycle, window management helpers
│   ├── widgets/        # Shared reusable widgets
│   └── app_initializer.dart # Firebase init, single-instance, custom URIs, deep link handlers
├── models/             # Settings model, user model
├── screens/
│   ├── account/        # User profile (name, email, sign-in method badge)
│   ├── about/          # Version info, update checker, links
│   ├── history/        # Caption history panel
│   ├── login/          # Sign-in screen (Google, Email, Guest)
│   ├── settings/       # Audio devices, languages, models tabs
│   ├── startup/        # Splash screen + onboarding slides
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
- **Header** — shows `source → target` language badge (clickable to open Settings)
- **Opacity + font size** controlled from Settings
