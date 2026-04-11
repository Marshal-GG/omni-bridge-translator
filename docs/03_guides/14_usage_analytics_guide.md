<!--
 Copyright (c) 2026 Omni Bridge. All rights reserved.
 
 Licensed under the PERSONAL STUDY & LEARNING LICENSE v1.0.
 Commercial use and public redistribution of modified versions are strictly prohibited.
 See the LICENSE file in the project root for full license terms.
-->

# 14 — Usage Analytics Guide

This document describes the `usage` feature module — an in-app analytics dashboard that gives users a live breakdown of their AI engine consumption and quota status.

## Table of Contents
1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [Domain Layer](#3-domain-layer)
4. [Data Layer](#4-data-layer)
5. [Presentation Layer](#5-presentation-layer)
6. [Integration Points](#6-integration-points)

---

## 1. Overview

The `usage` feature displays per-session and cumulative statistics for AI usage (tokens consumed, bytes translated, quota remaining). It is entirely **read-only** — it has no commands of its own, instead reading from the `ISubscriptionRepository` which is populated by Firebase Realtime Database listeners in `UsageMetricsRemoteDataSource`.

**Feature location**: `lib/features/usage/`

---

## 2. Architecture

```
lib/features/usage/
├── domain/
│   ├── entities/           # EngineUsage, DailyUsageRecord, QuotaStatus
│   ├── repositories/
│   │   ├── usage_repository.dart              # Abstract interface (includes clearCache())
│   │   └── i_engine_selection_source.dart     # Re-exports core/interfaces/i_engine_selection_source.dart
│   ├── usecases/
│   │   ├── get_usage_stats.dart               # Aggregates engine stats from RTDB, checks plan access
│   │   ├── get_usage_history.dart             # Fetches 30-day daily usage history
│   │   ├── get_quota_status.dart              # Current daily/monthly quota snapshot
│   │   ├── check_usage_rollover.dart          # Archives and resets expired periods
│   │   ├── get_selected_engines_usecase.dart  # Translates settings keys → RTDB stats keys via EngineRegistry
│   │   └── clear_usage_cache.dart             # Invalidates the in-memory cache on demand
│   └── utils/
│       └── usage_constants.dart               # Delegates knownAsr/TranslationEngines to EngineRegistry
├── data/
│   ├── datasources/        # UsageRemoteDataSource (Firestore + RTDB polling)
│   ├── models/             # DTOs: EngineUsageDto, DailyUsageRecordDto
│   └── repositories/       # UsageRepositoryImpl
└── presentation/
    ├── bloc/               # UsageBloc, UsageEvent, UsageState
    ├── screens/            # UsageScreen (main analytics view)
    └── widgets/            # Charts, EngineUsageCard, quota bars, UsageUtils
```

The `usage` feature follows the standard **Clean Architecture (Vertical Slice)** pattern established across all features. See [13 New Screen Setup Guide](../03_guides/13_new_screen_setup_guide.md) for the full pattern reference.

---

## 3. Domain Layer

### Repository Interface
**File**: `lib/features/usage/domain/repositories/usage_repository.dart`

Defines the contract for fetching engine stats and daily history. Kept deliberately minimal and decoupled from any data source.

### `IEngineSelectionSource`
**File**: `lib/core/interfaces/i_engine_selection_source.dart`

A cross-feature interface (defined in `core`, not in `settings`) that exposes the two methods `getSelectedTranslationEngine()` and `getSelectedTranscriptionEngine()`. Implemented by `SettingsRepositoryImpl`. The usage feature depends only on this interface — never directly on `SettingsBloc` or `ISettingsRepository`.

### `GetSelectedEnginesUseCase`
**File**: `lib/features/usage/domain/usecases/get_selected_engines_usecase.dart`

Reads the currently selected ASR and translation engines via `IEngineSelectionSource` (which returns settings keys such as `'google'` or `'whisper-tiny'`), then translates them to **RTDB stats keys** via `EngineRegistry.settingsKeyToStatsKey()`. Returns a `SelectedEngines` value object with `translationStatsKey` and `transcriptionStatsKey`. These stats keys match `EngineUsage.engine` so `UsageScreen` can compare directly without any conversion.

### `ClearUsageCache`
**File**: `lib/features/usage/domain/usecases/clear_usage_cache.dart`

Single-method use-case that calls `UsageRepository.clearCache()`. Injected into `UsageBloc` and called when `LoadUsageStats(refresh: true)` is dispatched (i.e. the user presses the refresh button in the header). Keeps the bloc free of any direct repository dependency.

### `UsageConstants`
**File**: `lib/features/usage/domain/utils/usage_constants.dart`

Delegates `knownAsrEngines` and `knownTranslationEngines` to `EngineRegistry.knownAsrStatsKeys` / `knownTranslationStatsKeys`. No hardcoded lists.

### Entities
**Directory**: `lib/features/usage/domain/entities/`

Plain Dart classes representing usage snapshots. These have **zero dependencies** on Firebase, Flutter, or any data source.

---

## 4. Data Layer

### `UsageRepositoryImpl`
**File**: `lib/features/usage/data/repositories/usage_repository_impl.dart`

Implements `UsageRepository`. Delegates to `UsageRemoteDataSource` for all RTDB REST calls.

**In-memory cache (3-minute TTL):** `getModelUsageStats()`, `getDailyUsageHistory()`, and `getUsageTotals()` all cache their RTDB responses in memory. On repeat visits within 3 minutes the results are returned instantly with no network round-trip. The cache is cleared automatically after any rollover write and on demand via `clearCache()` (called through `ClearUsageCache` when the user explicitly refreshes).

> [!NOTE]
> Live quota numbers (daily/monthly/lifetime tokens) are **not** affected by the cache — they come from `UsageRemoteDataSource`'s background polling timer, which updates independently of the screen.

**DI Registration** (in `lib/core/di/parts/repository_di.dart`):
```dart
sl.registerLazySingleton<UsageRepository>(
  () => UsageRepositoryImpl(),
);
```

---

## 5. Presentation Layer

### BLoC
**Directory**: `lib/features/usage/presentation/bloc/`

Follows the standard BLoC pattern:
- **Events**: `LoadUsageStats` (with optional `refresh: bool`)
- **States**: `UsageInitial`, `UsageLoading`, `UsageLoaded`, `UsageError`
- **BLoC**: Calls use cases and emits states

`UsageLoaded` carries the full dashboard state including:

| Field | Type | Description |
|---|---|---|
| `engineUsage` | `List<EngineUsage>` | Per-engine stats grouped by display name |
| `dailyHistory` | `List<DailyUsageRecord>` | Last 30 days of daily usage |
| `lifetimeTokens` | `int` | All-time character count |
| `monthlyTokens` | `int` | Current calendar-month character count |
| `asrTokens` | `int` | Lifetime ASR character count |
| `translationTokens` | `int` | Lifetime translation character count |
| `tier` | `String` | User's current subscription tier (uppercased) |
| `quotaStatus` | `QuotaStatus?` | Current daily/monthly quota snapshot |
| `selectedTranslationEngine` | `String` | Active translation engine as RTDB stats key (e.g. `'google-translate'`) |
| `selectedTranscriptionEngine` | `String` | Active ASR engine as RTDB stats key (e.g. `'whisper-asr'`) |

`UsageBloc` dependencies: `GetUsageStats`, `GetUsageHistory`, `GetQuotaStatus`, `CheckUsageRollover`, `GetSelectedEnginesUseCase`, `ClearUsageCache`.

**Load strategy:** After rollover completes, `GetUsageStats`, `GetUsageHistory`, and `GetSelectedEnginesUseCase` are fired in parallel via `Future.wait` — cutting load time from ~3 sequential RTDB round-trips to ~1. `LoadUsageStats(refresh: true)` calls `ClearUsageCache` before fetching, bypassing the 3-minute cache.

### Screen
**File**: `lib/features/usage/presentation/screens/usage_screen.dart`

Displays a high-density analytics dashboard consistent with the Omni Bridge design language:
- **Color accent**: `Colors.tealAccent` for ASR, `Color(0xFF6366F1)` (indigo) for translation engines
- **Navigation icon**: `Icons.analytics_rounded`
- **Layout**: Standard `1020px` centered content width
- **Engine highlighting**: The `EngineUsageCard` for the currently active ASR/translation engine is highlighted with a stronger border. `UsageScreen` reads `state.selectedTranslationEngine` and `state.selectedTranscriptionEngine` from `UsageLoaded` and passes `isSelected: e.engine == selectedEngine` to each `EngineUsageCard`. Both fields are already RTDB stats keys, matching `EngineUsage.engine` directly — no conversion needed in the screen.

### Widgets
**Directory**: `lib/features/usage/presentation/widgets/`

| Widget | Purpose |
|---|---|
| `EngineUsageCard` | Per-engine stat card. Accepts `isSelected` param — highlights the border when the engine is currently active. |
| `UsageUtils` | `getDisplayName(statsKey, type)` — delegates to `EngineRegistry.displayNameForStatsKey()`. |
| `UsageDonutChart` | ASR vs translation breakdown pie chart |
| `ModelUsageBarChart` | Per-engine bar chart for relative usage |
| `UsageHistoryChart` | 30-day daily usage line chart |
| `UsageHeader` | Top bar with refresh `IconButton` (dispatches `LoadUsageStats(refresh: true)`) |
| `QuotaUsageBar` | Inline progress bar for daily quota |

---

## 6. Integration Points

| Component | Role |
|-----------|------|
| `SubscriptionRemoteDataSource` | Populates quota and usage fields in Firebase (source of truth for plan/tier) |
| `UsageMetricsRemoteDataSource` | Buffers per-call stats (3s flush) and writes multi-path PATCH to RTDB `model_stats/{statsKey}` and `daily_usage/{date}/models/{statsKey}` |
| `ISubscriptionRepository` | The shared repository that `UsageRepositoryImpl` reads from for engine stats and quota |
| `IEngineSelectionSource` | Core interface implemented by `SettingsRepositoryImpl` — provides selected engine settings keys to `GetSelectedEnginesUseCase` without cross-feature BLoC coupling |
| `EngineRegistry` | `lib/core/constants/engine_registry.dart` — single source of truth for all engine definitions: settings key, RTDB stats key, display name, type. Used by `GetSelectedEnginesUseCase`, `UsageUtils`, `UsageConstants`, `_isEngineInPlan`, and `_engineLimit`. |
| `fl_chart` package | Powers usage visualizations (bar/line charts) |

> [!TIP]
> Because `UsageRepositoryImpl` wraps `ISubscriptionRepository`, there is no extra Firebase cost — the subscription listener is already open. The usage screen simply presents a different view of data already in memory.

> [!IMPORTANT]
> **Engine Key Spaces**: The Flutter settings system uses **settings keys** (e.g. `'google'`, `'riva-nmt'`) while the Python server writes **RTDB stats keys** (e.g. `'google-translate'`, `'riva-grpc-mt'`) to `model_stats/`. These two key spaces are different for every engine except `riva-asr`. All translation between these spaces must go through `EngineRegistry` — never hardcode both sides of this mapping in ad-hoc string comparisons.

---

## Related Docs

- [05 Flutter Architecture](../02_architecture/05_flutter_architecture.md) — BLoC pattern, DI, and all feature modules
- [07 Database Schema](../02_architecture/07_database_schema.md) — Firestore & Realtime DB schema for usage counters
- [16 Monetization Plan](../04_features/16_monetization_plan.md) — Subscription tiers, quotas, and limits
- [13 New Screen Setup Guide](../03_guides/13_new_screen_setup_guide.md) — Pattern reference for adding new feature screens
