# OmniBridge Flutter App Architecture

## Overview
The OmniBridge client is a Flutter desktop application (Windows) that serves as the user interface and orchestration layer. It is responsible for managing user settings, displaying an overlay for live translations, managing authentication, and communicating with the local Python backend server for audio processing.

The app follows a **BLoC (Business Logic Component)** architecture for state management, ensuring a clear separation between UI, state, and business logic.

## Directory Structure
```text
lib/
├── core/
│   ├── blocs/          # Global BLoCs (e.g., AuthBloc)
│   ├── constants/      # App-wide constants (themes, strings)
│   ├── routes/         # Navigation routing configuration
│   ├── services/       # Core services (Firestore tracking, TranslationService, WebSockets)
│   ├── utils/          # Helper functions
│   └── widgets/        # Reusable global widgets
├── models/             # Data models for settings, user info, etc.
├── screens/            # UI organized by feature
│   ├── account/        # User profile and account management
│   ├── home/           # Main landing screen
│   ├── settings/       # Settings control (Audio devices, Languages, Models)
│   ├── startup/        # Splash and Onboarding experience
│   └── translation/    # The transparent translation overlay and logic
├── app.dart            # Main MaterialApp wrapper (handles initial routing)
└── main.dart           # Application entry point (initializes Firebase, Auth, and SingleInstance)
```

## Key Components

### 1. State Management (BLoC)
The app uses the `flutter_bloc` package to manage state across different features:
- **`AuthBloc`**: Manages user authentication state using Firebase Auth (Google Sign-In, Email/Password).
- **`SettingsBloc`**: Manages local user preferences (`translationModel`, `transcriptionModel`, input/output devices, languages). It syncs these settings with Cloud Firestore for persistent storage across sessions.
- **`TranslationBloc`**: Orchestrates the active translation session. It connects the UI overlay with the `TranslationService`.

### 2. Services (`lib/core/services/`)
Services handle the business logic and external communication:
- **`TranslationService`**: Acts as the bridge between the Flutter app and the Python server. It triggers the `/start` and `/stop` REST endpoints on the Python server.
- **`AsrWsClient`**: Manages the WebSocket connection (`ws://127.0.0.1:8000/ws/captions`) to the Python server to receive live transcription and translation updates.
- **`TrackingService`**: Responsible for logging usage analytics, session data, and translation metadata to Firebase Firestore and Realtime Database.
- **`AuthService`**: Handles interaction with Firebase Authentication and custom URL scheme (`omni-bridge://`) deep-linking for desktop browser-based Google Sign-In.

### 3. UI Features (`lib/screens/`)
- **Settings Screen**: Allows the user to select their preferred `transcriptionModel` (e.g., Google or Whisper), `translationModel` (e.g., Llama, Riva, Google, MyMemory), target languages, and input/output audio devices.
- **Translation Overlay**: Uses desktop window management plugins (`bitsdojo_window`, `window_manager`) to display a borderless, always-on-top, click-through overlay showing the live translated captions.

## Application Flow
1. **Launch**: 
   - App boots and ensures it is the only instance running on Windows.
   - Initializes Firebase and environment variables.
   - Binds `AuthService` state and checks `SharedPreferences` for onboarding status.
   - **Conditional Routing**: 
       - Skip **Splash** if the user is already logged in for faster access.
       - Show **Splash** -> **Onboarding** for new users.
       - Show **Splash** -> **Login** for existing logged-out users.
2. **Setup**: The user configures settings (Languages, Mic/Desktop Audio, AI Models) in the Settings Tab.
3. **Start Translation**:
   - The user clicks "Start" on the Home Tab.
   - `TranslationBloc` sends a REST POST request to the Python backend `/start`.
   - `AsrWsClient` connects via WebSocket (`ws://`) to listen for incoming JSON packets.
   - The Flutter App opens the **Translation Overlay** window using `bitsdojo_window`.
4. **Live Stream**: The Python server streams JSON payloads containing `originalText`, `translatedText`, and `isFinal` flags to the Flutter app's WebSocket.
5. **Stop**: `TranslationBloc` stops the stream, hides the overlay, and updates the `TrackingService` with final session statistics on Firebase RTDB.
