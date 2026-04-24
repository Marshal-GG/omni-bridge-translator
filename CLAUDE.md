# CLAUDE.md

Project-level instructions for Claude Code. Read this before doing work.

## Design system

When generating any UI, motion, or marketing asset, **read [DESIGN.md](DESIGN.md) first**. It mirrors `lib/core/theme/app_theme.dart` and adds motion, iconography, component, and video-export rules. Do not invent colors, easings, or durations — pick from the tables there.

## Global widget library — check before building

**Before writing any UI primitive inline, check `lib/core/widgets/` first.** Recreating these as private widgets or inline `Container`s is a bug, not a style choice.

| Widget | Import path | Use for |
|---|---|---|
| `OmniWindowLayout` | `core/widgets/omni_window_layout.dart` | Every top-level screen — wraps `Scaffold + WindowBorder + surface bg` |
| `OmniHeader` | `core/widgets/omni_header.dart` | Draggable 32 px title bar with icon, title, minimize & close buttons |
| `OmniCard` | `core/widgets/omni_card.dart` | Any tinted card container — pass `baseColor` + `hasGlow: true` for glow |
| `OmniChip` | `core/widgets/omni_chip.dart` | Feature tags, engine names, version labels, metadata pills |
| `OmniBadge` | `core/widgets/omni_badge.dart` | Ticket status, category labels — smaller/heavier than `OmniChip` |
| `OmniTintedButton` | `core/widgets/omni_tinted_button.dart` | Action buttons needing tinted bg + hover scale + loading state |
| `OmniSearchBar` | `core/widgets/omni_search_bar.dart` | All search inputs — uses global `InputDecorationTheme` automatically |
| `OmniProgressBar` | `core/widgets/omni_progress_bar.dart` | Quota / usage progress bars |
| `OmniDropdown` | `core/widgets/omni_dropdown.dart` | All dropdown selectors |
| `OmniSegmentedControl` | `core/widgets/omni_segmented_control.dart` | Tab-style toggle between 2–4 options |
| `OmniVersionChip` | `core/widgets/omni_version_chip.dart` | Auto-reads `PackageInfo` and renders the app version label |
| `OmniBranding` | `core/widgets/omni_branding.dart` | Logo + wordmark lockup |
| `OmniCopyright` | `core/widgets/omni_copyright.dart` | Footer copyright line |

**Rules:**
- `OmniWindowLayout` replaces any manual `Scaffold(backgroundColor: transparent) + WindowBorder(...)` block.
- `OmniHeader` replaces any manual 32 px `Row` with `MoveWindow + MinimizeWindowButton + CloseWindowButton`.
- `OmniCard` replaces any `Container(decoration: BoxDecoration(color: color.withValues(alpha: 0.05), border: ...))` card pattern.
- `OmniChip` / `OmniBadge` replace any inline tinted pill/chip `Container`.
- `OmniTintedButton` replaces any custom hover-animated tinted button.
- `OmniSearchBar` replaces any raw `TextField` used as a search input.

## Strict architecture — zero tolerance

Vertical slice clean architecture. No exceptions.

- **Vertical slice** — each feature owns its own `domain/`, `data/`, `presentation/`. Never reach across feature boundaries directly — go through repository interfaces or use-cases.
- **Dependency direction** — `presentation → domain ← data`. Presentation never imports data layer classes. Data never imports presentation.
- **BLoC only in presentation** — BLoCs / Cubits live in `presentation/bloc/`. Domain use-cases are plain Dart classes with no Flutter imports.
- **Use-cases own business logic** — BLoCs call use-cases, not repositories directly.
- **Repository interfaces in `domain/`**, concrete impls in `data/repositories/`. BLoCs and use-cases depend on the interface, never the impl.
- **DI via `get_it` (`sl<T>()`) only** — never instantiate repositories, datasources, or BLoCs with `new` outside `core/di/`. No `.instance` singletons outside the data layer.
- **`core/` is framework-level only** — DI, navigation, platform, theme, utils. No feature-specific business logic.
- **No cross-feature imports** between `data/` directories. Shared contracts go through `core/` or a shared domain interface.

Before adding anything, confirm it belongs in the layer you're placing it in. If unsure, ask.

## Git workflow

- **Never commit without being asked.** Even at natural "done" milestones — only prepare or suggest a commit message, never run `git commit`. Wait for the user to say "commit" or "create commit msg".
- **No self-promotion in commit messages.** Never add `Co-Authored-By: Claude…` or any Claude branding to commits.

## Window management

All window positioning is centralised in `lib/core/platform/window_manager.dart`. **Never call `windowManager.*` directly from a screen or widget.**

### Rules

- Every top-level screen needs a matching `WindowMode` enum value and a `setTo*Position()` function.
- Register it in `lib/core/routes/my_nav_observer.dart` (`_handleWindowState`) so it fires on route push.
- Always guard with `if (_currentWindowMode == WindowMode.xxx) return;` to skip redundant transitions.
- Wrap all `windowManager` calls inside `_transitionWindow(() async { ... })` — never call them outside it.

### `setAlwaysOnTop` — reserved for overlays only

| Screen type | `setAlwaysOnTop` |
|---|---|
| Splash / Onboarding (`setToStartupPosition`) | ✅ `true` — must stay above other apps |
| Translation overlay (`setToOverlayPosition`) | ✅ `true` — lives above the target app |
| Dashboard / feature screens | ❌ `false` |
| `ForceUpdateScreen` (`setToForceUpdatePosition`) | ❌ `false` — user must alt-tab to their browser to download |

> **Do not** merge `ForceUpdateScreen` back into `setToStartupPosition()`. They are separate `WindowMode`s intentionally.

### Adding a new screen

```dart
// 1. window_manager.dart — add enum value
enum WindowMode { ..., myNewScreen }

// 2. window_manager.dart — add positioning function
Future<void> setToMyNewScreenPosition() async {
  if (_currentWindowMode == WindowMode.myNewScreen) return;
  _currentWindowMode = WindowMode.myNewScreen;
  await _transitionWindow(() async {
    await windowManager.setSize(const Size(900, 640));
    await windowManager.center();
    await windowManager.setAlwaysOnTop(false);
  });
}

// 3. my_nav_observer.dart — register route
} else if (name == AppRouter.myNewScreen) {
  setToMyNewScreenPosition();
}
```

See `docs/03_guides/13_new_screen_setup_guide.md` §5 for the full checklist.

## Tooling

- **Never use `mcp__dart__analyze_files`** — the tool is bugged. Use `Bash` to run `flutter analyze` or `dart analyze` instead.
- **Verification bar** — after any Dart edit, `flutter analyze` must report **zero issues**. "Compiles in my editor" is not done.
- **Test stack** — `mocktail` (not `mockito`), `bloc_test` for BLoCs. Shared mocks live at `test/helpers/test_mocks.dart`.

## Code conventions

- **Logging** — always `AppLogger.i / .e / .w / .d`. Never `print` or `debugPrint` — they pollute release builds.
- **Feature barrels** — when adding a public class to `lib/features/<feature>/`, update the barrel `lib/features/<feature>/<feature>.dart`. Consumers import the barrel, not individual files.
- **Don't touch generated files** — `firebase_options.dart`, any `*.g.dart`, `pubspec.lock`, or files with "GENERATED" headers. Regenerate via the right tool instead of hand-editing.
- **Windows-only** — don't add iOS / Android / macOS platform code or `Platform.isXxx` conditionals. The app targets Windows 10 / 11 desktop only.

## Flutter ↔ Python lockstep

The app has a Flutter client and a Python FastAPI server in `server/`. If a change touches the WebSocket payload shape (commands, events, quota fields, engine IDs), **both sides must be updated in the same commit**:

- Flutter: `lib/features/translation/data/datasources/` (transport) + relevant BLoCs
- Python: `server/src/network/handlers/` + any affected model/dispatcher

Testing only one side ships a broken app.

## Documentation map

- Architecture: [docs/02_architecture/05_flutter_architecture.md](docs/02_architecture/05_flutter_architecture.md)
- Project structure: [docs/01_core/03_project_structure.md](docs/01_core/03_project_structure.md)
- Feature docs: [docs/04_features/](docs/04_features/)
- Pre-launch TODO: [docs/05_maintenance/23_pre_launch_todo.md](docs/05_maintenance/23_pre_launch_todo.md)
