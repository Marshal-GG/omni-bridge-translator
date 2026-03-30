<!--
 Copyright (c) 2026 Omni Bridge. All rights reserved.
 
 Licensed under the PERSONAL STUDY & LEARNING LICENSE v1.0.
 Commercial use and public redistribution of modified versions are strictly prohibited.
 See the LICENSE file in the project root for full license terms.
-->

# 05 — Flutter Architecture

## Overview

The Omni Bridge client is a Flutter desktop app (Windows-first) that serves as the UI and orchestration layer. It connects to a local Python WebSocket server for audio capture, ASR, and translation.

State management: **BLoC pattern** throughout.
Architecture: **Clean Architecture (Layered)** with **Repository Pattern** and **Dependency Injection** using `get_it`.

> [!NOTE]
> The Vertical Slice (Feature-Driven) architecture is **fully implemented** as of Phase 16. All features have been migrated to `lib/features/` with complete `domain/`, `data/`, and `presentation/` sub-layers.

---

## Directory Structure (3-Layer Architecture)

The project follows a clean, modular 3-layer architecture to ensure scalability and maintainability.

```
lib/
├── core/                        # Shared Framework & Infrastructure
│   ├── config/                  # AppConfig, ServerConfig
│   ├── constants/               # Strings, Colors, Model Language Support
│   ├── data/                    # App-level DataSources (Sessions, Usage, Maintenance)
│   ├── device/                  # Device info utilities
│   ├── di/                      # Dependency Injection (injection.dart)
│   ├── error/                   # Failure classes
│   ├── infrastructure/          # PythonServerManager (process lifecycle)
│   ├── navigation/              # AppRouter (Centralized) & GlobalNavigator
│   ├── network/                 # Global HTTP Clients (e.g., RTDBClient)
│   ├── platform/                # Platform-specific logic (Window, Tray, AppInitializer)
│   ├── routes/                  # MyNavObserver (navigation analytics & window resizing)
│   ├── theme/                   # AppTheme (Design System: Colors, Spacing, Text, Shapes)
│   └── utils/                   # Shared helpers & Extensions
│
└── features/                    # Feature Modules (Vertical Slice)
    ├── auth/                    # Auth: Login, Logout, User state
    ├── translation/             # Translation: Live captions & engine control
    ├── settings/                # Settings: User preferences & device management
    ├── history/                 # History: Local session storage
    ├── subscription/            # Subscription: Quota & monetization
    ├── startup/                 # Startup: Bootstrapping, Splash, Onboarding
    ├── about/                   # About: Version info & updates
    └── usage/                   # Usage: Analytics & statistics dashboard
```

---

## Key BLoCs

| BLoC | Responsibility | Depends On |
|------|----------------|------------|
| `AuthBloc` | Firebase Auth state management | `IAuthRepository` |
| `SettingsBloc` | User preferences, device selection, and audio monitoring | `GetAppSettingsUseCase`, `UpdateAppSettingsUseCase`, `GetGoogleCredentialsUseCase`, `LoadDevicesUseCase`, `ObserveAudioLevelsUseCase`, `LogEventUseCase`, `GetSubscriptionStatus` |
| `TranslationBloc` | Live translation session control, caption streaming, server health, model status, quota reactivity, and auth-aware settings sync | `StartTranslationUseCase`, `StopTranslationUseCase`, `UpdateVolumeUseCase`, `GetModelStatusUseCase`, `ObserveCaptionsUseCase`, `ObserveQuotaStatusUseCase`, `GetInitialQuotaStatusUseCase`, `GetDefaultTierUseCase`, `UpdateTranslationSettingsUseCase`, `CheckServerHealthUseCase`, `GetCurrentUserUseCase`, `ObserveAuthChangesUseCase`, `GetAppSettingsUseCase`, `GetGoogleCredentialsUseCase`, `SyncSettingsUseCase`, `LogEventUseCase`, `LogoutUseCase`, `GetSystemConfigUseCase`, `SubscriptionRemoteDataSource`, `TranslationRestDatasource` |
| `HistoryBloc` | Live and chunked transcription history | `GetLiveHistoryUseCase`, `GetChunkedHistoryUseCase`, `ClearHistoryUseCase`, `AddHistoryEntryUseCase`, `ConfigureHistoryUseCase`, `SubscriptionRemoteDataSource` |
| `AboutBloc` | App versioning and updates | `CheckForUpdate` |
| `StartupBloc` | Bootstrapping, auth check, and routing | `IAuthRepository` |
| `SubscriptionBloc` | Real-time subscription status and plan management | `GetSubscriptionStatus`, `GetAvailablePlans`, `ActivateTrial`, `OpenCheckout`, `HasUsedTrial` |

---

### UseCase Layer (Domain Feature)

UseCases are the brain of the feature. They encapsulate a single business logic piece and are independent of both UI and Data implementation.

| Feature | Key UseCases |
|---------|--------------|
| **Auth** | `LoginWithGoogle`, `Logout`, `GetCurrentUser`, `ObserveAuthChanges` |
| **Settings** | `GetAppSettings`, `UpdateAppSettings`, `GetGoogleCredentials`, `LoadDevices`, `ObserveAudioLevels`, `SyncSettings`, `LogEvent`, `GetSystemConfig` |
| **Translation** | `ObserveCaptions`, `ObserveQuotaStatus`, `GetInitialQuotaStatus`, `GetDefaultTier`, `StartTranslation`, `StopTranslation`, `UpdateTranslationSettings`, `UpdateVolume`, `CheckServerHealth`, `GetModelStatus` |
| **History** | `GetLiveHistory`, `GetChunkedHistory`, `AddHistoryEntry`, `ConfigureHistory`, `ClearHistory` |
| **Subscription** | `GetSubscriptionStatus`, `GetAvailablePlans`, `ActivateTrial`, `OpenCheckout`, `HasUsedTrial` |
| **About** | `CheckForUpdate` |
| **Usage** | *(Delegates to `UsageRepository` which wraps `ISubscriptionRepository`)* |

### Design System (AppTheme)

The application uses a centralized Design System located in `lib/core/theme/app_theme.dart`.
All cosmetic values (Colors, Spacing, text Styles, Shapes) are defined here as comprehensive tokens (`AppColors`, `AppSpacing`, `AppTextStyles`, etc). Feature modules strictly use these shared tokens instead of hardcoded metrics to ensure consistent scaling and styling across the application UI.

### Dependency Injection (DI)

The application uses `get_it` for dependency injection. All UseCases are registered as **LazySingletons**, and BLoCs are factory-injected with these UseCases. 

> [!IMPORTANT]
> **BLoC Scoping**: Feature-specific BLoCs are not registered as singletons. They are provided at the **Route Level** within `AppRouter.generateRoute` using `BlocProvider`. This ensures BLoCs are only instantiated when the user navigates to the feature and are correctly disposed of when the route is popped.

See `lib/core/di/injection.dart` and `lib/core/navigation/app_router.dart`.

---

## Unit Testing

The Flutter app uses [`bloc_test`](https://pub.dev/packages/bloc_test) and [`mocktail`](https://pub.dev/packages/mocktail) for BLoC unit testing.

### Running Flutter Tests

```powershell
# 05 — Flutter Architecture
flutter test

# 05 — Flutter Architecture
flutter test test/features/auth/presentation/blocs/auth_bloc_test.dart
```

### Test Coverage (Phase 14)

| BLoC | Test File | Tests |
|------|-----------|-------|
| `AuthBloc` | `test/features/auth/presentation/blocs/auth_bloc_test.dart` | 3 |
| `AboutBloc` | `test/features/about/presentation/blocs/about_bloc_test.dart` | 4 |
| `HistoryBloc` | `test/features/history/presentation/blocs/history_bloc_test.dart` | 5 |
| `SettingsBloc` | `test/features/settings/presentation/blocs/settings_bloc_test.dart` | 5 |
| `StartupBloc` | `test/features/startup/presentation/blocs/startup_bloc_test.dart` | 3 |
| `SubscriptionBloc` | `test/features/subscription/presentation/bloc/subscription_bloc_test.dart` | 5 |

Shared mock helpers are located in `test/helpers/test_mocks.dart`.

> [!NOTE]
> `TranslationBloc` is intentionally excluded from unit tests due to its deep dependency on live WebSocket streams and audio capture. It is covered by integration/manual testing.

### CI/CD

A GitHub Actions pipeline (`.github/workflows/flutter_ci.yml`) automatically runs `flutter analyze` and `flutter test --coverage` on every push and pull request to `main`.

> [!IMPORTANT]
> Both `flutter_ci.yml` and `release.yml` are currently configured as **manual-trigger only** (`workflow_dispatch`). Auto-triggers are commented out at the top of each file. To re-enable push/PR triggers, follow the instructions in the comment header of each workflow file. See [12 GitHub Workflow Guide](../03_guides/12_github_workflow_guide.md) for full details on the CI/CD setup, branching strategy, and how to ship a release.

---

## Data Sources

| Component | Responsibility |
|-----------|----------------|
| `AsrWebSocketClient` | High-level wrapper around the caption WebSocket stream. Dispatches events to `AsrTextController`. Owns `AddHistoryEntryUseCase` and `ConfigureHistoryUseCase` for session-level history management. |
| `AsrTextController` | Manages display buffer, interim vs final text, and typing catch-up logic. |
| `LiveCaptionSyncDataSource` | Manages high-frequency real-time caption syncing logic to the database. |
| `TranslationRemoteDataSource` | Manages translation configurations and engine-specific logic via Firestore. |
| `TranscriptionRemoteDataSource` | Manages transcription (ASR) configurations via Firestore. |
| `TranslationRestDatasource` | HTTP REST client for translation-related server queries (e.g., model download status, Whisper model management). |
| `SubscriptionRemoteDataSource`| Handles real-time subscription status, tiers, and monetization configs. |
| `SessionRemoteDataSource` | App-level tracking for user session lifecycle and total duration. |
| `UsageMetricsRemoteDataSource` | App-level tracking for translation bytes and AI usage quotas. |
| `DataMaintenanceRemoteDataSource` | App-level scheduled cleanup for legacy data, stale sessions, and cache. |
| `UpdateRemoteDataSource` | Checks for new versions via GitHub API. Also triggers a silent background update check on app launch (see `main.dart`). |
| `AuthRemoteDataSource` | Handles Firebase Auth and Google Sign-In redirects. |
| `PythonServerManager` | Manages local Python process lifecycle (auto-restart, backoff). Lives in `core/infrastructure/`. |

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
     ├─ Version Update Check (via UpdateRemoteDataSource -> system/app_version)
     │   ├─ If Forced Update  → Routes directly to Force Update screen (Blocks app access)
     │   └─ If Optional Update → Sets visual badge via UpdateNotifier, continues boot sequence
     ├─ Deep links (OAuth redirects) routed to AuthService
      ├─ New user (Logged out) → AppInitializer → Splash → Onboarding → Login
      └─ Return user (Logged in) → AppInitializer → Translation Overlay (Direct)

Settings
 └─ SettingsBloc syncs preferences to Firestore on save
 └─ TranslationBloc triggers initial sync to Python server on app launch to populate model statuses

Start Translation
 └─ TranslationBloc sends `start` command via AsrWsClient
     ├─ Passes run-time configurations (dynamic Riva function IDs, Google credentials as JSON objects)
     └─ TranslationBloc is provided at app root (BlocProvider) to ensure state persistence
         └─ Overlay window opens (bitsdojo_window)
             └─ AsrTextController buffers caption events
                 └─ UI reacts via BlocBuilder (Handling `interim` vs `final`)

---

## Inference Status Flow

To handle heavy AI models (like Whisper Medium or Llama), the app implements a real-time status flow:

1.  **Python Model**: The model engine (e.g., `WhisperASR`) sets an internal `_is_loading` flag during initialization or reload.
2.  **Status Handler**: `status_handler.py` polls model states and broadcasts a `model_status` payload via WebSocket.
3.  **Flutter Bloc**: `TranslationBloc` listens for `model_status` events.
4.  **UI Updates**:
    - **Loading**: UI shows a progress indicator (e.g., "Loading Whisper Medium...").
    - **Ready**: UI enables the "Start" button and shows "Ready" status.
    - **Fallback**: If a primary model fails to load, `TranslationBloc` reflects the switch to a fallback engine (e.g., Google Online).
5.  **Connection Resilience**: If the server WebSocket disconnects, `TranslationBloc` detects the disconnect event, auto-pauses the stream, and the underlying `TranslationWebsocketClient` continuously attempts exponential backoff reconnection.
6.  **Subscription Tier Reactivity**: The `TranslationBloc` validates model selections against real-time subscription quotas. If a tier downgrade occurs, it transparently unloads premium models, fallback-switches to default models, and updates the UI.
```
