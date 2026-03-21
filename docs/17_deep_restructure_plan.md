# Omni Bridge: Deep Architecture Restructure Plan

This document provides a highly detailed, step-by-step blueprint to migrate the Omni Bridge application from its current horizontal layered architecture to a **Feature-Driven Clean Architecture** (similar to KiraSathi or standard enterprise Flutter apps). 

By following this plan strictly phase-by-phase, you ensure robust separation of concerns, higher testability, and zero regression.

---

## 1. The Target Architecture Pattern

We will migrate to a **Feature-Driven (Vertical Slice)** structure. Instead of organizing by layer (`lib/data`, `lib/domain`), we organize by feature (`lib/features/translation`, `lib/features/auth`), and then layer *inside* each feature.

### Standard Feature Template
```text
lib/features/[feature_name]/
  ├── domain/               # Business Logic (The absolute core)
  │   ├── entities/         # Pure Dart data objects (No dependencies, No JSON annotations)
  │   ├── repositories/     # Interfaces (abstract classes) defining what the feature needs
  │   └── usecases/         # Action classes (e.g., StartTranslationUseCase, LoginUseCase)
  ├── data/                 # Outside World (APIs, Firebase, Local Storage)
  │   ├── models/           # DTOs with fromJson/toJson (extends Domain Entities)
  │   ├── datasources/      # Classes calling APIs, WebSockets, or Firebase directly
  │   └── repositories/     # Implementation of Domain's abstract repositories
  └── presentation/         # UI & State Management
      ├── blocs/            # State management (Bloc/Cubit) coordinating UseCases
      ├── screens/          # Main UI pages
      └── widgets/          # UI components specific to this feature
```

---

## 2. Phase 1: Core & Infrastructure Realignment (Foundation)

Before moving features, clean up the `core` folder. This houses code shared across *multiple* features.

**Actions:**
1. **Create `lib/core/infrastructure/`**: Move native/desktop integrations here.
   - Move `lib/data/services/server/python_server_manager.dart` -> `lib/core/infrastructure/python_server_manager.dart` (This isn't standard "data", it's process management).
2. **Create `lib/core/device/`**: Move hardware-specific system services here.
   - Move `lib/data/services/system/asr_text_controller.dart` -> `lib/core/device/asr_text_controller.dart`
   - Move `lib/data/services/system/audio_recording_service.dart` -> `lib/core/device/audio_recording_service.dart`
   - Move `lib/data/services/system/hotkey_service.dart` -> `lib/core/device/hotkey_service.dart`
3. **Clean up `GlobalNavigator`**: Ensure `lib/core/navigation/global_navigator.dart` and `lib/core/routes/router.dart` are isolated. Update their imports later.
4. **Phase Synchronization**:
   - Update `README.md` and all related architectural `docs/*.md`.
   - Audit `.gitignore` for any new path patterns.
   - Update `firestore.rules` if any core data structures changed.

---

## 3. Phase 2: Feature Extraction (The Core Migration)

We will create the `lib/features/` directory and migrate existing code feature by feature. Do **one feature at a time**, fix imports, and run the app.

### Feature A: Authentication (`lib/features/auth`)
1. **Domain Layer**:
   - Move `lib/domain/repositories/auth_repository.dart` -> `lib/features/auth/domain/repositories/i_auth_repository.dart` (Rename to `IAuthRepository`)
   - **Create UseCases**: `LoginWithGoogleUseCase`, `LogoutUseCase`, `GetCurrentUserUseCase`. (These will inject `IAuthRepository` and have exactly one `call()` method).
2. **Data Layer**:
   - Move `lib/data/services/firebase/auth_service.dart` -> `lib/features/auth/data/datasources/auth_remote_datasource.dart` (Class: `AuthRemoteDataSource`)
   - Move `lib/data/repositories/auth_repository_impl.dart` -> `lib/features/auth/data/repositories/auth_repository_impl.dart`
3. **Presentation Layer**:
   - Move `lib/presentation/screens/login/` -> `lib/features/auth/presentation/screens/`
   - Move `lib/presentation/screens/account/` -> `lib/features/auth/presentation/screens/`
   - Move auth-related blocs (if any) to `lib/features/auth/presentation/blocs/`.

### Feature B: Translation (`lib/features/translation`)
1. **Domain Layer**:
   - Move `lib/domain/repositories/translation_repository.dart` -> `lib/features/translation/domain/repositories/i_translation_repository.dart`
   - **Entities**: (Extract core data structures from `caption_model.dart` into pure Dart entities sans JSON).
   - **Create UseCases**: `StartTranslationUseCase`, `StopTranslationUseCase`, `UpdateVolumeUseCase`, `GetModelStatusUseCase`.
2. **Data Layer**:
   - Move `lib/data/models/caption_model.dart` -> `lib/features/translation/data/models/caption_dto.dart` (Implements domain entity).
   - Move `lib/data/services/server/asr_ws_client.dart` -> `lib/features/translation/data/datasources/asr_websocket_datasource.dart`
   - Move `lib/data/services/translation/whisper_service.dart` -> `lib/features/translation/data/datasources/translation_rest_datasource.dart`
   - Move `lib/data/repositories/translation_repository_impl.dart` -> `lib/features/translation/data/repositories/translation_repository_impl.dart`
3. **Presentation Layer**:
   - Move `lib/presentation/screens/translation/` -> `lib/features/translation/presentation/screens/`
   - Ensure `TranslationBloc` lives in `lib/features/translation/presentation/blocs/` and injects **UseCases**, not Repositories directly.

### Feature C: Settings (`lib/features/settings`)
1. **Domain Layer**:
   - Move `lib/domain/repositories/settings_repository.dart` -> `lib/features/settings/domain/repositories/i_settings_repository.dart`
   - **Create UseCases**: `GetAppSettingsUseCase`, `UpdateAppSettingsUseCase`, `GetAvailableDevicesUseCase`.
2. **Data Layer**:
   - Move `lib/data/models/app_settings.dart` -> `lib/features/settings/data/models/app_settings_dto.dart`.
   - Create local datasource: `lib/features/settings/data/datasources/settings_local_datasource.dart` (wrapping SharedPreferences/SecureStorage).
   - Move `lib/data/repositories/settings_repository_impl.dart` -> `lib/features/settings/data/repositories/settings_repository_impl.dart`.
3. **Presentation Layer**:
   - Move `lib/presentation/screens/settings/` -> `lib/features/settings/presentation/screens/`
   - Any state management for settings goes to `lib/features/settings/presentation/blocs/`.

### Feature D: History (`lib/features/history`)
1. **Domain Layer**:
   - Create `lib/features/history/domain/repositories/i_history_repository.dart`
   - Move `lib/data/models/history_entry.dart` -> `lib/features/history/domain/entities/history_entry.dart` (Remove JSON logic to a Data Model later).
   - Create UseCases: `GetHistoryUseCase`, `ClearHistoryUseCase`.
2. **Data Layer**:
   - Create `HistoryRemoteDataSource` for Cloud Firestore fetching.
   - Create `HistoryRepositoryImpl`.
3. **Presentation Layer**:
   - Move `lib/presentation/screens/history/` -> `lib/features/history/presentation/screens/`

### Feature E: Subscription / Quota (`lib/features/subscription`)
1. **Domain Layer**:
   - Create `lib/features/subscription/domain/repositories/i_subscription_repository.dart`
   - Create UseCases: `GetSubscriptionTierUseCase`, `GetQuotaUsageUseCase`.
2. **Data Layer**:
   - Move `lib/data/models/subscription_models.dart` -> `lib/features/subscription/data/models/subscription_dto.dart`.
   - Move `lib/data/services/firebase/subscription_service.dart` -> `lib/features/subscription/data/datasources/subscription_remote_datasource.dart`.
   - Create `SubscriptionRepositoryImpl`.
3. **Presentation Layer**:
   - Move `lib/presentation/screens/subscription/` -> `lib/features/subscription/presentation/screens/`
4. **Phase Synchronization**:
   - Update `README.md` and feature-specific `docs/*.md`.
   - Update `.gitignore` for new feature directory patterns.
   - Update `firestore.rules` to match new feature-driven data paths.

---

## 4. Phase 3: Dependency Injection (DI) Cleanup

Currently, DI is handled in `lib/core/di/injection.dart` likely mapping blocs directly to repositories.

**Rules for new DI**:
1. **Data Sources**: Register external wrappers (http.Client, FirebaseFirestore instance) and inject them into `DataSources`.
2. **Repositories**: Inject `DataSources` into `RepositoryImpls`, and register them against their `Domain Interface` (`bind<IAuthRepository>().to<AuthRepositoryImpl>()`).
3. **UseCases**: Inject the interface `I***Repository` into the UseCases.
4. **Blocs/Cubits**: Inject **UseCases** into Blocs/Cubits. **Never inject a Repository directly into a Bloc.**

Example (using GetIt):
```dart
// 1. Data Sources
sl.registerLazySingleton<AuthRemoteDataSource>(() => AuthRemoteDataSourceImpl(firebaseAuth: sl()));

// 2. Repositories
sl.registerLazySingleton<IAuthRepository>(() => AuthRepositoryImpl(remoteDataSource: sl()));

// 3. Use Cases
sl.registerLazySingleton(() => LoginWithGoogleUseCase(repository: sl()));

// 4. Blocs
sl.registerFactory(() => AuthBloc(loginWithGoogleUseCase: sl()));
```

5. **Phase Synchronization**:
   - Update `README.md` (Architecture/DI section).
   - Update and synchronize all related `docs/*.md` with new DI patterns.
   - Ensure `.gitignore` and `firestore.rules` are aligned with DI-injected services.

---

## 5. Phase 5: Application Bootstrapping & Routing

Currently, all BLoCs (`TranslationBloc`, `SettingsBloc`) are instantiated globally in `lib/app.dart` inside a `MultiBlocProvider`. In a proper feature-driven architecture, we only keep **Global** states at the top level.

**Actions:**
1. **Global Providers in `app.dart`**: Things like `AuthBloc` or `ThemeBloc`/`SettingsBloc` stay in the global `MultiBlocProvider`.
2. **Feature-Scoped Providers**: Scoped features like `TranslationBloc` or `HistoryBloc` should NOT live in `app.dart`. Instead, inject them at the navigation level right before the screen loads.
3. **Router Cleanup**: Move `lib/core/routes/router.dart` to `lib/core/navigation/app_router.dart`. Inside the route generator, wrap your feature screens with their respective `BlocProvider`:
   ```dart
   case '/translation':
     return MaterialPageRoute(
       builder: (_) => BlocProvider(
         create: (_) => sl<TranslationBloc>(),
         child: const TranslationScreen(),
       ),
     );
   ```

4. **Phase Synchronization**:
   - Update `README.md` and `docs/*.md` to reflect new routing and BLoC scoping.
   - Synchronize `.gitignore` and `firestore.rules` for any new persistence logic.

---

## 6. Phase 6: Implementation Checklist & Safety Guidelines

To prevent breaking the app during migration, follow this loop for **each feature** (do not do all features at once):

1. [ ] **Create Folder Hierarchy** for the specific feature.
2. [ ] **Move Domain layer files** (Interfaces & Entities). Fix imports.
3. [ ] **Create Use Cases** if they do not exist. Update Blocs to rely on UseCases.
4. [ ] **Move Data layer files** (Models, DataSources, Repo Impls). Fix imports.
5. [ ] **Move Presentation layer files** (Screens, scattered Blocs). Fix imports. *Note: Ensure all old BLoC folders (like `core/blocs` or BLoCs inside `screens/`) are moved to their feature's `presentation/blocs/` and the old empty folders are deleted.*
6. [ ] **Update DI (`injection.dart`)** to reflect the new paths and UseCases.
7. [ ] **Scoped Routing**: Update `app_router.dart` to inject the feature's BLoC at the route level.
9. [ ] **Phase Synchronization**: Update `README.md`, all `docs/*.md`, `.gitignore`, and `firestore.rules` for this feature.
10. [ ] **Run Flutter Clean & Run**. Do not move to the next feature until the app compiles and runs perfectly.

By doing this strictly, you maintain an always-working app while completely reforming the architecture.
