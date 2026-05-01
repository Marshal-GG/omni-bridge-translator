<!--
 Copyright (c) 2026 Omni Bridge. All rights reserved.
 
 Licensed under the PERSONAL STUDY & LEARNING LICENSE v1.0.
 Commercial use and public redistribution of modified versions are strictly prohibited.
 See the LICENSE file in the project root for full license terms.
-->

# 14 — Usage Analytics Guide

This document describes the `usage` feature module — an in-app analytics dashboard that gives users a live breakdown of their AI engine consumption, quota status, daily activity, and source-language distribution.

## Table of Contents
1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [Domain Layer](#3-domain-layer)
4. [Data Layer](#4-data-layer)
5. [Presentation Layer](#5-presentation-layer)
6. [Language Tracking Pipeline](#6-language-tracking-pipeline)
7. [Integration Points](#7-integration-points)

---

## 1. Overview

The `usage` feature displays per-session and cumulative statistics for AI usage — tokens consumed, daily/monthly quota, per-engine breakdown, a 30-day activity chart, and a top-languages donut. It is read-only from the user's perspective; all writes happen in `UsageMetricsRemoteDataSource` during translation sessions.

**Feature location**: `lib/features/usage/`

---

## 2. Architecture

```
lib/features/usage/
├── domain/
│   ├── entities/
│   │   ├── engine_usage.dart          # Per-engine stats snapshot
│   │   ├── daily_usage_record.dart    # One day of aggregated usage
│   │   ├── language_usage.dart        # Source-language token totals
│   │   └── quota_status.dart          # Daily/monthly quota snapshot
│   ├── repositories/
│   │   ├── usage_repository.dart              # Abstract interface
│   │   └── i_engine_selection_source.dart     # Re-exports core/interfaces/
│   └── usecases/
│       ├── get_usage_stats.dart               # Aggregates engine stats, checks plan access
│       ├── get_usage_history.dart             # Fetches N-day daily usage history
│       ├── get_language_usage.dart            # Fetches per-language token totals
│       ├── get_quota_status.dart              # Current quota snapshot
│       ├── check_usage_rollover.dart          # Archives and resets expired periods
│       ├── get_selected_engines_usecase.dart  # Settings keys → RTDB stats keys
│       └── clear_usage_cache.dart             # Invalidates the in-memory cache
├── data/
│   ├── datasources/
│   │   └── usage_remote_datasource.dart   # RTDB REST reads (stats, history, languages)
│   ├── models/
│   │   ├── engine_usage_dto.dart          # JSON → EngineUsage
│   │   └── daily_usage_record_dto.dart    # JSON → DailyUsageRecord
│   └── repositories/
│       └── usage_repository_impl.dart     # UsageRepository implementation (3-min TTL cache)
└── presentation/
    ├── bloc/
    │   ├── usage_bloc.dart    # Orchestrates load + range change + CSV export
    │   ├── usage_event.dart   # LoadUsageStats · SetDateRange · ExportCsv
    │   └── usage_state.dart   # UsageInitial · UsageLoading · UsageLoaded · UsageError
    ├── screens/
    │   └── usage_screen.dart  # Main analytics view
    └── widgets/
        ├── engine_usage_card.dart  # Per-engine stat card (ACTIVE / LOCKED pill)
        ├── quota_strip.dart        # Two-bar quota widget (Daily amber + Monthly teal)
        ├── stat_cards_grid.dart    # 4-card grid: TODAY / WEEK / MONTH / LIFETIME sparklines
        ├── activity_chart.dart     # 30-day stacked bar chart (ASR + NMT)
        ├── language_pie.dart       # Source-language donut + flag legend
        ├── usage_header.dart       # Title bar with refresh action
        ├── usage_status_bar.dart   # 28 px footer: engine dots + "Updated Ns ago"
        └── usage_utils.dart        # getDisplayName() helper
```

The `usage` feature follows the standard **Clean Architecture (Vertical Slice)** pattern. See [13 New Screen Setup Guide](../03_guides/13_new_screen_setup_guide.md) for the full pattern reference.

---

## 3. Domain Layer

### Repository Interface
**File**: `lib/features/usage/domain/repositories/usage_repository.dart`

| Method | Returns | Notes |
|---|---|---|
| `getModelUsageStats()` | `Future<List<EngineUsage>>` | Per-engine cumulative stats |
| `getDailyUsageHistory({int days})` | `Future<List<DailyUsageRecord>>` | Last N days, sorted oldest-first |
| `getLanguageUsage()` | `Future<List<LanguageUsage>>` | Per-language totals, sorted by tokens descending |
| `getUsageTotals()` | `Future<Map<String, dynamic>>` | Raw `usage/totals` node |
| `clearCache()` | `void` | Invalidates all in-memory caches |
| `quotaStatusStream` | `Stream<QuotaStatus>` | Live quota updates from background poll |
| `currentQuotaStatus` | `QuotaStatus?` | Most recent quota snapshot |
| `engineMonthlyUsage` | `Map<String, int>` | Per-engine subscription-cycle tokens |

### Entities

**`LanguageUsage`** (`lib/features/usage/domain/entities/language_usage.dart`)  
Plain Dart class (Equatable). Fields: `code` (ISO 639-1, e.g. `'en'`), `tokens` (`int`), `calls` (`int`).

**`EngineUsage`** — per-engine stats snapshot. Key computed field: `effectiveTokens` (uses monthly if capped, lifetime otherwise).

**`DailyUsageRecord`** — one day. Fields: `date`, `totalTokens`, `engineTokens: Map<String, int>` (RTDB stats key → tokens).

**`QuotaStatus`** — daily/monthly usage against configured limits. Has `isExceeded`, `isUnlimited`, `hasMonthlyLimit`, `hasPeriodLimit`, `monthlyProgress` helpers.

### Use Cases

**`GetLanguageUsage`** — calls `UsageRepository.getLanguageUsage()`. No parameters.

**`GetSelectedEnginesUseCase`** — reads `IEngineSelectionSource` (returns settings keys like `'whisper-tiny'`) then translates via `EngineRegistry.settingsKeyToStatsKey()`. Returns `SelectedEngines(translationStatsKey, transcriptionStatsKey)`. Both fields match `EngineUsage.engine` directly — no conversion needed in the screen.

**`ClearUsageCache`** — single call to `UsageRepository.clearCache()`. Injected into `UsageBloc`; called on `LoadUsageStats(refresh: true)`.

---

## 4. Data Layer

### `UsageRemoteDataSource`
**File**: `lib/features/usage/data/datasources/usage_remote_datasource.dart`

RTDB reads via `RTDBClient.instance.getRTDBUrl(path)` + `http.get()`. All paths are user-scoped (prefixed `users/{uid}/`).

| Method | RTDB path | Notes |
|---|---|---|
| `getModelUsageStatsRaw(uid)` | `model_stats` | Returns raw JSON map |
| `getDailyUsageHistoryRaw(uid)` | `daily_usage` | Full history; repo trims to N days |
| `getLanguageUsageRaw(uid)` | `usage/totals/languages` | Map of `{code: {tokens, calls}}` |
| `fetchUsageTotals(uid)` | `usage/totals` | Lifetime + period counters |

### `UsageRepositoryImpl`
**File**: `lib/features/usage/data/repositories/usage_repository_impl.dart`

Implements `UsageRepository`. All four fetch methods have a **3-minute in-memory TTL** cache. Cache is cleared on any rollover write and on demand via `clearCache()`.

```
Cache fields:
  _cachedModelStats / _modelStatsCachedAt
  _cachedHistory / _historyCachedAt / _cachedHistoryDays
  _cachedTotals / _totalsCachedAt
  _cachedLanguages / _languagesCachedAt
```

**DI Registration** (`lib/core/di/parts/repository_di.dart`):
```dart
sl.registerLazySingleton<UsageRepository>(() => UsageRepositoryImpl());
```

---

## 5. Presentation Layer

### BLoC
**Directory**: `lib/features/usage/presentation/bloc/`

**Events:**

| Event | Payload | Handler |
|---|---|---|
| `LoadUsageStats` | `refresh: bool` | Fetches all data in parallel; clears cache if refresh |
| `SetDateRange` | `range: UsageRange` | Re-fetches history + languages for the new range |
| `ExportCsv` | — | Writes a `.csv` file to `~/Downloads/` |

**`UsageRange`** enum: `sevenDays(7, '7D')` · `thirtyDays(30, '30D')` · `ninetyDays(90, '90D')` · `oneYear(365, '1Y')`

**`UsageLoaded` fields:**

| Field | Type | Source |
|---|---|---|
| `engineUsage` | `List<EngineUsage>` | `GetUsageStats` |
| `dailyHistory` | `List<DailyUsageRecord>` | `GetUsageHistory(days: range.days)` |
| `languages` | `List<LanguageUsage>` | `GetLanguageUsage` |
| `lifetimeTokens` | `int` | `quotaStatus.lifetimeTokensUsed` |
| `monthlyTokens` | `int` | `quotaStatus.monthlyTokensUsed` |
| `weeklyTokens` | `int` | `quotaStatus.weeklyTokensUsed` |
| `asrTokens` | `int` | Sum of ASR engine tokens from `GetUsageStats` |
| `translationTokens` | `int` | Sum of translation engine tokens |
| `tier` | `String` | Uppercased from `quotaStatus.tier` |
| `quotaStatus` | `QuotaStatus?` | `GetQuotaStatus.current` |
| `selectedTranslationEngine` | `String` | RTDB stats key from `GetSelectedEnginesUseCase` |
| `selectedTranscriptionEngine` | `String` | RTDB stats key |
| `range` | `UsageRange` | Current date range selection |
| `loadedAt` | `DateTime` | `DateTime.now()` at load time |
| `exportPath` | `String?` | Set after successful CSV export |
| `exportError` | `String?` | Set on export failure |

**Load strategy:** `GetUsageStats`, `GetUsageHistory`, `GetSelectedEnginesUseCase`, and `GetLanguageUsage` run in parallel via `Future.wait` — one network round-trip window for all four.

### Screen
**File**: `lib/features/usage/presentation/screens/usage_screen.dart`

Full-bleed dark background (`#161616 → #0F0F0F` vertical gradient). No centered max-width constraint — content stretches edge-to-edge with `16 px` horizontal padding.

**Layout (top-to-bottom):**
1. `buildUsageHeader(context)` — pinned outside scroll, bottom border
2. `QuotaStrip` — daily + monthly bars (only when `quotaStatus != null`)
3. `StatCardsGrid` — TODAY / THIS WEEK / THIS MONTH / LIFETIME
4. Row: `ActivityChart` | `LanguagePie` (50/50 split)
5. Translation engines section (grid of `EngineUsageCard`)
6. ASR engines section (grid of `EngineUsageCard`)
7. `UsageStatusBar` — pinned footer

**Week-over-week trend** — `_buildEngineSection` computes `changePct` per engine by comparing `dailyHistory` tokens for the last 7 days vs the preceding 7 days. `null` when either window has zero data. Passed as `trendChangePct` to `EngineUsageCard`.

**Section headers** — show right-aligned aggregate: `"N engines · X.XK tokens"`. Use `NumberFormat.compact()`.

**Engine card `isSelected`** — `e.engine == state.selectedTranslationEngine` (or transcription). Both sides are already RTDB stats keys; no conversion needed.

### Widgets

| Widget | File | Purpose |
|---|---|---|
| `QuotaStrip` | `quota_strip.dart` | Two-column (Daily amber / Monthly teal) quota bars with shimmering gradient, plan pill, reset countdowns, Upgrade button |
| `StatCardsGrid` | `stat_cards_grid.dart` | 4 glass cards (TODAY / THIS WEEK / THIS MONTH / LIFETIME) with sparklines drawn from `dailyHistory` — no `Random()`, no hardcoded fallbacks |
| `ActivityChart` | `activity_chart.dart` | 30-day stacked bar chart — ASR indigo + Translation teal. Hover state dims non-hovered bars. Summary row: active days, average, peak. Empty state when `dailyHistory.isEmpty`. |
| `LanguagePie` | `language_pie.dart` | SVG donut + flag legend, top 5 + "Other" bucket. Empty state until language data arrives. |
| `EngineUsageCard` | `engine_usage_card.dart` | Per-engine card with glowing dot, big mono token count, `tokens · X% share`, 4 px animated progress bar, `avg Nms · p99 Nms` footer. **ACTIVE** pill (top-right) for selected engine. **LOCKED** pill for engines not in user's plan. Uniform height regardless of token count. |
| `UsageStatusBar` | `usage_status_bar.dart` | 28 px pinned footer. Engine status dots (translation teal, ASR indigo, LIVE/OFFLINE). "Updated Ns ago" counter updated every 1s. |
| `UsageHeader` | `usage_header.dart` | `OmniHeader` titled "Usage Analytics" with a `refresh` icon that dispatches `LoadUsageStats(refresh: true)`. |
| `UsageUtils` | `usage_utils.dart` | `getDisplayName(statsKey, type)` — delegates to `EngineRegistry.displayNameForStatsKey()`. |

---

## 6. Language Tracking Pipeline

Source-language statistics are collected passively during translation sessions and exposed in the `LanguagePie` widget.

### Write path

**File**: `lib/core/data/datasources/usage_metrics_remote_datasource.dart`

`logModelUsage(stats)` buffers per-language token counts in `_languageBuffer: Map<String, Map<String, int>>`. Language resolution order:

1. Use `stats['source_lang']` if present and not `'auto'` or empty.
2. Fall back to `stats['detected_lang']` — populated by Riva ASR when auto-detection is active.
3. Skip if both are absent or `'auto'`.

On the 3-second flush timer, `flushUsage()` writes:
- `usage/totals/languages/{code}/tokens` — lifetime total
- `usage/totals/languages/{code}/calls` — lifetime call count
- `daily_usage/{YYYY-MM-DD}/languages/{code}/tokens`
- `daily_usage/{YYYY-MM-DD}/languages/{code}/calls`

All updates are part of the existing multi-path PATCH — no extra RTDB write.

**Auto-detection fix** (`lib/features/translation/data/datasources/asr_websocket_datasource.dart`):  
When the server sends a `source_lang_override` (Whisper auto-detecting the source language), `AsrWebSocketClient._sourceLang` is updated immediately. This ensures subsequent `usage_stats` messages for that session are tagged with the detected language code, not `'auto'`.

### Read path

`UsageRemoteDataSource.getLanguageUsageRaw(uid)` reads `usage/totals/languages` via REST. `UsageRepositoryImpl.getLanguageUsage()` maps each `{code: {tokens, calls}}` entry to a `LanguageUsage` entity, sorts by `tokens` descending, and caches with the same 3-minute TTL.

### Supported display names and flags

`LanguagePie._displayName()` and `_flagFor()` have built-in mappings for 20 ISO 639-1 codes: `en`, `es`, `fr`, `de`, `ja`, `zh`, `ko`, `pt`, `it`, `ru`, `ar`, `hi`, `nl`, `sv`, `pl`, `tr`, `uk`, `vi`, `th`, `id`. Unknown codes show `🌐` and the code uppercased.

---

## 7. Integration Points

| Component | Role |
|---|---|
| `UsageMetricsRemoteDataSource` | Buffers per-call stats (3 s flush), writes `model_stats/`, `daily_usage/`, and `usage/totals/languages/` to RTDB. **Single write path for all usage data.** |
| `UsageRemoteDataSource` | Read-only REST client for the usage feature screen. Reads `model_stats/`, `daily_usage/`, and `usage/totals/languages/`. |
| `AsrWebSocketClient` | Updates `_sourceLang` on `source_lang_override` events — ensures language stats are tagged with the detected code, not `'auto'`. |
| `IEngineSelectionSource` | Core interface implemented by `SettingsRepositoryImpl`. Provides selected engine settings keys to `GetSelectedEnginesUseCase` without cross-feature BLoC coupling. |
| `EngineRegistry` | `lib/core/constants/engine_registry.dart` — canonical mapping between settings keys, RTDB stats keys, display names, and types. All engine lookups must go through this registry. |

> [!IMPORTANT]
> **Engine Key Spaces**: Settings keys (e.g. `'google'`, `'whisper-tiny'`) and RTDB stats keys (e.g. `'google-translate'`, `'whisper-asr'`) are distinct namespaces for most engines. All translation between them must go through `EngineRegistry`.

> [!NOTE]
> Live quota numbers (daily/monthly/lifetime tokens) are **not** cached — they come from `UsageRemoteDataSource`'s background polling timer, which runs independently of the screen load.

---

## Related Docs

- [05 Flutter Architecture](../02_architecture/05_flutter_architecture.md) — BLoC pattern, DI, and all feature modules
- [07 Database Schema](../02_architecture/07_database_schema.md) — RTDB schema for usage counters including `usage/totals/languages`
- [22 Token Estimation](../02_architecture/22_token_estimation.md) — How characters are counted per engine
- [16 Monetization Plan](../04_features/16_monetization_plan.md) — Subscription tiers, quotas, and limits
- [13 New Screen Setup Guide](../03_guides/13_new_screen_setup_guide.md) — Pattern reference for adding new feature screens
