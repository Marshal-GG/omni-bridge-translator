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
7. [Dependency Injection (DI) Registration](#7-dependency-injection-di-registration)
8. [Navigation & Routing](#8-navigation--routing)
9. [Checklist](#9-checklist)

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

### B. Screen
The main entry point in `presentation/screens/[feature_name]_screen.dart`. Use `BlocBuilder` to react to state changes.

```dart
class MyScreen extends StatelessWidget {
  const MyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Feature')),
      body: BlocBuilder<MyBloc, MyState>(
        builder: (context, state) {
          if (state is MyLoading) return const Center(child: CircularProgressIndicator());
          if (state is MyLoaded) return Text(state.data.title);
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
Add a new positioning function in `lib/core/platform/window_manager.dart` if your screen requires a specific size.

> [!IMPORTANT]
> Always set **both** `appWindow.minSize` (bitsdojo_window) **and** `windowManager.setMinimumSize` (window_manager). They are separate native packages — setting only one is ignored by the other.

```dart
/// Sets the window to a centered panel for the MyFeature screen
Future<void> setToMyFeaturePosition() async {
  await windowManager.setResizable(true);
  appWindow.minSize = const Size(1000, 500);          // bitsdojo constraint
  await windowManager.setMinimumSize(const Size(1000, 500)); // window_manager constraint
  await windowManager.setSize(const Size(1140, 850));
  appWindow.alignment = Alignment.center;
  await windowManager.center();
  await windowManager.setAlwaysOnTop(false);
}
```

### B. Trigger Positioning on Navigation
Call the positioning logic when the BLoC is initialized or when navigating to the screen.

```dart
// In app_router.dart or the BLoC constructor
setToMyFeaturePosition();
```

---

## 6. UI Structure & Premium Aesthetics

To maintain the "Omni Bridge look," always wrap your screen in the standard boilerplate.

### A. Window Wrapper
Use `WindowBorder` (from `bitsdojo_window`) to ensure the custom title bar is draggable and consistent.

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.transparent,
    body: WindowBorder(
      color: Colors.white10,
      width: 1,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF161616), Color(0xFF0F0F0F)],
          ),
        ),
        child: Column(
          children: [
            buildMyFeatureHeader(context),
            const Divider(height: 1, color: Colors.white10),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    ),
  );
}
```

### B. Draggable Header
Create a header widget in `presentation/widgets/[feature]_header.dart`.

> [!IMPORTANT]
> **Never** wrap `MinimizeWindowButton` or `CloseWindowButton` in a `SizedBox`. These bitsdojo widgets have their own internal sizing — constraining them causes them to render vertically centered (appearing "floating" in the header). Place them **directly** in the Row.

```dart
Widget buildMyFeatureHeader(BuildContext context) {
  return SizedBox(
    height: 32,
    child: Row(
      children: [
        // Optional: back button (standard Flutter widget — SizedBox wrapper is fine)
        SizedBox(
          width: 32,
          height: 32,
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, size: 15, color: Colors.white38),
            splashRadius: 16,
            padding: EdgeInsets.zero,
          ),
        ),
        const Icon(Icons.my_icon, size: 14, color: Colors.tealAccent),
        const SizedBox(width: 8),
        const Text(
          'My Feature',
          style: TextStyle(
            color: Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(child: MoveWindow()), // fills remaining space, enables drag
        MinimizeWindowButton(          // ← NO SizedBox wrapper
          colors: WindowButtonColors(iconNormal: Colors.white38),
        ),
        CloseWindowButton(             // ← NO SizedBox wrapper
          colors: WindowButtonColors(
            iconNormal: Colors.white38,
            mouseOver: Colors.redAccent,
          ),
          onPressed: () => appWindow.close(),
        ),
      ],
    ),
  );
}
```

### C. Layout Constraints
For premium visual balance, center the main content in a fixed-width container (usually **1020px**) to avoid stretching on wide monitors.

```dart
Widget _buildBody() {
  return SingleChildScrollView(
    child: Center(
      child: SizedBox(
        width: 1020, // Standard wide layout
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

## 8. Navigation & Routing

### A. Define Route Name
Add a constant in `lib/core/navigation/app_router.dart`.
```dart
static const String myFeature = '/my-feature';
```

### B. Register Route
Add a case to the `generateRoute` switch statement. 

> [!IMPORTANT]
> **Scoping**: Always wrap the screen in a `BlocProvider` here. This ensures the BLoC is localized to this route and disposed of when the user leaves.

```dart
case myFeature:
  return MaterialPageRoute(
    builder: (_) => BlocProvider(
      create: (context) => sl<MyBloc>()..add(const LoadDataEvent()),
      child: const MyScreen(),
    ),
    settings: settings,
  );
```

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
- **Icons**: Place new PNG/SVG assets in `assets/`. Register them in `pubspec.yaml`.
- **Usage**: Access them using `Image.asset('assets/image_name.png')`.

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
Always center the core content within a **1020px fixed-width container** for desktop views. This prevents the UI from becoming unreadable on ultra-wide monitors.

---

## 13. End-to-End Implementation Checklist

- [ ] **Directory structure**: Files placed in `lib/features/[name]/{data, domain, presentation}`.
- [ ] **Data layer**: `RepositoryImpl` and `DataSource` implemented.
- [ ] **Domain layer**: `Entity`, `IRepository`, and `UseCase` defined.
- [ ] **Error Handling**: UseCases and Repositories return `Either<Failure, T>`.
- [ ] **BLoC**: Events, States, and Logic implemented (using specific states like `Loading`, `Loaded`, `Error`).
- [ ] **Injection**: DataSources, Repositories, UseCases, and BLoCs registered in `injection.dart`.
- [ ] **Router**: Constant defined and route registered (with `BlocProvider`) in `app_router.dart`.
- [ ] **Window Management**: New position preset added to `window_manager.dart` and called on screen init.
- [ ] **UI Structure**: Screen uses `WindowBorder`, `MoveWindow` (for header), and `1020px` width constraint.
- [ ] **Design Language**: Colors match feature category (ASR: Indigo, Trans: Teal). Model names match standard nomenclature.
- [ ] **Performance**: Vertical dead space minimized using `MainAxisSize.min` and high-density padding.
- [ ] **Testing**: Unit tests for UseCases and BLoC tests implemented in `test/features/[name]/`.
