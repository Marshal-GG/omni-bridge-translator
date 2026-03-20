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
│   │   ├── navigation/              # GlobalNavigator
│   │   ├── platform/                # NEW: Tray, Window, Initializer
│   │   ├── routes/                  # Router + RoutesConfig
│   │   ├── theme/                   # AppTheme
│   │   └── utils/                   # Shared utilities
│   │
│   ├── data/                        # Data Layer (Domain-grouped)
│   │   ├── models/                  # AppSettings, CaptionModel, etc.
│   │   ├── repositories/            # Future: Abstract data access
│   │   └── services/                # Grouped by domain
│   │       ├── firebase/            # AuthService, TrackingService, SubscriptionService
│   │       ├── server/              # AsrWsClient, PythonServerManager, UpdateService
│   │       ├── system/              # HistoryService, AppLifecycle
│   │       └── translation/         # TranslationService, WhisperService
│   │
│   └── presentation/                # UI Layer
│       ├── blocs/                   # Feature BLoCs (Firebase MBs)
│       ├── screens/                 # Decomposed into domain folders
│       │   ├── translation/         # Overlay, history panel, header
│       │   ├── settings/            # Tabs (General, Language, Hotkeys)
│       │   ├── login/               # Auth UX
│       │   ├── history/             # Dedicated history view
│       │   ├── about/               # About + links
│       │   ├── account/             # User profile + logic
│       │   ├── subscription/        # Upgrade flows
│       │   └── startup/             # Splash + onboarding
│       └── widgets/                 # Common reusable widgets
│
├── server/                          # Python backend (Restructure In Progress)
│   ├── flutter_server.py            # FastAPI entrypoint
│   └── src/
│       ├── audio/                   # Audio capture layer
│       ├── models/                  # ⚠️ Mixed ASR + Translation models
│       ├── network/                 # WebSocket management
│       ├── orchestrator.py          # ⚠️ 514-line God class (Phase 2 Target)
│       └── ...
```

---

## Restructure Status

| Phase | Goal | Status |
|-------|------|--------|
| **Phase 1** | Flutter 3-Layer Restructure | ✅ **COMPLETE** |
| **Phase 2** | Python Server Model Decomposition | ⏳ PLANNED |
| **Phase 3** | Python Orchestrator Refactor | ⏳ PLANNED |
| **Phase 4** | Clean Data Layer (Repositories) | ⏳ PLANNED |

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
