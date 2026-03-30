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
    ├── screens/             # SupportScreen, TicketDetailsScreen
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

### Design Aesthetic & Window Management
The `support` feature utilizes **Glassmorphism** heavily through the main `AppTheme` design system (see `lib/core/theme/app_theme.dart`). 
- **Theming**: Directly leverages `AppColors`, `AppSpacing`, and `AppTextStyles` tokens, overriding legacy hardcoded gradients to ensure consistency with the entire app.
- **Layout**: Uses a Split-view dashboard for desktop, ensuring intuitive navigation between different support threads.
- **Window Management**: The `SupportScreen` window sizing rules and positioning are managed centrally by the `MyNavObserver` instead of locally, ensuring smooth resizing transitions when navigating between the overlay and support chat screens.

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
- [13 — New Screen Setup Guide](../03_guides/13_new_screen_setup_guide.md) — UI/UX pattern reference & centralized window routing.
