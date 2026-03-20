# OmniBridge — Restructure Plan

> **Reference Model:** KiraSathi uses a strict 3-layer architecture (`core/` → `data/` → `presentation/`) with each layer owning its own concerns and zero cross-layer leakage. This plan brings OmniBridge to the same standard across both the Flutter client and the Python server.

---

## 1. Current State Audit

### 1.1 Flutter (`lib/`)

```
lib/
├── app.dart
├── main.dart
├── firebase_options.dart
├── models/           ← ❌ data models at root level (not in data layer)
│   ├── app_settings.dart
│   ├── caption_model.dart
│   ├── history_entry.dart
│   ├── subscription_models.dart
│   └── tracking_models.dart
├── screens/          ← ❌ screens at root level (not under presentation/)
│   ├── about/
│   ├── account/
│   ├── history/
│   ├── login/
│   ├── settings/
│   ├── startup/
│   ├── subscription/
│   └── translation/
└── core/             ← ⚠️ overloaded — contains blocs, services, widgets
    ├── app_initializer.dart
    ├── tray_manager.dart
    ├── window_manager.dart
    ├── blocs/
    │   └── firebase/  ← only one BLoC domain, misplaced inside core
    ├── config/
    ├── constants/
    ├── navigation/
    ├── routes/
    ├── services/      ← ❌ 8 service files all flat (no grouping by domain)
    │   ├── asr_ws_client.dart
    │   ├── asr_text_controller.dart
    │   ├── translation_service.dart
    │   ├── python_server_manager.dart
    │   ├── whisper_service.dart
    │   ├── history_service.dart
    │   ├── update_service.dart
    │   └── app_lifecycle.dart
    ├── theme/
    ├── utils/
    └── widgets/       ← ❌ empty directory
```

**Problems:**
| # | Issue | Impact |
|---|-------|--------|
| 1 | `lib/models/` at root — no layer ownership | Hard to know where data logic lives |
| 2 | `lib/screens/` at root — not under presentation | Breaks architectural convention |
| 3 | `core/` contains BLoCs and services — not just framework code | Core should be zero business logic |
| 4 | Services flat in `core/services/` with no domain grouping | 8 files grow into 20 with no discoverability |
| 5 | `core/widgets/` exists but is empty | Indicates unfinished extraction |
| 6 | BLoCs only cover Firebase — all translation/server state lives in services | No clear state management story for translation |

---

### 1.2 Python Server (`server/`)

```
server/
├── flutter_server.py     ✅ clean entrypoint (FastAPI + lifespan)
├── pyproject.toml
└── src/
    ├── audio/            ✅ reasonably scoped
    │   ├── capture.py    (16KB)
    │   ├── handler.py
    │   ├── meter.py
    │   └── shared_pyaudio.py
    ├── models/           ⚠️ 7 AI model files flat — no subgrouping
    │   ├── google_cloud_model.py
    │   ├── google_model.py
    │   ├── llama_model.py
    │   ├── mymemory_model.py
    │   ├── riva_model.py
    │   ├── speech_recognition_model.py
    │   └── whisper_model.py
    ├── network/
    │   ├── orchestrator.py   ← ❌ 514-line GOD class (ASR + Translation + Threading + Fallbacks)
    │   ├── handlers.py     (13KB)
    │   ├── router.py
    │   └── ws_manager.py
    └── utils/
        ├── language_support.py
        └── server_utils.py
```

**Problems:**
| # | Issue | Impact |
|---|-------|--------|
| 1 | `orchestrator.py` is a 514-line God class — ASR dispatch, translation dispatch, threading, fallback logic, stutter cleaning, lang detection all in one | Impossible to test individual concerns |
| 2 | `src/models/` mixes ASR models (Whisper, Riva SR, Google SR) with translation models (Llama, Google, MyMemory, Riva NMT) | Makes model routing logic implicit |
| 3 | `handlers.py` (13KB) contains `ServerContext`, `SessionHandler`, `ConfigHandler`, `DeviceHandler`, `StatusHandler` all in one file | Single file for 5 distinct responsibilities |
| 4 | No `pipeline/` or `services/` concept — all logic sits in `network/` | Network layer is doing business logic |
| 5 | Debug wave file saving baked into `_asr_worker` | Dev tooling polluting production code paths |

---

## 2. Target Architecture

### 2.1 Flutter — KiraSathi-inspired 3-layer model

```
lib/
├── main.dart
├── app.dart
├── firebase_options.dart
├── injection_container.dart        ← NEW: GetIt DI (mirrors KiraSathi pattern)
│
├── core/                           ← Framework only, zero business logic
│   ├── constants/
│   │   ├── app_strings.dart
│   │   ├── app_colors.dart
│   │   └── app_dimensions.dart
│   ├── theme/
│   │   └── app_theme.dart
│   ├── router/
│   │   └── app_router.dart         ← move from core/routes/ + core/navigation/
│   ├── utils/
│   │   └── formatters.dart
│   └── errors/
│       └── failures.dart           ← Either<Failure,T> pattern (like KiraSathi)
│
├── data/                           ← NEW top-level layer (mirrors KiraSathi)
│   ├── models/                     ← MOVE from lib/models/
│   │   ├── app_settings.dart
│   │   ├── caption_model.dart
│   │   ├── history_entry.dart
│   │   ├── subscription_models.dart
│   │   └── tracking_models.dart
│   ├── repositories/               ← NEW: wrap services with Either<Failure,T>
│   │   ├── session_repository.dart      (start/stop translation session)
│   │   ├── settings_repository.dart     (load/save app settings)
│   │   ├── history_repository.dart      (caption history CRUD)
│   │   └── subscription_repository.dart (plan state)
│   └── services/
│       ├── server/
│       │   ├── python_server_manager.dart
│       │   └── asr_ws_client.dart
│       ├── translation/
│       │   ├── translation_service.dart
│       │   ├── whisper_service.dart
│       │   └── asr_text_controller.dart
│       ├── system/
│       │   ├── app_lifecycle.dart
│       │   └── update_service.dart
│       └── firebase/
│           └── (firebase-specific services)
│
└── presentation/                   ← NEW top-level layer (mirrors KiraSathi)
    ├── blocs/
    │   ├── firebase/               ← KEEP existing
    │   │   ├── firebase_bloc.dart
    │   │   ├── firebase_event.dart
    │   │   └── firebase_state.dart
    │   ├── session/                ← NEW: replaces raw service calls in screen
    │   │   ├── session_bloc.dart
    │   │   ├── session_event.dart
    │   │   └── session_state.dart
    │   ├── caption/                ← NEW: caption stream + display state
    │   │   ├── caption_bloc.dart
    │   │   ├── caption_event.dart
    │   │   └── caption_state.dart
    │   └── settings/               ← NEW: settings load/save state
    │       ├── settings_bloc.dart
    │       ├── settings_event.dart
    │       └── settings_state.dart
    ├── screens/                    ← MOVE from lib/screens/
    │   ├── translation/
    │   ├── settings/
    │   ├── history/
    │   ├── subscription/
    │   ├── account/
    │   ├── startup/
    │   ├── login/
    │   └── about/
    └── widgets/
        ├── common/
        │   ├── caption_overlay.dart
        │   ├── status_badge.dart
        │   └── model_health_card.dart
        └── translation/
            ├── language_selector.dart
            └── engine_selector.dart
```

---

### 2.2 Python Server — Decomposed pipeline

```
server/
├── flutter_server.py        ✅ keep as-is
└── src/
    ├── audio/               ✅ keep as-is
    │   ├── capture.py
    │   ├── handler.py
    │   ├── meter.py
    │   └── shared_pyaudio.py
    │
    ├── asr/                 ← NEW: extract from orchestrator
    │   ├── __init__.py
    │   ├── asr_dispatcher.py    (routes to correct ASR model, replaces _perform_asr + _asr_worker)
    │   └── asr_config.py        (RMS threshold, dedup window, constants)
    │
    ├── translation/         ← NEW: extract from orchestrator
    │   ├── __init__.py
    │   ├── translation_dispatcher.py  (replaces _dispatch_translation + fallback logic)
    │   └── lang_detector.py           (script-based detection, replaces _detect_lang_from_script)
    │
    ├── pipeline/            ← NEW: replaces the God orchestrator class
    │   ├── __init__.py
    │   └── orchestrator.py          (thin coordinator: owns queues + threads, delegates to asr/ + translation/)
    │
    ├── models/
    │   ├── asr/             ← NEW subgroup: speech recognition models
    │   │   ├── __init__.py
    │   │   ├── whisper_model.py
    │   │   ├── riva_model.py         (ASR part only)
    │   │   ├── google_model.py
    │   │   └── speech_recognition_model.py
    │   └── translation/     ← NEW subgroup: translation models
    │       ├── __init__.py
    │       ├── llama_model.py
    │       ├── mymemory_model.py
    │       ├── google_cloud_model.py
    │       └── riva_nmt_model.py     (translation part of riva_model.py split out)
    │
    ├── network/
    │   ├── router.py        ✅ keep
    │   ├── ws_manager.py    ✅ keep
    │   └── handlers/        ← SPLIT handlers.py into per-handler files
    │       ├── __init__.py
    │       ├── context.py         (ServerContext)
    │       ├── session_handler.py
    │       ├── config_handler.py
    │       ├── device_handler.py
    │       └── status_handler.py
    │
    └── utils/               ✅ keep + add debug utils
        ├── language_support.py
        ├── server_utils.py
        └── debug_audio.py   ← MOVE debug wave-saving logic here (out of orchestrator)
```

---

## 3. Migration Phases

This is a **non-breaking, incremental** migration. Each phase can be committed independently.

### Phase 1 — Flutter: Create layers, move files (no logic change) — ✅ COMPLETE
- Create `lib/data/models/`, `lib/data/services/`, `lib/data/repositories/`
- Create `lib/presentation/blocs/`, `lib/presentation/screens/`, `lib/presentation/widgets/`
- Move `lib/models/` → `lib/data/models/`
- Move `lib/screens/` → `lib/presentation/screens/`
- Move `lib/core/services/` → `lib/data/services/` (grouped into `server/`, `translation/`, `system/`)
- Move `lib/core/blocs/` → `lib/presentation/blocs/`
- Update all import paths (no behaviour change)

### Phase 2 — Flutter: Add repositories + DI container
- Create `injection_container.dart` with GetIt (mirrors `kirasathi/lib/injection_container.dart`)
- Create `lib/data/repositories/` wrappers that return `Either<Failure, T>`
- Wire repositories and BLoCs through GetIt

### Phase 3 — Flutter: Add missing BLoCs
- `SessionBloc` (start/stop translation, replaces direct service calls in screens)
- `CaptionBloc` (caption display state + history)
- `SettingsBloc` (load/save settings)
- Extract common widgets into `presentation/widgets/common/`

### Phase 4 — Python: Split handlers.py
- Move each handler class to `src/network/handlers/` as its own file
- No logic change, pure file split

### Phase 5 — Python: Split orchestrator (biggest change)
- Extract `_asr_worker` + `_perform_asr` → `src/asr/asr_dispatcher.py`
- Extract `_translation_worker` + `_dispatch_translation` + fallbacks → `src/translation/translation_dispatcher.py`
- Extract `_detect_lang_from_script` → `src/translation/lang_detector.py`
- Extract `_clean_stutters` → `src/asr/asr_config.py` or `src/utils/`
- Slim `InferenceOrchestrator` down to ~100 lines (queue setup + thread lifecycle only)

### Phase 6 — Python: Split models/
- Move ASR models → `src/models/asr/`
- Move translation models → `src/models/translation/`
- Split `riva_model.py` into `riva_asr_model.py` and `riva_nmt_model.py`

### Phase 7 — Python: Move debug tooling
- Move inline `wave` debug saving from `_asr_worker` → `src/utils/debug_audio.py`
- Gate behind an env flag (`OMNI_BRIDGE_DEBUG`)

---

## 4. Naming Conventions (align with KiraSathi)

| Type | Convention | Example |
|------|-----------|---------|
| Dart files | `snake_case` | `session_repository.dart` |
| Dart classes | `PascalCase` | `SessionRepository` |
| BLoC events | Suffix `Requested` or `Submitted` | `SessionStartRequested` |
| BLoC states | Describe state | `SessionRunning`, `SessionStopped` |
| Screens | Suffix `Screen` | `TranslationScreen` |
| Python files | `snake_case` | `asr_dispatcher.py` |
| Python classes | `PascalCase` | `ASRDispatcher` |
| Python handlers | Suffix `Handler` | `SessionHandler` |

---

## 5. What Stays the Same

The following are well-structured and **do not need to change**:

| Item | Reason |
|------|--------|
| `flutter_server.py` | Clean FastAPI entrypoint with proper lifespan |
| `src/network/router.py` | Simple command router, focused and small |
| `src/network/ws_manager.py` | Clean WebSocket connection manager |
| `src/audio/` | Well-scoped audio capture layer |
| `src/utils/language_support.py` | Single purpose, no fat |
| `lib/core/config/` | Clean config setup |
| `lib/core/theme/` | Correct placement in core |
| `lib/core/constants/` | Correct placement in core |
| Firestore rules + indexes | Well-structured already |

---

## 6. Key Principle Differences vs KiraSathi

| KiraSathi | OmniBridge equivalent |
|-----------|----------------------|
| Firebase as data source | Python server (WebSocket) as data source |
| `Either<Failure, T>` from repositories | `Either<Failure, T>` from repositories wrapping WS calls |
| Cloud Functions for background work | Python scheduler / audio worker threads |
| GetIt DI for all BLoCs | GetIt DI for all BLoCs + server manager |
| `presentation/blocs/` per feature | `presentation/blocs/` per feature (session, caption, settings) |

---

## 7. Additional Improvements (Before Proceeding)

These are pre-migration fixes and hygiene tasks to do **before or alongside Phase 1**.

### 7.1 Flutter — Pin all dependency versions

Several packages in `pubspec.yaml` have **no version constraints**, which means a silent `flutter pub upgrade` can break the build at any time:

```yaml
# ❌ Current (dangerous)
provider:
http:
bitsdojo_window:
tray_manager:
system_tray:
flutter_acrylic:

# ✅ Fix — pin with ^ constraints
provider: ^6.1.2
http: ^1.2.2
bitsdojo_window: ^0.1.6
tray_manager: ^0.2.3
system_tray: ^2.0.3
flutter_acrylic: ^1.1.2
```

Also: **`provider` appears unused** — the app uses BLoC throughout. If Provider is no longer called anywhere, drop it from `pubspec.yaml`.

---

### 7.2 Flutter — Add test infrastructure scaffolding

Unlike KiraSathi (which ships with `bloc_test` + `mocktail`), OmniBridge has **zero test infrastructure**. Add the scaffolding now so each Phase can ship with a passing test:

```yaml
# Add to dev_dependencies:
bloc_test: ^10.0.0
mocktail: ^1.0.4
```

Create the folder skeleton:
```
test/
├── data/
│   ├── repositories/
│   └── services/
└── presentation/
    └── blocs/
```

This costs nothing upfront and makes each phase verifiable.

---

### 7.3 Flutter — Move loose desktop files out of `core/` root

`core/tray_manager.dart` and `core/window_manager.dart` are floating at the `core/` root alongside `app_initializer.dart`. Move them to a `core/platform/` subfolder:

```
core/platform/
├── tray_manager.dart
├── window_manager.dart
└── app_initializer.dart
```

This keeps `core/` consistent — every concern has its own subfolder, nothing loose at root.

---

### 7.4 Python — Enforce `__init__.py` API contracts

When `asr/`, `translation/`, and `pipeline/` are created in Phase 5, each must have a clean `__init__.py` that **explicitly exports its public API**. This prevents wildcard import chains and makes the package boundary clear:

```python
# src/asr/__init__.py  ✅
from .asr_dispatcher import ASRDispatcher
from .asr_config import ASR_RMS_THRESHOLD, DEDUP_WINDOW_S

# src/translation/__init__.py  ✅
from .translation_dispatcher import TranslationDispatcher
from .lang_detector import detect_lang_from_script
```

Existing packages like `src/audio/` and `src/utils/` should be audited to follow the same pattern.

---

### 7.5 Python — Split `riva_model.py` before Phase 5 (priority)

`riva_model.py` (8.4 KB) handles **two completely different gRPC services**:
- `RivaSpeechRecognitionServiceStub` → ASR
- `RivaNmtServiceStub` → Translation

This dual responsibility is the primary reason `orchestrator.py` is hard to decompose. **Do this split at the start of Phase 6**, before tackling Phase 5, so the orchestrator refactor works with already-clean model boundaries:

```
src/models/asr/riva_asr_model.py          ← RecognitionService only
src/models/translation/riva_nmt_model.py  ← NmtService only
```

---

### 7.6 Scripts folder — Document in developer setup

`scripts/` contains two legitimate dev utilities:
- `clear_app_data.ps1` — purges app data / SecureStorage for clean testing
- `clear_app_data.cmd` — Windows CMD wrapper for the same

Neither is mentioned in `docs/developer_setup.md`. Add a **"Dev Scripts"** section there so contributors know these exist and when to use them. No code change needed.

---

*Generated: 2026-03-20 | Scope: Flutter client + Python server | Strategy: incremental, non-breaking*
