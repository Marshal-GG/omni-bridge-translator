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
│   ├── entities/           # Usage data entities
│   └── repositories/       # UsageRepository (abstract interface)
├── data/
│   └── repositories/       # UsageRepositoryImpl
└── presentation/
    ├── bloc/               # UsageBloc, Events, States
    ├── screens/            # UsageScreen (main analytics view)
    └── widgets/            # Charts, stat cards, breakdown widgets
```

The `usage` feature follows the standard **Clean Architecture (Vertical Slice)** pattern established across all features. See [13 New Screen Setup Guide](../03_guides/13_new_screen_setup_guide.md) for the full pattern reference.

---

## 3. Domain Layer

### Repository Interface
**File**: `lib/features/usage/domain/repositories/usage_repository.dart`

Defines the contract for fetching usage data. The interface is kept deliberately minimal to stay decoupled from the underlying data source (Firestore / Realtime DB).

### Entities
**Directory**: `lib/features/usage/domain/entities/`

Plain Dart classes representing usage snapshots. These have **zero dependencies** on Firebase, Flutter, or any data source.

---

## 4. Data Layer

### `UsageRepositoryImpl`
**File**: `lib/features/usage/data/repositories/usage_repository_impl.dart`

Implements `UsageRepository`. Rather than holding its own data source, it **delegates to `ISubscriptionRepository`**, which already holds real-time subscription and quota data populated by `SubscriptionRemoteDataSource`. This avoids duplicating Firebase listeners.

**DI Registration** (in `lib/core/di/injection.dart`):
```dart
sl.registerLazySingleton<UsageRepository>(
  () => UsageRepositoryImpl(subscriptionRepository: sl()),
);
```

> [!NOTE]
> `UsageRepositoryImpl` depends on `ISubscriptionRepository` — ensure the subscription repository is registered **before** `UsageRepository` in `injection.dart`.

---

## 5. Presentation Layer

### BLoC
**Directory**: `lib/features/usage/presentation/bloc/`

Follows the standard BLoC pattern:
- **Events**: Trigger data loads or refreshes
- **States**: `UsageInitial`, `UsageLoading`, `UsageLoaded`, `UsageError`
- **BLoC**: Calls `UsageRepository` and emits states

### Screen
**File**: `lib/features/usage/presentation/screens/`

Displays a high-density analytics dashboard consistent with the Omni Bridge design language:
- **Color accent**: `Colors.orangeAccent` (reserved per the [Design Language Guide](../03_guides/13_new_screen_setup_guide.md#b-color-coding-system))
- **Navigation icon**: `Icons.bar_chart_rounded`
- **Layout**: Standard `1020px` centered content width

### Widgets
**Directory**: `lib/features/usage/presentation/widgets/`

Encapsulates individual UI components (e.g., `fl_chart`-powered charts, quota progress bars, per-engine stat cards) to keep the Screen widget lean.

---

## 6. Integration Points

| Component | Role |
|-----------|------|
| `SubscriptionRemoteDataSource` | Populates quota and usage fields in Firebase (source of truth) |
| `UsageMetricsRemoteDataSource` | Tracks per-session token counts and byte usage to Firebase Realtime DB |
| `ISubscriptionRepository` | The shared repository that `UsageRepositoryImpl` reads from |
| `fl_chart` package | Powers usage visualizations (bar/line charts) |

> [!TIP]
> Because `UsageRepositoryImpl` wraps `ISubscriptionRepository`, there is no extra Firebase cost — the subscription listener is already open. The usage screen simply presents a different view of data already in memory.

---

## Related Docs

- [05 Flutter Architecture](../02_architecture/05_flutter_architecture.md) — BLoC pattern, DI, and all feature modules
- [07 Database Schema](../02_architecture/07_database_schema.md) — Firestore & Realtime DB schema for usage counters
- [16 Monetization Plan](../04_features/16_monetization_plan.md) — Subscription tiers, quotas, and limits
- [13 New Screen Setup Guide](../03_guides/13_new_screen_setup_guide.md) — Pattern reference for adding new feature screens
