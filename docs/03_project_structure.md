# 03 — Project Structure

> This document describes the **current** project layout and the **target** layout after the restructure (see `16_restructure_plan.md`).

---

## Current Structure

```
omni_bridge/
├── lib/                             # Flutter source
│   ├── main.dart                    # Entry point — Firebase init, window setup, server start
│   ├── app.dart                     # Root widget — MaterialApp + BLoC providers
│   ├── firebase_options.dart        # Firebase config (generated)
│   │
│   ├── core/                        # Framework-level logic (Shared)
│   │   ├── config/                  # AppConfig, ServerConfig
│   │   ├── constants/               # Strings, Colors, Model Language Support
│   │   ├── di/                      # Dependency Injection (injection.dart)
│   │   ├── error/                   # Failure classes
│   │   ├── navigation/              # AppRouter & GlobalNavigator
│   │   ├── platform/                # Tray, Window, AppInitializer
│   │   ├── theme/                   # AppTheme
│   │   └── utils/                   # Shared utilities & Extensions
│   │
│   └── features/                    # Feature Modules (Vertical Slice Architecture)
│       ├── auth/                    # Authentication
│       │   ├── domain/              # Entities, IAuthRepository, UseCases (Login, Logout, GetCurrentUser)
│       │   ├── data/                # AuthRemoteDataSource, Repository implementation
│       │   └── presentation/        # AuthBloc, LoginScreen
│       ├── translation/             # Live captioning & engine control
│       │   ├── domain/              # UseCases (ObserveCaptions, StartTranslation, UpdateSettings)
│       │   ├── data/                # AsrWsClient, AsrTextController, RemoteDataSources
│       │   └── presentation/        # TranslationBloc, TranslationScreen, OverlayScreen
│       ├── settings/                # User preferences & device management
│       │   ├── domain/              # UseCases (LoadDevices, ObserveAudioLevels, SyncSettings)
│       │   ├── data/                # SettingsRemoteDataSource, StorageService
│       │   └── presentation/        # SettingsBloc, SettingsScreen
│       ├── history/                 # Caption history storage
│       │   ├── domain/              # UseCases (GetLiveHistory, GetChunkedHistory, ClearHistory)
│       │   ├── data/                # HistoryRemoteDataSource
│       │   └── presentation/        # HistoryBloc, HistoryScreen
│       ├── subscription/            # Quota & monetization
│       │   ├── domain/              # UseCases (GetSubscriptionStatus, GetAvailablePlans, ActivateTrial)
│       │   ├── data/                # SubscriptionRemoteDataSource, TrackingRemoteDataSource
│       │   └── presentation/        # SubscriptionBloc, UpgradeSheet
│       ├── startup/                 # Bootstrapping & onboarding
│       │   ├── domain/              # StartupBloc dependencies
│       │   ├── data/                # (minimal — delegates to auth/settings)
│       │   └── presentation/        # StartupBloc, SplashScreen, OnboardingScreen
│       └── about/                   # Version info & updates
│           ├── domain/              # UseCases (CheckForUpdate)
│           ├── data/                # UpdateRemoteDataSource
│           └── presentation/        # AboutBloc, AboutScreen
│
├── server/                          # Python backend
│   ├── flutter_server.py            # FastAPI entrypoint
│   └── src/
│       ├── pipeline/                # Thin orchestration layer
│       │   └── orchestrator.py      # InferenceOrchestrator (delegates to ASR + Translation dispatchers)
│       ├── asr/                     # ASR dispatcher & logic
│       │   └── asr_dispatcher.py
│       ├── translation/             # Translation dispatcher & logic
│       │   └── translation_dispatcher.py
│       ├── audio/                   # Audio capture layer
│       │   ├── capture.py           # WASAPI loopback + mic + VAD
│       │   ├── handler.py           # caption_callback, audio_poll_loop
│       │   ├── meter.py             # RMS metering (dB-normalized 0.0–1.0)
│       │   └── shared_pyaudio.py    # Thread-safe global PyAudio singleton
│       ├── models/                  # AI Model Implementations
│       │   ├── asr/                 # ASR models (Riva, Whisper, Google)
│       │   └── translation/         # Translation models (Riva NMT, Llama, Google, MyMemory)
│       ├── network/                 # Network layer
│       │   ├── handlers/            # Modular per-concern handlers
│       │   │   ├── base_handler.py      # Shared BaseHandler & ServerContext
│       │   │   ├── session_handler.py   # Session lifecycle (start/stop)
│       │   │   ├── config_handler.py    # Settings & volume updates
│       │   │   ├── device_handler.py    # WASAPI device enumeration
│       │   │   └── status_handler.py    # Health & model status
│       │   ├── router.py            # Command routing
│       │   └── ws_manager.py        # WebSocket connection tracking
│       └── utils/
│           ├── language_support.py  # Single source of truth for language capabilities
│           └── server_utils.py      # Structured logging, process management
│
└── tests/                           # Flutter unit test suite
    ├── features/
    │   ├── auth/
    │   ├── about/
    │   ├── history/
    │   ├── settings/
    │   ├── startup/
    │   └── subscription/
    └── helpers/
        └── test_mocks.dart          # Shared mocktail mock helpers
```

---

## Restructure Status

| Phase | Goal | Status |
|-------|------|--------|
| **Phase 1** | Flutter 3-Layer Restructure | ✅ **COMPLETE** |
| **Phase 2** | Flutter Data Layer (Repositories & DI) | ✅ **COMPLETE** |
| **Phase 3** | Flutter Presentation Layer (BLoCs) | ✅ **COMPLETE** |
| **Phase 4** | Python Server Modularization (Handlers) | ✅ **COMPLETE** |
| **Phase 5** | Python Orchestrator Decomposition | ✅ **COMPLETE** |
| **Phase 6** | Python Model Reorganization | ✅ **COMPLETE** |
| **Phase 7** | Python Integration Tests (Warp Speed) | ⏭️ **SKIPPED** |
| **Phase 8** | Python Unit Tests (Pytest) | ✅ **COMPLETE** |
| **Phase 9** | Deep Restructure Phase 1: Core/Infra | ✅ **COMPLETE** |
| **Phase 10**| Deep Restructure Phase 2: Features | ✅ **COMPLETE** |
| **Phase 11**| Deep Restructure Phase 3: UseCases & DI | ✅ **COMPLETE** |
| **Phase 12**| Deep Restructure Phase 4: Routing & BLoC Scoping | ✅ **COMPLETE** |
| **Phase 13**| Phase 7: Final Data Layer Consolidation | ✅ **COMPLETE** |
| **Phase 14**| Phase 8: BLoC Consistency | ✅ **COMPLETE** |
| **Phase 15**| Phase 9: Unified Naming (`pages/` -> `screens/`) | ✅ **COMPLETE** |
| **Phase 16**| Phase 10: Final Core Refinement | ✅ **COMPLETE** |
---

## Naming Conventions

| Type | Convention | Example |
|------|-----------|---------|
| Dart files | `snake_case` | `history_service.dart` |
| Dart classes | `PascalCase` | `HistoryService` |
| BLoC events | Past tense or `Requested` | `SettingsUpdated` |
| BLoC states | Describe the state | `AuthAuthenticated` |
| Screens | Suffix `Screen` | `TranslationScreen` |
| Python files | `snake_case` | `asr_dispatcher.py` |
| Python classes | `PascalCase` | `ASRDispatcher` |
