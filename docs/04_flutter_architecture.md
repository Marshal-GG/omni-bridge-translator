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
│   ├── navigation/              # AppRouter (Centralized) & GlobalNavigator
│   ├── platform/                # Platform-specific logic (Window, Tray, AppInitializer)
│   ├── theme/                   # AppTheme (Dark Material 3)
│   └── utils/                   # Shared helpers & Extensions
│
├── features/                    # Feature Modules (Vertical Slice)
│   ├── auth/                    # Auth: Login, Logout, User state
│   ├── translation/             # Translation: Live captions & engine control
│   ├── settings/                # Settings: User preferences & device management
│   ├── history/                 # History: Local session storage
│   ├── subscription/            # Subscription: Quota & monetization
│   ├── startup/                 # Startup: Bootstrapping, Splash, Onboarding
│   └── about/                   # About: Version info & updates
│
├── core/                        # Shared Framework & Cross-cutting Concerns
│   ├── di/                      # Dependency Injection (injection.dart)
│   ├── navigation/              # AppRouter (Route generation)
│   └── ...                      # platform, theme, utils, etc.
```

---

## Key BLoCs

| BLoC | Responsibility | Depends On |
|------|----------------|------------|
| `AuthBloc` | Firebase Auth state management | `IAuthRepository` |
| `SettingsBloc` | User preferences, device selection, and audio monitoring | `SyncSettingsUseCase`, `LoadDevicesUseCase`, `ObserveAudioLevelsUseCase` |
| `TranslationBloc` | Live translation session control, caption streaming, and quota tracking | `ObserveCaptionsUseCase`, `ObserveQuotaStatusUseCase`, `StartTranslationUseCase` |
| `HistoryBloc` | Live and chunked transcription history | `GetLiveHistoryUseCase`, `GetChunkedHistoryUseCase`, `ClearHistoryUseCase` |
| `AboutBloc` | App versioning and updates | `CheckForUpdateUseCase` |
| `StartupBloc` | Bootstrapping, auth check, and routing | - |

---

### UseCase Layer (Domain Feature)

UseCases are the brain of the feature. They encapsulate a single business logic piece and are independent of both UI and Data implementation.

| Feature | Key UseCases |
|---------|--------------|
| **Auth** | `LoginWithGoogle`, `Logout`, `GetCurrentUser`, `ObserveAuthChanges` |
| **Settings** | `LoadDevices`, `ObserveAudioLevels`, `SyncSettings`, `LogEvent` |
| **Translation** | `ObserveCaptions`, `ObserveQuotaStatus`, `UpdateTranslationSettings`, `UpdateVolume` |
| **About** | `CheckForUpdate` |

### Dependency Injection (DI)

The application uses `get_it` for dependency injection. All UseCases are registered as **LazySingletons**, and BLoCs are factory-injected with these UseCases. 

> [!IMPORTANT]
> **BLoC Scoping**: Feature-specific BLoCs are not registered as singletons. They are provided at the **Route Level** within `AppRouter.generateRoute` using `BlocProvider`. This ensures BLoCs are only instantiated when the user navigates to the feature and are correctly disposed of when the route is popped.

See `lib/core/di/injection.dart` and `lib/core/navigation/app_router.dart`.

### Key DataSources & Services

| Component | Responsibility |
|-----------|----------------|
| `AsrWebSocketDataSource` | High-level wrapper around the caption WebSocket. Dispatches events to `AsrTextController`. |
| `AsrTextController` | Manages display buffer, interim vs final text, and typing catch-up logic. |
| `TranslationRemoteDataSource` | Manages translation configurations and engine-specific logic via Firestore. |
| `TranscriptionRemoteDataSource` | Manages transcription (ASR) configurations via Firestore. |
| `SubscriptionRemoteDataSource`| Handles real-time subscription status, tiers, and monetization configs. |
| `TrackingRemoteDataSource` | Sole source of truth for usage tracking, session management, and buffering stats. |
| `UpdateRemoteDataSource` | Checks for new versions via GitHub API (Migrated from `UpdateService`). |
| `AuthRemoteDataSource` | Handles Firebase Auth and Google Sign-In redirects. |
| `StorageService` | Secure DPAPI storage wrapper (located in `core/platform`). |
| `PythonServerManager` | Manages local Python process lifecycle (Auto-restart, backoff). |

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
     └─ AppRouter injects TranslationBloc into Overlay Route
         └─ Overlay window opens (bitsdojo_window)
             └─ AsrTextController buffers caption events
                 └─ UI reacts via BlocBuilder
```
