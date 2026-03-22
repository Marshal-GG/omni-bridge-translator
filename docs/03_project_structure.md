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
│   │   ├── constants/               # Strings, Colors, Dimensions
│   │   ├── device/                  # Device & System services integration
│   │   ├── infrastructure/          # Native/Desktop process integrations
│   │   ├── navigation/              # AppRouter & GlobalNavigator
│   │   ├── platform/                # Tray, Window, Initializer
│   │   ├── theme/                   # AppTheme
│   │   └── utils/                   # Shared utilities
│   │
│    ├── features/                    # Feature Modules (Clean Architecture)
    │   ├── auth/                    # Auth: Domain (UseCases), Data, Presentation
    │   ├── history/                 # History: Domain, Data, Presentation
    │   ├── settings/                # Settings: Domain (UseCases), Data, Presentation
    │   ├── translation/             # Translation: Domain (UseCases), Data, Presentation
    │   ├── subscription/            # Subscription: Domain, Data, Presentation [NEW]
    │   ├── startup/                 # Startup: Splash, Onboarding [NEW]
    │   └── about/                   # About: Update logic [NEW]
    │
    ├── data/                        # Core Data (Shared Models/Services)
    │   ├── models/                  # AppSettings, CaptionModel, etc.
    │   └── services/                # Grouped by provider
    │       ├── firebase/            # TrackingService, SubscriptionService
    │       ├── server/              # AsrWsClient, UpdateService
    │       ├── system/              # AppLifecycle
    │       └── translation/         # TranslationService, WhisperService
    │
    └── presentation/                # Layer for global UI & shared blocs
        ├── blocs/                   # Global BLoCs
        └── widgets/                 # Common reusable widgets
│
├── server/                          # Python backend
│   ├── flutter_server.py            # FastAPI entrypoint
│   └── src/
│       ├── asr/                     # ASR dispatcher & logic
│       ├── translation/             # Translation dispatcher & logic
│       ├── audio/                   # Audio capture layer
│       ├── models/                  # AI Model Implementations
│       │   ├── asr/                 # ASR models (Riva, Whisper, Local)
│       │   └── translation/         # Translation models (Riva NMT, Llama, Google, MyMemory)
│       ├── network/                 # Handlers & Routing
│       │   ├── handlers/            # Modular per-concern handlers
│       │   ├── base_handler.py      # Shared context
│       │   ├── router.py            # Command routing
│       │   └── ws_manager.py        # Connection tracking
│       └── utils/
│           ├── language_support.py
│           └── server_utils.py
│   └── tests/                       # Unit testing suite
│       ├── conftest.py
│       └── test_*.py
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
| **Phase 10**| Deep Restructure Phase 2: Features | ✅ **COMPLETE** (Auth, Translation, History, Settings, Startup, About, Subscription extracted) |
| **Phase 11**| Deep Restructure Phase 3: UseCases & DI | ✅ **COMPLETE** (20+ UseCases created, BLoCs refactored) |
| **Phase 12**| Deep Restructure Phase 4: Routing & BLoC Scoping | ✅ **COMPLETE** (AppRouter created, Route-scoped Blocs) |
---

## Naming Conventions

| Type | Convention | Example |
|------|-----------|---------|
| Dart files | `snake_case` | `history_service.dart` |
| Dart classes | `PascalCase` | `HistoryService` |
| BLoC events | Past tense or `Requested` | `SettingsUpdated` |
| BLoC states | Describe the state | `AuthAuthenticated` |
| Screens/Pages | Suffix `Page` | `TranslationPage` |
| Python files | `snake_case` | `asr_dispatcher.py` |
| Python classes | `PascalCase` | `ASRDispatcher` |
