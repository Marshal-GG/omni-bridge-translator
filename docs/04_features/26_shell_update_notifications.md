<!--
 Copyright (c) 2026 Omni Bridge. All rights reserved.
 
 Licensed under the PERSONAL STUDY & LEARNING LICENSE v1.0.
 Commercial use and public redistribution of modified versions are strictly prohibited.
 See the LICENSE file in the project root for full license terms.
-->

# 26 — Shell Update Notifications

This document describes how in-app update notifications are surfaced to the user and how the forced-update blocking screen works.

## Table of Contents
1. [Overview](#1-overview)
2. [UpdateNotifier](#2-updatenotifier)
3. [Nav Rail — Update Tile](#3-nav-rail--update-tile)
4. [Force Update Screen](#4-force-update-screen)
5. [Launch Logic](#5-launch-logic)
6. [Debug Simulation](#6-debug-simulation)

---

## 1. Overview

The update system has two distinct modes:

| Mode | Trigger | UI Element | Dismissible |
|---|---|---|---|
| **Soft update** | `isForced: false` | `_UpdateNavTile` in the nav rail | Yes — user can dismiss |
| **Forced update** | `isForced: true` | Full-screen `ForceUpdateScreen` at `/force_update` | No — blocks the app |

Both modes are driven by a single source of truth: `UpdateNotifier.instance`.

> [!NOTE]
> The `ShellOverlay` header badge that previously appeared alongside the nav tile has been removed. The nav rail is now the sole UI entry point for soft updates, keeping the chrome clean.

---

## 2. UpdateNotifier

**File**: `lib/features/startup/presentation/notifiers/update_notifier.dart`

A singleton `ValueNotifier<bool>` populated by the **presentation layer** from a returned `UpdateInfo` (post-A3, the data layer never writes to it directly).

**Who calls `setAvailable()`:**

| Caller | When |
|---|---|
| `StartupBloc._onInitialize` | App launch — destructures `(String, UpdateInfo?)` from `AppInitializer.initAsync()` and populates the notifier if an update is found, before navigating to the splash next route. |
| `ConnectivityService._handleConnectivityChange` | Offline → online recovery — re-runs `sl<IUpdateRepository>().checkForUpdate()` and populates the notifier if a new version surfaces while the user is mid-session. |
| `AboutBloc._onCheckUpdate` | User taps "Check for updates" in the About screen — populates the notifier so the nav rail tile appears even if startup found nothing. |

> [!IMPORTANT]
> **Do not call `UpdateNotifier.instance.setAvailable()` from `update_remote_datasource.dart` or any other data-layer file.** That was the pre-A3 pattern; it's now an A6 (data→presentation) violation. The datasource returns `UpdateInfo`; presentation owns the notifier.

```dart
// Signal that an update is available (soft)
UpdateNotifier.instance.setAvailable(
  '2.1.0',                           // latestVersion
  'https://github.com/.../releases', // releaseUrl
  download: 'https://.../Setup.exe', // downloadUrl (optional, direct installer)
  forced: false,                     // isForced — set true to trigger ForceUpdateScreen
  message: null,                     // forceUpdateMessage — shown on ForceUpdateScreen
);

// Dismiss (only works when isForced == false)
UpdateNotifier.instance.dismiss();
```

**Fields:**

| Field | Type | Description |
|---|---|---|
| `value` | `bool` | Whether an update is available |
| `latestVersion` | `String?` | Version string shown in the UI (e.g. `2.1.0`) |
| `releaseUrl` | `String?` | GitHub releases page URL |
| `downloadUrl` | `String?` | Direct `.exe` installer URL |
| `isForced` | `bool` | If `true`, routes to `ForceUpdateScreen`; disables dismiss |
| `forceUpdateMessage` | `String?` | Custom message displayed on `ForceUpdateScreen` |

---

## 3. Nav Rail — Update Tile

**Files:**
- `lib/features/shell/presentation/widgets/app_navigation_rail.dart` — hosts `_UpdateNavTile` and `_launchUpdate()`
- Widget: `_UpdateNavTile` (private, defined at the bottom of the file)

The tile is inserted into the `Column` of `AppNavigationRail` just above the collapse toggle, wrapped in a `ListenableBuilder` so it appears and disappears reactively:

```dart
ListenableBuilder(
  listenable: UpdateNotifier.instance,
  builder: (context, _) {
    if (!UpdateNotifier.instance.value) return const SizedBox.shrink();
    return _UpdateNavTile(
      isExpanded: isExpanded,
      isForced: UpdateNotifier.instance.isForced,
      version: UpdateNotifier.instance.latestVersion,
      onTap: () => _launchUpdate(),
    );
  },
),
```

### `_UpdateNavTile` behaviour

- Uses a `SingleTickerProviderStateMixin` `AnimationController` to pulse the background opacity between `0.3` and `0.9` (1.6 s loop).
- **Collapsed mode**: Icon centred with `Spacer` widgets either side.
- **Expanded mode**: Icon + "Update" / "Critical Update" label + version string + download icon.
- Colour is `AppColors.accentCyan` for normal updates, `AppColors.accentRed` for forced.
- Hover state handled via `MouseRegion` + local `_hovered` bool → `AnimatedContainer`.

---

## 4. Force Update Screen

**File**: `lib/features/startup/presentation/screens/force_update_screen.dart`  
**Route**: `AppRouter.forceUpdate` → `/force_update`

When `AppInitializer.initAsync()` returns a route of `/force_update`, `StartupBloc` populates `UpdateNotifier` (with `forced: true`) and emits `StartupNavigateToForceUpdate` — `SplashScreen` then `pushReplacementNamed`s to `/force_update`. This screen blocks the entire app until the user downloads and installs the new version.

### UI

Built entirely from the global `lib/core/widgets/` library — no inline styling:

```
OmniWindowLayout
 └── Column
      ├── OmniHeader(title: 'Update Required', icon: system_update_alt_rounded)
      ├── Divider
      └── SingleChildScrollView
           └── Center → ConstrainedBox(maxWidth: AppSpacing.maxDashboardWidth)
                └── OmniCard(baseColor: accentRed, hasGlow: true)
                     ├── OmniCard(icon only — inner icon container)
                     ├── Text (display style — "Update Required")
                     ├── OmniChip(label: 'vX.X.X', color: accentRed)
                     ├── Text (forceUpdateMessage or default)
                     └── UpdateDownloadButton(primary: true)
```

### Window behaviour

`ForceUpdateScreen` uses its **own** `WindowMode` — `WindowMode.forceUpdate` — handled by `setToForceUpdatePosition()` in `window_manager.dart`.

> [!IMPORTANT]
> `setToForceUpdatePosition()` calls `setAlwaysOnTop(false)`. This is intentional. The force-update screen is a full-window UI, not a live overlay — the user must be able to alt-tab to their browser to download the update. **Do not** merge it back into `setToStartupPosition()`, which uses `setAlwaysOnTop(true)` for splash/onboarding.

```dart
// window_manager.dart
Future<void> setToForceUpdatePosition() async {
  if (_currentWindowMode == WindowMode.forceUpdate) return;
  _currentWindowMode = WindowMode.forceUpdate;

  await _transitionWindow(() async {
    await windowManager.setResizable(true);
    appWindow.minSize = const Size(600, 500);
    await windowManager.setMinimumSize(const Size(600, 500));
    await windowManager.setSize(const Size(880, 700));
    appWindow.alignment = Alignment.center;
    await windowManager.center();
    await windowManager.setAlwaysOnTop(false); // ← not an overlay
  });
}
```

```dart
// my_nav_observer.dart — _handleWindowState
} else if (name == AppRouter.forceUpdate) {
  setToForceUpdatePosition();
}
```

---

## 5. Launch Logic

The nav tile calls `_launchUpdate()` (static method on `AppNavigationRail`). The `UpdateDownloadButton` on `ForceUpdateScreen` handles its own URL launch internally via the same pattern:

```dart
Future<void> _launchUpdate() async {
  final notifier = UpdateNotifier.instance;
  // Prefer a direct installer URL; fall back to the releases page.
  final url = notifier.downloadUrl?.isNotEmpty == true
      ? notifier.downloadUrl!
      : notifier.releaseUrl ??
          'https://github.com/Marshal-GG/omni-bridge-translator/releases';
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
```

> **Note:** `url_launcher` must remain in `pubspec.yaml`.

---

## 6. Debug Simulation

Because `UpdateNotifier` starts as `false` and is only set by the production version-check, the update UI is never visible during development without a manual trigger.

**Solution:** `AppDashboardShell.initState()` contains a `kDebugMode`-gated `Future.microtask`:

**File**: `lib/features/shell/presentation/widgets/app_dashboard_shell.dart`

```dart
@override
void initState() {
  super.initState();
  if (kDebugMode) {
    Future.microtask(
      () => UpdateNotifier.instance.setAvailable(
        '2.0.0-preview',
        'https://github.com/Marshal-GG/omni-bridge-translator/releases',
        download:
            'https://github.com/Marshal-GG/omni-bridge-translator/releases/download/v2.0.0/OmniBridge-Setup.exe',
      ),
    );
  }
}
```

This block is **compiled away entirely in release builds** because `kDebugMode` is a `const bool` that the tree-shaker removes. It is safe to leave in permanently.

To simulate a **forced** update during development, pass `forced: true`:

```dart
UpdateNotifier.instance.setAvailable(
  '2.0.0-preview',
  'https://github.com/...',
  forced: true,
  message: 'This version is no longer supported.',
);
```

---

## Related Docs

- [05 — Flutter Architecture](../02_architecture/05_flutter_architecture.md) — Shell widget hierarchy
- [13 — New Screen Setup Guide](../03_guides/13_new_screen_setup_guide.md) — Window management patterns (`WindowMode`, `setAlwaysOnTop`)
- [18 — Support Feature Guide](./18_support_feature_guide.md) — Support dashboard and ActiveTicketsPage
