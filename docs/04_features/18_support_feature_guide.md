<!--
 Copyright (c) 2026 Omni Bridge. All rights reserved.

 Licensed under the PERSONAL STUDY & LEARNING LICENSE v1.0.
 Commercial use and public redistribution of modified versions are strictly prohibited.
 See the LICENSE file in the project root for full license terms.
-->

# 18 — Support Feature Guide

This document describes the `support` feature module — an integrated helpdesk that provides users with real-time chat support, ticket history, and automated system diagnosis.

## Table of Contents
1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [Domain Layer](#3-domain-layer)
4. [Data Layer](#4-data-layer)
5. [Presentation Layer](#5-presentation-layer)
6. [System Snapshots](#6-system-snapshots)

---

## 1. Overview

The `support` feature allows users to communicate with the Omni Bridge support team directly within the application. It includes a WhatsApp-style chat interface, ticket management, and a tool to generate and send encrypted system "snapshots" for rapid troubleshooting.

**Feature location**: `lib/features/support/`

---

## 2. Architecture

```text
lib/features/support/
├── domain/
│   ├── entities/            # Ticket, Message, Snapshot
│   ├── repositories/        # ISupportRepository (abstract)
│   └── usecases/            # SendSupportMessage, GetTicketHistory, etc.
├── data/
│   ├── datasources/         # SupportRemoteDataSource, SupportLocalDataSource
│   └── repositories/        # SupportRepositoryImpl
└── presentation/
    ├── blocs/               # SupportBloc, Events, States
    ├── screens/
    │   ├── support_screen.dart        # Shell + BLoC routing
    │   ├── active_tickets_page.dart   # Default dashboard (no ticket selected)
    │   └── ticket_details_screen.dart # Individual ticket chat view
    └── widgets/             # ChatBubble, TicketListTile, SnapshotPreview
```

---

## 3. Domain Layer

### Key UseCases
- **`SendSupportMessage`**: Dispatches a new message to an active ticket.
- **`GetTicketHistory`**: Fetches the list of all past and current support requests.
- **`GetSystemSnapshot`**: Gathers non-PII system data (OS version, app logs, server status) for debugging.
- **`SubmitFeedback`**: Allows users to send quick ratings or comments without opening a formal ticket.

---

## 4. Data Layer

### `SupportRemoteDataSource`
**File**: `lib/features/support/data/datasources/support_remote_datasource.dart`
Communicates with the Support backend (Firebase Firestore for ticketing and a REST API for message delivery).

### `SupportLocalDataSource`
**File**: `lib/features/support/data/datasources/support_local_datasource.dart`
Handles local persistence of draft messages and a cache of the last 10 support tickets for offline viewing.

---

## 5. Presentation Layer

### BLoC
**Directory**: `lib/features/support/presentation/blocs/`
Manages the real-time state of the chat. It listens for new message arrives via a stream from the repository and handles the pagination of ticket history.

### SupportScreen
**File**: `lib/features/support/presentation/screens/support_screen.dart`

The top-level shell for the feature, implemented as a stateless widget. It reads the initial active tab from `ModalRoute.of(context)?.settings.arguments`, provisions a local `SupportBloc`, and wraps its content in a `BlocBuilder`. By passing the active tab index down to `AppDashboardShell`, it keeps the global navigation sidebar perfectly in sync.

It routes to the correct sub-screen depending on the internal conversational state:

| State | Rendered Screen |
|---|---|
| No ticket selected (default) | `ActiveTicketsPage` |
| Ticket selected | `TicketDetailsScreen` |

### ActiveTicketsPage
**File**: `lib/features/support/presentation/screens/active_tickets_page.dart`

The entry-point dashboard shown when the user navigates to Support with no active ticket selected. Strictly design-system compliant — uses `AppColors`, `AppTextStyles`, `AppShapes`, and `AppSpacing` tokens alongside global widgets from `lib/core/widgets/` (`OmniCard`, `OmniChip`, `OmniBadge`).

**Key UI sections:**
- **Summary strip** — three stat cards showing open, in-progress, and resolved counts.
- **Section header** — "Active Tickets" title with a count badge.
- **Ticket cards** — interactive cards with status-based accent colouring and hover effects. Tapping a card dispatches a `SupportSelectTicketEvent` to the BLoC to navigate to `TicketDetailsScreen`.

> **Important:** Do **not** add hardcoded colours, custom gradients, or inline card/chip reproductions to this file. All colour values must come from `AppColors` (or `withValues(alpha:)` calls on those tokens); all status pills and card containers must use `OmniChip`/`OmniBadge` and `OmniCard` respectively.

### Design Aesthetic & Window Management
The `support` feature leverages the **Glassmorphism** design language through the main `AppTheme` (see `lib/core/theme/app_theme.dart`) and the shared global widget library (`lib/core/widgets/`).
- **Theming**: Uses `AppColors`, `AppSpacing`, and `AppTextStyles` tokens. All card and chip patterns use `OmniCard` and `OmniChip`/`OmniBadge` — never inline `Container` reproductions.
- **Layout**: Split-view dashboard for desktop, ensuring intuitive navigation between different support threads.
- **Window Management**: `SupportScreen` window sizing is managed centrally by `MyNavObserver` → `setToDashboardPosition()`, ensuring smooth resize transitions when navigating between screens.

---

## 6. System Snapshots

One of the unique capabilities of the `support` feature is the **System Snapshot**. When a user reports a bug:
1. The `GetSystemSnapshotUseCase` is triggered.
2. It captures the contents of `PythonServerManager` logs and core app settings.
3. The data is bundled, anonymized (PII stripped), and attached to the ticket as a JSON payload for the support team.

---

## Related Docs

- [05 — Flutter Architecture](../02_architecture/05_flutter_architecture.md) — Feature-driven structure and BLoC reference
- [07 — Database Schema](../02_architecture/07_database_schema.md) — Ticketing schema details in Firestore
- [13 — New Screen Setup Guide](../03_guides/13_new_screen_setup_guide.md) — UI/UX pattern reference & centralized window routing
- [26 — Shell Update Notifications](../04_features/26_shell_update_notifications.md) — Update tile and badge implementation
