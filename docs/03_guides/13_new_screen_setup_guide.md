<!--
 Copyright (c) 2026 Omni Bridge. All rights reserved.
 
 Licensed under the PERSONAL STUDY & LEARNING LICENSE v1.0.
 Commercial use and public redistribution of modified versions are strictly prohibited.
 See the LICENSE file in the project root for full license terms.
-->

# 13 — New Screen Setup Guide

This guide provides a detailed walkthrough for adding a new screen (and its associated feature logic) to the Omni Bridge project following the established **Clean Architecture (Layered)** and **Vertical Slice (Feature-Driven)** patterns.

## Table of Contents
1. [Feature Directory Structure](#1-feature-directory-structure)
2. [Domain Layer (Business Logic)](#2-domain-layer-business-logic)
3. [Data Layer (Implementation)](#3-data-layer-implementation)
4. [Presentation Layer (UI & State)](#4-presentation-layer-ui--state)
5. [Window Management (window_manager.dart)](#5-window-management-window_managerdart)
6. [UI Structure & Premium Aesthetics](#6-ui-structure--premium-aesthetics)
   - [6A. Dashboard Shell](#a-dashboard-shell)
   - [6B. Global Widget Library (use first)](#b-global-widget-library--check-before-writing-any-ui)
   - [6C. Header (OmniHeader)](#c-header-omniheader)
   - [6D. Engine Status Badges](#d-engine-status-badges-modelstatusindicator)
   - [6E. Layout Constraints](#e-layout-constraints)
7. [Dependency Injection (DI) Registration](#7-dependency-injection-di-registration)
8. [Navigation & Routing](#8-navigation--routing)
9. [Error Handling & Failures](#9-error-handling--failures-functional-approach)
10. [Testing Template](#10-testing-template)
11. [Assets & Localization](#11-assets--localization)
12. [UI Design Language & Consistency](#12-ui-design-language--consistency)
13. [Lint Compliance](#13-lint-compliance)
14. [End-to-End Implementation Checklist](#14-end-to-end-implementation-checklist)

---

## 1. Feature Directory Structure

All new features should reside in `lib/features/[feature_name]/`. Replace `[feature_name]` with your feature (e.g., `analytics`, `profile`, `support`).

```text
lib/features/[feature_name]/
├── data/
│   ├── datasources/        # Remote/Local API clients
│   ├── models/             # Data Transfer Objects (DTOs) / JSON mapping
│   └── repositories/       # Repository implementations
├── domain/
│   ├── entities/           # Core business objects (Plain Dart)
│   ├── repositories/       # Repository interfaces (Abstract classes)
│   └── usecases/           # Single-purpose logic classes
└── presentation/
    ├── blocs/              # BLoC, Events, and States
    ├── screens/            # Main screen widget
    └── widgets/            # Feature-specific sub-widgets
```

---

## 2. Domain Layer (Business Logic)

The Domain layer is the "Brain" and should have **zero dependencies** on Flutter or data implementation.

### A. Entity
Define your core data object in `domain/entities/[entity_name].dart`.
```dart
class MyEntity {
  final String id;
  final String title;

  const MyEntity({required this.id, required this.title});
}
```

### B. Repository Interface
Define the contract in `domain/repositories/[feature_name]_repository.dart`.
```dart
abstract class IMyFeatureRepository {
  Future<MyEntity> getData();
}
```

### C. UseCase
Create single-purpose classes in `domain/usecases/get_data_usecase.dart`.
```dart
class GetDataUseCase {
  final IMyFeatureRepository repository;
  GetDataUseCase(this.repository);

  Future<MyEntity> call() async {
    return await repository.getData();
  }
}
```

---

## 3. Data Layer (Implementation)

### A. Model
Extends the Entity to add JSON serialization in `data/models/[model_name]_model.dart`.
```dart
class MyModel extends MyEntity {
  MyModel({required super.id, required super.title});

  factory MyModel.fromJson(Map<String, dynamic> json) {
    return MyModel(id: json['id'], title: json['title']);
  }
}
```

### B. Repository Implementation
Implements the domain interface in `data/repositories/[feature_name]_repository_impl.dart`.
```dart
class MyFeatureRepositoryImpl implements IMyFeatureRepository {
  final MyRemoteDataSource dataSource;
  MyFeatureRepositoryImpl(this.dataSource);

  @override
  Future<MyEntity> getData() => dataSource.fetchData();
}
```

---

## 4. Presentation Layer (UI & State)

### A. BLoC (State Management)
Create the standard trio in `presentation/blocs/`:
- `[feature_name]_event.dart`: `abstract class MyEvent {}`
- `[feature_name]_state.dart`: `abstract class MyState {}` (Initial, Loading, Loaded, Error)
- `[feature_name]_bloc.dart`: Handles events and emits states.

```dart
class MyBloc extends Bloc<MyEvent, MyState> {
  final GetDataUseCase getDataUseCase;

  MyBloc({required this.getDataUseCase}) : super(MyInitial()) {
    on<LoadDataEvent>((event, emit) async {
      emit(MyLoading());
      try {
        final data = await getDataUseCase();
        emit(MyLoaded(data));
      } catch (e) {
        emit(MyError(e.toString()));
      }
    });
  }
}
```

#### Event Transformers (`bloc_concurrency`)

For events that can fire concurrently, use `bloc_concurrency` transformers to prevent race conditions:

```dart
import 'package:bloc_concurrency/bloc_concurrency.dart';

MyBloc(...) : super(MyInitial()) {
  // Save events queue — never overlap
  on<SaveEvent>(_onSave, transformer: sequential());

  // Refresh events drop if already loading
  on<RefreshEvent>(_onRefresh, transformer: droppable());
}
```

| Transformer | Use when |
|-------------|----------|
| `sequential()` | User can trigger multiple saves/submits — process in order, never overlap |
| `droppable()` | Rapid triggers (auth changes, tab switches) — only the first matters |
| *(default)* | Independent events with no concurrency concern |
```

### B. Screen
The main entry point in `presentation/screens/[feature_name]_screen.dart`. All dashboard-level screens should be wrapped in the `AppDashboardShell`.

```dart
class MyScreen extends StatelessWidget {
  const MyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppDashboardShell(
      currentRoute: AppRouter.myFeature,
      header: const OmniHeader(title: 'My New Feature'),
      child: BlocBuilder<MyBloc, MyState>(
        builder: (context, state) {
          if (state is MyLoading) return const Center(child: CircularProgressIndicator());
          if (state is MyLoaded) return _buildContent(state.data);
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
```

---

## 5. Window Management (`window_manager.dart`)

The project uses a centralized `window_manager.dart` for handling window positioning, sizing, and transparency across different features.

### A. Define Window Presets
Add a new entry to the `WindowMode` enum and a new positioning function in `lib/core/platform/window_manager.dart` if your screen requires a specific size.

> [!IMPORTANT]
> Always set **both** `appWindow.minSize` (bitsdojo_window) **and** `windowManager.setMinimumSize` (window_manager). They are separate native packages — setting only one is ignored by the other.

**Step 1 — add to enum:**
```dart
enum WindowMode { none, login, startup, forceUpdate, translation, history, dashboard, subscription, myFeature }
```

**Step 2 — add a position function:**
```dart
/// Sets the window to a centered panel for the MyFeature screen.
Future<void> setToMyFeaturePosition() async {
  if (_currentWindowMode == WindowMode.myFeature) return; // guard — no-op on re-entry
  _currentWindowMode = WindowMode.myFeature;

  await _transitionWindow(() async {           // fades out → resizes → fades in
    await windowManager.setResizable(true);
    appWindow.minSize = const Size(1000, 500);          // bitsdojo constraint
    await windowManager.setMinimumSize(const Size(1000, 500)); // window_manager constraint
    await windowManager.setSize(const Size(1140, 850));
    appWindow.alignment = Alignment.center;
    await windowManager.center();
    await windowManager.setAlwaysOnTop(false); // almost always false — see note below
  });
}
```

> [!WARNING]
> **`setAlwaysOnTop`**: Only set to `true` for screens that must float above all other OS windows during active use (e.g., the translation overlay, splash/onboarding). Dashboard and utility screens **must** use `false`. Setting it to `true` on a utility screen is a UX defect — the window can't be hidden behind other apps.
>
> Example of the split: `setToStartupPosition()` uses `true`; the identical `setToForceUpdatePosition()` uses `false` because the force-update screen is a full blocking page, not a live overlay.

### B. Trigger Positioning on Navigation

Window resizing is driven by `MyNavigatorObserver`. Register your route in `_handleWindowState` **and** add it to the `didPop` list so the previous window size is restored when the user navigates back.

```dart
// lib/core/routes/my_nav_observer.dart

// 1. didPop — restore window on back-navigation
void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
  final name = route.settings.name;
  if (name == AppRouter.myFeature /* ... other routes ... */) {
    if (previousRoute != null) _handleWindowState(previousRoute);
  }
}

// 2. _handleWindowState — apply window preset
void _handleWindowState(Route<dynamic> route) {
  final name = route.settings.name;
  // ...
  } else if (name == AppRouter.myFeature) {
    setToMyFeaturePosition();
  }
  // ...
}
```

> [!TIP]
> The `_currentWindowMode` guard inside each preset function means navigating to a screen you're already on is a no-op — no flicker, no redundant native calls.

---

## 6. UI Structure & Premium Aesthetics

To maintain the "Omni Bridge look," always use the standard shell and layout primitives.

### A. Dashboard Shell
Instead of manual boilerplate, use `AppDashboardShell`. It automatically provides:
1.  **Window Handling**: Via `OmniWindowLayout` (Native borders & custom title bar).
2.  **Global UI Layer**: Via `ShellOverlay` (Common overlays and feedback).
3.  **Global Navigation**: Via `AppNavigationRail` (Sidebar integration).

```dart
@override
Widget build(BuildContext context) {
  return AppDashboardShell(
    currentRoute: AppRouter.myFeature,
    header: const OmniHeader(
      title: 'Feature Title',
      icon: Icons.auto_awesome_rounded,
      accentColor: AppColors.accentCyan,
    ),
    child: _buildBody(),
  );
}
```

> [!NOTE]
> `AppDashboardShell` is the high-level layout. If you are building a smaller utility window that does NOT need the sidebar, use `OmniWindowLayout` directly.

### B. Global Widget Library — check before writing any UI

**Before writing any inline `Container`, `Row`, or `Scaffold` that recreates a known pattern, check `lib/core/widgets/` first.** Recreating these as private widgets or inline code is a defect, not a style choice.

| Widget | Import | Use for |
|---|---|---|
| `OmniWindowLayout` | `core/widgets/omni_window_layout.dart` | Every top-level screen — `Scaffold(transparent) + WindowBorder + surface bg` |
| `OmniHeader` | `core/widgets/omni_header.dart` | Draggable 32 px title bar with icon, title, minimize & close |
| `OmniCard` | `core/widgets/omni_card.dart` | Tinted card container — pass `baseColor` + `hasGlow: true` for glow |
| `OmniChip` | `core/widgets/omni_chip.dart` | Feature tags, version strings, engine name labels |
| `OmniBadge` | `core/widgets/omni_badge.dart` | Ticket status, category labels — heavier weight than `OmniChip` |
| `OmniTintedButton` | `core/widgets/omni_tinted_button.dart` | Action buttons needing tinted bg + hover scale + loading state |
| `OmniSearchBar` | `core/widgets/omni_search_bar.dart` | All search `TextField`s — wired to the global `InputDecorationTheme` |
| `OmniProgressBar` | `core/widgets/omni_progress_bar.dart` | Quota / usage progress bars |
| `OmniDropdown` | `core/widgets/omni_dropdown.dart` | All dropdown selectors |
| `OmniSegmentedControl` | `core/widgets/omni_segmented_control.dart` | Tab-style 2–4 option toggle |
| `OmniVersionChip` | `core/widgets/omni_version_chip.dart` | Auto-reads `PackageInfo` and renders `OMNI BRIDGE vX.X.X` |
| `OmniBranding` | `core/widgets/omni_branding.dart` | Logo + wordmark lockup |
| `OmniCopyright` | `core/widgets/omni_copyright.dart` | Footer copyright line |

**Anti-patterns:**
- ❌ `Scaffold(backgroundColor: transparent) + WindowBorder(...)` → `OmniWindowLayout`
- ❌ Manual 32 px `Row` with `MoveWindow + MinimizeWindowButton + CloseWindowButton` → `OmniHeader`
- ❌ `Container(decoration: BoxDecoration(color: color.withValues(alpha:0.05), ...))` → `OmniCard`
- ❌ Inline tinted pill/chip `Container` → `OmniChip` / `OmniBadge`
- ❌ Custom hover-animated tinted button → `OmniTintedButton`
- ❌ Raw `TextField` as a search input → `OmniSearchBar`

### C. Header (`OmniHeader`)

All screens pass their header via `AppDashboardShell.header` or directly as the first child of `OmniWindowLayout`. **Always use `OmniHeader`** — do not rebuild the button row manually.

```dart
OmniHeader(
  title: 'My Feature',
  icon: Icons.my_feature_icon,          // optional
  accentColor: AppColors.accentCyan,    // optional — tints icon
  onBack: () => Navigator.pop(context), // optional — shows back button
)
```

> [!IMPORTANT]
> Never wrap `MinimizeWindowButton` or `CloseWindowButton` (bitsdojo widgets) in a `SizedBox`. They have their own internal sizing — constraining them causes them to appear vertically off-center. `OmniHeader` already handles this correctly internally.

### D. Engine Status Badges (`ModelStatusIndicator`)

The shared `ModelStatusIndicator` widget (`lib/core/widgets/model_status_indicator.dart`) renders a compact status badge (Ready / Loading / Error / etc.) for any model.

| Param | Type | Default | Purpose |
|---|---|---|---|
| `status` | `Map<String, dynamic>?` | required | Model status map from the server (`status`, `ready`, `message`, `progress`). Pass `null` to render "Offline". |
| `compact` | `bool` | `false` | When `true`, hides the text label and shows only the icon — used in tight spaces like the overlay header. |
| `greyed` | `bool` | `false` | When `true`, forces all badge colours to `Colors.white24` and suppresses spinners — used for engines that are locked (DB kill switch) or unavailable on the user's current tier. |

```dart
// Fully visible status (settings panel)
ModelStatusIndicator(status: state.modelStatuses['llama'])

// Compact icon-only (overlay header)
ModelStatusIndicator(status: state.modelStatuses['llama'], compact: true)

// Greyed out — engine locked or not in user's plan
ModelStatusIndicator(
  status: state.modelStatuses['llama'],
  compact: true,
  greyed: isDbDisabled || !userHasAccess,
)
```

### E. Layout Constraints
For premium visual balance, center the main content in a fixed-width container to avoid stretching on wide monitors. The target width depends on the screen's content density:

| Screen type | Typical content width |
|---|---|
| Standard dashboard screens (Settings, Usage, About) | `1020px` |
| Card-heavy screens (Subscription) | `900px` — wider window (`WindowMode.subscription`, 1340×820) keeps cards compact |

```dart
Widget _buildBody() {
  return SingleChildScrollView(
    child: Center(
      child: SizedBox(
        width: 1020, // adjust per screen type (see table above)
        child: Column(...),
      ),
    ),
  );
}
```

---

## 7. Dependency Injection (DI) Registration

Register all layers in `lib/core/di/injection.dart`. Follow the established order:
1. **Data Sources** (Singletons)
2. **Repositories** (Singletons)
3. **UseCases** (Lazy Singletons)
4. **BLoCs** (Factories)

```dart
// Repositories
sl.registerLazySingleton<IMyFeatureRepository>(() => MyFeatureRepositoryImpl(sl()));

// Use Cases
sl.registerLazySingleton(() => GetDataUseCase(sl()));

// Blocs
sl.registerFactory(() => MyBloc(getDataUseCase: sl()));
```

---

### B. Register Sidebar Item (Required)

To make your screen accessible, you must add it to the `AppNavigationRail` items.

1.  Open `lib/features/shell/presentation/widgets/app_navigation_rail.dart`.
2.  Add your route to the appropriate section (Top items, Middle, or Bottom).

```dart
_NavTile(
  icon: Icons.my_feature_icon,
  label: 'My Feature',
  isActive: currentRoute == AppRouter.myFeature,
  isExpanded: isExpanded,
  onTap: () => _navigate(context, AppRouter.myFeature),
),
```

### C. Register Header Resizing (Required)
Finally, add your route name to the window transition logic in `lib/core/routes/my_nav_observer.dart`:

1.  **didPop List**: Add `AppRouter.myFeature` to the list of names that trigger a resize on pop.
2.  **_handleWindowState**: Add a case that calls your `setToMyFeaturePosition()` method.

This ensures the window expands when you enter the screen and shrinks correctly when you go back.

---

## 9. Error Handling & Failures (Functional Approach)

Omni Bridge uses the `dartz` package's `Either<Failure, T>` return type for Repositories and UseCases to avoid excessive try-catch blocks in the UI layer.

- **Failure**: Defined in `lib/core/error/failures.dart`. Use `ServerFailure`, `CacheFailure`, or create a feature-specific failure.
- **Repository Pattern**:
  ```dart
  Future<Either<Failure, MyEntity>> getData() async {
    try {
      final remoteData = await remoteDataSource.getData();
      return Right(remoteData.toEntity());
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
  ```

---

## 10. Testing Template

Maintain high coverage by testing UseCases and BLoCs using `mocktail` and `bloc_test`.

### A. UseCase Test
```dart
test('should get data from the repository', () async {
  // arrange
  when(() => mockRepo.getData()).thenAnswer((_) async => Right(tEntity));
  // act
  final result = await useCase(NoParams());
  // assert
  expect(result, Right(tEntity));
});
```

### B. BLoC Test
```dart
blocTest<MyBloc, MyState>(
  'emits [Loading, Loaded] when data is fetched successfully',
  build: () {
    when(() => mockUseCase(any())).thenAnswer((_) async => Right(tData));
    return MyBloc(useCase: mockUseCase);
  },
  act: (bloc) => bloc.add(FetchDataEvent()),
  expect: () => [
    MyLoading(),
    MyLoaded(data: tData),
  ],
);
```

---

## 11. Assets & Localization

### A. Strings
Add new user-facing strings to **localization** files if the project uses internationalization. For simple screens, use a central `Constants` class or `UsageUtils` file.

### B. Assets
- **Icons**: Place new PNG/SVG assets in `assets/app/icons/` or `assets/app/images/`. Register them in `pubspec.yaml`.
- **Usage**: Access them using `Image.asset('assets/app/icons/image_name.png')`.

---

## 12. UI Design Language & Consistency

To maintain a professional, high-density, and consistent look, every new feature must adhere to the following design system rules:

### A. Consistent Branding & Nomenclature
Do **not** use raw model IDs (e.g., `google_api`) in the UI. Always use a utility (like `UsageUtils.getDisplayName`) to map backend IDs to user-facing labels.
- **ASR/Transcription**: Standardize on names like "NVIDIA Riva", "Whisper [Size] (Offline)", "Google Online".
- **Translation**: Standardize on names like "Google Translate (Free)", "Llama 3.1 8B (Accurate, Slower)".

### B. Color Coding System
To maintain visual distinction and branding consistency, every feature category and core navigation icon has a reserved accent color.

#### 1. Feature Category Accents
- **ASR / Transcription**: Use **Indigo** accents (`Colors.indigo`).
- **Translation**: Use **Teal** accents (`Colors.teal`).
- **Administrative / Usage**: Use **Purple** or **Blue-Grey**.

#### 2. Navigation Icon Color Map (Reserved)
The following colors are **reserved** for their specific screens in the header popup menu and should **not** be reused for other top-level screen icons:

| Screen / Feature | Accent Color | Iconic Representation |
| :--- | :--- | :--- |
| **Configuration** | `Colors.tealAccent` | `Icons.handyman` / Lang Badge |
| **Subscription & Quota** | `Colors.lightBlueAccent` | `Icons.workspace_premium_rounded` |
| **Usage Statistics** | `Colors.orangeAccent` | `Icons.bar_chart_rounded` |
| **Account Settings** | `Colors.purpleAccent` | `Icons.manage_accounts_rounded` |
| **About Omni Bridge** | `Colors.amberAccent` | `Icons.info_outline_rounded` |
| **History Panel** | `Colors.greenAccent` | `Icons.history` |
| **Mini Mode Collapse** | `Colors.amberAccent` | `Icons.compress` |

> [!IMPORTANT]
> **Accent Uniqueness**: When adding a new top-level feature or navigation button to the header menu, pick a distinct accent color from the Material palette that is **not** already in the map above. This ensures users can learn to navigate by color cues.

### C. High-Density Layout Standards
Omni Bridge prioritizes a premium, info-dense interface over "airy" mobile-first designs.
- **Internal Padding**: Use `4px` or `8px` internal padding for cards and rows.
- **MainAxisSize.min**: Ensure columns and rows wrap tightly around their content to avoid vertical dead space.
- **Aspect Ratios**: For Grids, use `childAspectRatio` values that optimize for horizontal space without causing text overflow (e.g., `2.8` for engine cards).

### D. Typography & Header Standards
- **Secondary Screens** (Settings, Account, Usage, History):
    - **Header Title**: `fontSize: 11`, `fontWeight: FontWeight.w500`, `color: Colors.white38`.
    - **Header Height**: `32px`.
- **Main Screen** (Translator):
    - **Header Title**: `fontSize: 12`, `fontWeight: FontWeight.normal`, `color: Colors.white70`.
    - **Header Height**: `32px`.
- **Model Labels**: Descriptive, not just the engine name (e.g., "7B (Fastest)" instead of "llama").

### E. Layout Constraints
Always center the core content within a fixed-width container for desktop views. This prevents the UI from becoming unreadable on ultra-wide monitors. Standard screens use **1020px**; card-heavy screens like Subscription use **900px** paired with a wider `WindowMode` (see Section 5).

---

## 13. Lint Compliance

The project enforces a custom `analysis_options.yaml`. New code **must** pass `flutter analyze` before merging. Key rules to follow:

### Always use `Future<void>` for async functions
```dart
// ❌ triggers avoid_void_async
void _onSave(SaveEvent event, Emitter<MyState> emit) async { ... }

// ✅ correct
Future<void> _onSave(SaveEvent event, Emitter<MyState> emit) async { ... }
```

> [!NOTE]
> Exception: override methods whose parent class declares `void` (e.g., `WindowListener.onWindowClose`, `TrayListener.onTrayIconMouseDown`) — suppress with `// ignore: avoid_void_async`.

### Await or explicitly discard Futures
```dart
// ❌ triggers unawaited_futures
someAsyncCall();

// ✅ option 1 — await it
await someAsyncCall();

// ✅ option 2 — intentional fire-and-forget
unawaited(someAsyncCall());  // import 'dart:async'

// ✅ option 3 — fire-and-forget inside a fold/callback (any Future<T>)
someAsyncCall().ignore();
```

### Cancel subscriptions
```dart
// ❌ triggers cancel_subscriptions
StreamSubscription<X> _sub = stream.listen(...);
// (never cancelled)

// ✅ cancel in dispose / BLoC close
@override
Future<void> close() {
  _sub.cancel();
  return super.close();
}
```

### Use `AppLogger`, not `print()`
```dart
// ❌ triggers avoid_print
print('Debug info');

// ✅
AppLogger.i('Debug info', tag: 'MyFeature');
```

### `unused_import` is an error (blocks CI)
Remove all unused imports immediately — the analyzer treats them as errors and CI will fail.

---

## 14. End-to-End Implementation Checklist

- [ ] **Directory structure**: Files placed in `lib/features/[name]/{data, domain, presentation}`.
- [ ] **Data layer**: `RepositoryImpl` and `DataSource` implemented.
- [ ] **Domain layer**: `Entity`, `IRepository`, and `UseCase` defined.
- [ ] **Error Handling**: UseCases and Repositories return `Either<Failure, T>`.
- [ ] **BLoC**: Events, States, and Logic implemented (using specific states like `Loading`, `Loaded`, `Error`).
- [ ] **Injection**: DataSources, Repositories, UseCases, and BLoCs registered in `injection.dart`.
- [ ] **Router**: Constant defined and route registered (with `BlocProvider`) in `app_router.dart`.
- [ ] **Sidebar**: `_NavTile` added to `AppNavigationRail` with proper active state check.
- [ ] **Window Management**: `WindowMode` enum entry added, preset function added (with `_transitionWindow` + `setAlwaysOnTop(false)`), registered in `my_nav_observer.dart`.
- [ ] **Global widgets**: No `OmniWindowLayout`, `OmniHeader`, `OmniCard`, `OmniChip`, `OmniBadge`, `OmniTintedButton`, or `OmniSearchBar` patterns recreated inline — checked `lib/core/widgets/` first.
- [ ] **UI Structure**: Screen uses `AppDashboardShell` with proper `currentRoute` and `OmniHeader`.
- [ ] **Design Language**: Colors match feature category (ASR: Indigo, Trans: Teal). Model names match standard nomenclature.
- [ ] **Performance**: Vertical dead space minimized using `MainAxisSize.min` and high-density padding.
- [ ] **Testing**: Unit tests for UseCases and BLoC tests implemented in `test/features/[name]/`.
- [ ] **Lint**: `flutter analyze` passes with no issues — no unused imports, `Future<void>` on async functions, `unawaited()` or `await` on all Futures, `AppLogger` not `print()`.
- [ ] **Concurrency**: Events that can fire simultaneously use `sequential()` or `droppable()` from `bloc_concurrency`.
