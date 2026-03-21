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
Architecture: **Clean Architecture (Layered)** with **Repository Pattern** and **Dependency Injection** using `get_it`.

> [!NOTE]
> The application is currently transitioning from a **Horizontal Layered** architecture to a **Feature-Driven (Vertical Slice)** architecture. For the new roadmap and component boundaries, refer to **`docs/17_deep_restructure_plan.md`**.

---

## Directory Structure (3-Layer Architecture)

The project follows a clean, modular 3-layer architecture to ensure scalability and maintainability.

```
lib/
├── core/                        # Shared Framework & Infrastructure
│   ├── config/                  # AppConfig, ServerConfig
│   ├── constants/               # Strings, Colors, Model Language Support
│   ├── di/                      # Dependency Injection (injection.dart)
│   ├── error/                   # Failure classes
│   ├── navigation/              # GlobalNavigator
│   ├── platform/                # Platform-specific logic (Window, Tray, AppInitializer)
│   ├── routes/                  # Router + RoutesConfig (Barrel exports)
│   ├── theme/                   # AppTheme (Dark Material 3)
│   └── utils/                   # Shared helpers & Extensions
│
├── features/                    # Modularized Features Domain
│   ├── auth/                    # Authentication (Domain, Data, Presentation)
│   └── translation/             # Translation & ASR (Domain, Data, Presentation)
│
├── domain/                      # Domain Layer (Business Logic & Entities)
│   ├── entities/                # [Future] Domain entities
│   └── repositories/            # Repository Interfaces (ITranslationRepository, etc.)
│
├── data/                        # Data Layer (Implementation)
│   ├── models/                  # AppSettings, CaptionModel, etc.
│   ├── repositories/            # Concrete Repository Implementations
│   └── services/                # Specialized domain services
│       ├── firebase/            # TrackingService, SubscriptionService
│       ├── server/              # AsrWsClient, PythonServerManager, UpdateService
│       ├── system/              # HistoryService, AppLifecycle
│       └── translation/         # TranslationService, WhisperService
│
└── presentation/                # UI Layer (Screens & Blocs)
    ├── blocs/                   # Feature BLoCs (Auth, Settings, Translation, etc.)
    ├── screens/                 # Feature-decomposed UI
    │   ├── settings/            # Preference tabs
    │   ├── history/             # Session history
    │   └── ...
    └── widgets/                 # Common reusable UI components
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

### Dependency Injection (DI)

The application uses `get_it` for dependency injection, configured in `lib/core/di/injection.dart`. This ensures that BLoCs and repositories are instantiated with their required dependencies and maintains singleton lifecycles for core services like `AsrWebSocketClient`.

### Key Repositories (Domain Layer)

| Repository | Responsibility |
|------------|----------------|
| `IAuthRepository` | Abstraction for authentication operations. |
| `ISettingsRepository`| Abstraction for persisting and retrieving application settings. |
| `ITranslationRepository`| Abstraction for the live translation session and audio devices. |

### Key Services (Data Layer)
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
| `AuthRemoteDataSource` | Firebase Auth + custom URL schemes for Windows Google Sign-In redirects. Exposes `currentUser` ValueNotifier and public `auth`/`firestore` getters used by UI components like `AdminPanel` (Located in `features/auth/data`). |

---

## Language Compatibility Validation

All model language support is centralised in `lib/core/constants/model_language_support.dart` — the single Dart source of truth. No screen or BLoC defines its own language sets.

| Symbol | Purpose |
|---|---|
| `rivaTranslationLangs` | Languages supported by Riva NMT (both source and target must be in set) |
| `llamaLangs` | `null` — Llama is unrestricted |
| `translationLangsFor(model)` | Returns the supported set for a model, or `null` if unrestricted |
| `translationCompatibilityError(model, source, target)` | Returns a human-readable error string if the combo is unsupported, otherwise `null` |

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
```
