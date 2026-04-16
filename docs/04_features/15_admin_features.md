# 15 — Admin Features

This document provides a technical overview of the administrative code in the Omni Bridge project, detailing how administrative capabilities are managed and implemented.

---

## 1. Admin Identity & Authorization

Admin status is determined **at the app-shell level** via `AppShellBloc`, not locally inside any screen or widget. This ensures the nav rail and all downstream UI react consistently across the entire session.

### Detection Flow

```
User signs in
 └─ AppShellBloc._onUserChanged() fires
     └─ resets isAdmin: false immediately
     └─ calls _checkAdminStatus(user)
         └─ CheckAdminStatusUseCase.call(email)
             └─ IAuthRepository.isAdmin(email)
                 └─ AuthRemoteDataSource.checkAdminStatus(email)
                     └─ reads system/admins → emails[]
                     └─ returns emails.contains(email)
         └─ add(AppShellAdminStatusChanged(isAdmin: result))
             └─ AppShellState.isAdmin updated
                 └─ AppNavigationRail rebuilds → admin tile appears
```

### Key Files

| File | Role |
|---|---|
| `lib/features/auth/domain/usecases/check_admin_status_usecase.dart` | Use case — single responsibility: `call(email) → Future<bool>` |
| `lib/features/auth/domain/repositories/i_auth_repository.dart` | Interface — `isAdmin(String email)` method |
| `lib/features/auth/data/repositories/auth_repository_impl.dart` | Delegates to `AuthRemoteDataSource.checkAdminStatus()` |
| `lib/features/auth/data/datasources/auth_remote_datasource.dart` | Reads `system/admins → emails[]` from Firestore |
| `lib/features/shell/presentation/blocs/app_shell_bloc.dart` | Orchestrates check on `AppShellUserChanged`; holds `isAdmin` in state |
| `lib/features/shell/presentation/blocs/app_shell_state.dart` | `isAdmin: bool = false` field |
| `lib/features/shell/presentation/blocs/app_shell_event.dart` | `AppShellAdminStatusChanged({required bool isAdmin})` event |

### Admin Whitelist Storage

```
Firestore: system/admins → { emails: ["admin@example.com", ...] }
```

The bootstrap admin (`marshalgcom@gmail.com`) is also hardcoded in `firestore.rules` for initial setup and recovery.

---

## 2. Admin Navigation Entry Point

**File**: `lib/features/shell/presentation/widgets/app_navigation_rail.dart`

The nav rail conditionally renders an **Admin tile** at the bottom of the navigation list. It is only shown when `AppShellState.isAdmin == true`. The tile uses an amber accent colour to distinguish it from regular nav items.

```dart
if (state.isAdmin) ...[
  const SizedBox(height: AppSpacing.xs),
  _NavTile(
    icon: Icons.admin_panel_settings_rounded,
    label: 'Admin',
    isActive: currentRoute == AppRouter.admin,
    accentColor: Colors.amberAccent,
    onTap: () => _navigate(context, AppRouter.admin),
  ),
],
```

`buildWhen` in the `BlocBuilder` includes `prev.isAdmin != curr.isAdmin` so the rail rebuilds when admin status changes (e.g. after sign-in).

---

## 3. Admin Screen

**File**: `lib/features/auth/presentation/screens/admin/admin_screen.dart`

A dedicated dashboard screen that wraps the existing `AdminPanel` widget inside `AppDashboardShell`. Registered as `/admin` in `AppRouter`.

```
/admin → AdminScreen → AppDashboardShell → AdminPanel
```

The route is accessible to any user who knows the path, but the `AdminPanel` widget performs its own Firestore check on `initState` and renders `SizedBox.shrink()` for non-admins — providing a secondary defence-in-depth gate at the UI level.

---

## 4. Administrative Panel (`AdminPanel`)

**File**: `lib/features/auth/presentation/screens/account/components/admin_panel.dart`

The `AdminPanel` widget is the UI for all admin operations. It performs a local `_checkAdminAccess()` on `initState` (reads `system/admins`) before rendering any content.

### Key Components

| Component | Description |
|---|---|
| `_AdminIdentitySection` | Read/write the `system/admins` email whitelist. Add or remove admins instantly. |
| User List | `FutureBuilder` fetching all `users` collection documents |
| User Search | `TextField` for local filter by name or email |
| Plan Manager Card | Shown when a user is selected — `ActionChip`s call `setTierForOtherUser(uid, tier)` to promote/demote in real-time |
| System Config | Seeds or resets the full `system/monetization` document — see fields below |

### System Config Seed Data

**Seed System Config** writes the following top-level fields to `system/monetization` (merge, not overwrite):

| Field | Purpose |
|---|---|
| `tiers` | Per-tier quotas, pricing, allowed models, rate limits, display features |
| `order` | Tier display order (`["free", "trial", "pro", "enterprise"]`) |
| `popular` | Which tier gets the "Popular" badge |
| `plan_ids` | Maps tier IDs → Razorpay plan IDs used by `createSubscription` function |
| `function_urls.create_subscription` | Cloud Run URL of the `createSubscription` function |
| `model_overrides` | Per-engine display names, types, kill switches |
| `usage_poll_interval_seconds` | How often the app polls RTDB usage (default: 30s) |
| `fallback_engine` | Engine to use when a paid engine's cap is exceeded (default: `google`) |
| `upgrade_prompts` | Contextual upsell copy per feature gate |
| `announcements` | In-app banner config (active flag, message, target tiers) |
| `app_version` | Force-update minimum version, changelog URL |

> **When to re-seed**: After switching Razorpay plans from test to production, update `plan_ids` in `admin_panel.dart` and tap Seed System Config again. The `function_urls` value does not change between environments.

---

## 5. Administrative Actions

**File**: `lib/features/subscription/data/datasources/subscription_remote_datasource.dart`

- **`setTierForOtherUser(String uid, String tier)`** — writes `tier` to `users/{uid}` in Firestore. Triggered by the Plan Manager ActionChips. Firestore Security Rules enforce that only admin-listed emails can write to other users' documents.
- **`setTierDebug(String tier)`** — debug-only shortcut that targets the signed-in user. Visible only in `kDebugMode`.
- **`resetTrialDebug()` / `activateFreshTrialDebug()` / `activateExpiredTrialDebug()`** — debug helpers to test trial flows without waiting. Visible only in `kDebugMode`.

Changes to `system/monetization` take effect immediately for all connected clients via the real-time Firestore listener in `SubscriptionRemoteDataSource._listenToMonetizationConfig()`.

---

## 6. Security Architecture

Security is enforced at the **database level** via Firestore Security Rules — client-side checks are convenience gates only.

### Key Protections

- Users cannot modify their own `tier`, `subscriptionSince`, or `paymentProvider`
- Only admin-listed emails can write to `system/*` documents
- The bootstrap admin (`marshalgcom@gmail.com`) is hardcoded in `firestore.rules` for initial setup and recovery
- `AdminPanel` performs its own local `_isAdmin` check as a secondary UI gate — even if a non-admin navigates directly to `/admin`, they see an empty widget
