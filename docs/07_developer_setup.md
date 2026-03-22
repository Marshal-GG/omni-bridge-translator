<!--
 Copyright (c) 2026 Omni Bridge. All rights reserved.
 
 Licensed under the PERSONAL STUDY & LEARNING LICENSE v1.0.
 Commercial use and public redistribution of modified versions are strictly prohibited.
 See the LICENSE file in the project root for full license terms.
-->

# Developer Setup

This guide covers running Omni Bridge from source for development.

## Prerequisites

- **Windows 10/11** (required for WASAPI loopback audio capture)
- **Flutter SDK** 3.x+ — [flutter.dev](https://flutter.dev/docs/get-started/install/windows)
- **Python 3.11+** — [python.org](https://python.org)
- **Firebase CLI** — [firebase.google.com/docs/cli](https://firebase.google.com/docs/cli)

---

## 1. Python Server

The Python server acts as the local orchestrator for audio capture and AI processing.

```powershell
# 1. Navigate to the project root (already there usually)
# 2. Create and activate a Virtual Environment
python -m venv .venv
.\.venv\Scripts\activate

# 3. Install core dependencies
# It is recommended to stay in the root for venv activation
# Install the server in editable mode from the root
pip install -e ./server
```

### 2. Flutter App Configuration

Credentials are kept out of source control using two gitignored Dart files. Each has a committed example template to copy from.

**Step 1 — Firebase options:**

```powershell
copy lib\firebase_options.example.dart lib\firebase_options.dart
```

Open `lib/firebase_options.dart` and fill in your Firebase project values.  
Get them from: [Firebase Console](https://console.firebase.google.com) → Project Settings → Your apps → SDK setup.

**Step 2 — Google client ID:**

```powershell
copy lib\core\config\app_config.example.dart lib\core\config\app_config.dart
```

Open `lib/core/config/app_config.dart` and fill in your `googleClientId`.  
Get it from: [Google Cloud Console](https://console.cloud.google.com) → APIs & Services → Credentials → OAuth 2.0 Client IDs.

**Step 3 — Firebase Services:**

1.  **Firestore**: Enable Firestore Database (Native mode) in the Firebase Console.
2.  **Realtime Database**: Enable Realtime Database for usage tracking.
3.  **Authentication**: Enable Google Sign-In and Anonymous authentication.
4.  **Admin Setup**: Add your development email to `system/admins/emails` in Firestore. 

> [!TIP]
> **Bootstrap Admin**: The email `marshalgcom@gmail.com` is hardcoded as the primary administrator in `firestore.rules`. Use this account for the first login to configure additional administrators if needed.

**Step 4 — Deploying Security Rules:**

From the project root, ensure you are logged in to the Firebase CLI (`firebase login`) and then deploy the security rules:

```powershell
firebase deploy --only firestore:rules
```

> [!IMPORTANT]
> `firebase_options.dart` and `app_config.dart` are listed in `.gitignore` and must **never** be committed.

### Run the server

```powershell
# From the server/ directory with venv active:
python flutter_server.py
```

Or from the project root, double-click **`start_server.bat`**.

The server starts at `ws://127.0.0.1:8765`.

### Running Unit Tests

The server uses `pytest` for unit testing. Mocks are used for all AI engines, so no API keys or NVIDIA GPUs are required to run the tests.

```powershell
# From the server/ directory with venv active:
pytest
```

To see detailed output, use:
```powershell
pytest -v
```
---

## 3. Flutter App

From the project root:

```powershell
flutter pub get
flutter run -d windows
```

> [!NOTE]
> **Windows Build Fix**: A known issue where `firebase_core` fails to find specific CMake files on Windows has been resolved in the project's root `windows/CMakeLists.txt`. No manual intervention is required.

### Running Flutter Unit Tests

The Flutter app has a comprehensive unit test suite covering all core BLoCs. No device, Firebase, or network connection is required to run them.

```powershell
# Run all tests:
flutter test

# Run all tests with coverage report (same as CI):
flutter test --coverage

# Run tests for a specific feature:
flutter test test/features/auth/

# Run with verbose output to see each test name:
flutter test --reporter expanded
```

Test files live under `test/features/[feature_name]/`. Shared mock helpers (using `mocktail`) are in `test/helpers/test_mocks.dart`.

For details on what each BLoC test covers, see [Flutter Architecture](04_flutter_architecture.md#unit-testing).

### Resetting Environment

If you need to clear all local data specifically for this project without affecting other Firebase apps on your system, run:

```powershell
.\scripts\clear_app_data.ps1
```

> [!IMPORTANT]
> **Safety & Isolation**: This script targets isolated session folders (`OmniBridge-Debug` and `OmniBridge-Release`) within the local AppData directory, and purges legacy insecure `shared_preferences` keys from the Registry. This ensures that cleaning your development environment for Omni Bridge does not inadvertently sign you out of other Firebase-enabled apps, but does fully reset all legacy session identifiers.

### Dev Scripts

The `scripts/` directory contains utility scripts for common developer tasks:

| Script | Purpose |
| :--- | :--- |
| `clear_app_data.ps1` | Purges local app data, secure storage, and registry keys for a clean start. |
| `clear_app_data.cmd` | Command-line wrapper for the PowerShell cleanup script. |

---

## 4. Building for Production

### Python server → EXE (Production)

To create a production build, you must first obfuscate the source code and then package it:

```powershell
cd server
# if .venv is in root, you might need to activate it from root before and then cd here
# or just:
..\.venv\Scripts\activate

# 1. Obfuscate source code
pyarmor gen --output dist_obfuscated .

# 2. Package into EXE (Spec file automatically uses dist_obfuscated)
# Ensure the venv from the project root is active:
# ..\.venv\Scripts\activate 
pyinstaller --noconfirm --clean omni_bridge_server.spec
```

Output: `dist/omni_bridge_server.exe`

### Flutter → Windows release

```powershell
flutter build windows
```

### Installer (Inno Setup)

Open `installer_setup.iss` in [Inno Setup Compiler](https://jrsoftware.org/isinfo.php) and click **Compile**.

Output: `installers/OmniBridge_Setup_v{version}.exe` (version is pulled from `#define MyAppVersion` in `installer_setup.iss`)

**What the installer does:**

- Requires Windows 10 1809+ (build 17763), x64 only, admin privileges
- Uses `AppMutex` / `SetupMutex` to block the app from launching during install and prevent duplicate installer instances
- **Pre-install cleanup** (runs before files are copied):
  1. Kills `omni_bridge.exe` and `omni_bridge_server.exe` to release file locks
  2. Silently runs the existing uninstaller if a previous version is detected
  3. Wipes Flutter SharedPreferences registry keys (`HKCU\Software\omni_bridge`, etc.)
  4. Removes the outdated Google Auth registry key
  5. Deletes stale PyInstaller `%TEMP%\omni_bridge*` extractions
  6. Removes any leftover user-level install directory
  7. Wipes AppData and Firebase caches (Roaming, LocalAppData, Firestore, heartbeat, google-services-desktop-auth) — prevents "still logged in after reinstall" issues
- **On uninstall**: repeats the AppData/Firebase/registry wipe and removes the entire `{app}` directory, including any downloaded Whisper models

---

## VS Code

A `.vscode/settings.json` is included to help manage project execution natively. This file configures:
- **`python.defaultInterpreterPath`**: Automatically points to the `.venv/Scripts/python.exe` virtual environment in the root. If you encounter interpreter path errors, ensure your virtual environment was created in the project root.
- **`python.venvFolders`** and **`python.analysis.extraPaths`**: Helps VS Code resolve server modules accurately without manual configuration for linting and IntelliSense.

Recommended extensions:
- **Dart** + **Flutter** (Dart Code)
- **Python** (Microsoft)

---

## 5. Deployment & Protection

To protect the intellectual property and logic of Omni Bridge, the following steps are recommended for production builds:

### 1. Windows App Obfuscation (Flutter)
Building with obfuscation makes it significantly harder to reverse-engineer the compiled Dart code.

```powershell
# Build the Windows application with obfuscation
flutter build windows --obfuscate --split-debug-info=build/windows/debug_info
```

> [!IMPORTANT]
> Keep the `debug_info` folder secure and separate. You will need it to de-obfuscate stack traces if errors occur in production.

### 2. Python Server Obfuscation (PyArmor)
The Python backend contains core logic protected with [PyArmor](https://pyarmor.readthedocs.io/) before packaging.

```powershell
# 1. Navigate to server
cd server

# 2. Generate obfuscated scripts
pyarmor gen --output dist_obfuscated .

# 3. Build the EXE
pyinstaller omni_bridge_server.spec
```
The `omni_bridge_server.spec` file is pre-configured to automatically source files from `dist_obfuscated/` if the folder exists, ensuring the final `.exe` contains only protected bytecode.

> [!NOTE]
> When using PyArmor to obfuscate code, dynamic imports (such as `riva` and `riva.client`) may be hidden from PyInstaller. These must be explicitly defined in the `hiddenimports` array within `omni_bridge_server.spec` to prevent `ModuleNotFoundError` in production.
>
> **Log Redirection**: PyArmor bug logs are automatically redirected to `server/logs/pyarmor.bug.log` via the local `.pyarmor/config.json`.

---

## 6. Copyright & Legal Safeguards

While copyright is automatic upon creation, formalizing your protection is highly recommended for commercial-grade software.

1. **Formal Registration**: It is recommended to register your software with the **U.S. Copyright Office** (or your local equivalent). This creates a public record of ownership and is a prerequisite for filing infringement lawsuits in many jurisdictions.
2. **Deposit Source Code**: During registration, you will likely need to deposit a portion of your source code. Ensure you deposit the "Redacted" or key logic portions that you wish to protect most.
3. **Professional Counsel**: For critical commercial protection, always consult with an Intellectual Property (IP) attorney to ensure your custom license and registration are robust.

---

## 7. Additional Developer Documentation

- [Flutter Architecture](04_flutter_architecture.md)
- [Python Server Architecture](05_python_architecture.md)
- [Database Schema](06_database_schema.md)
- [Monetization Plan](13_monetization_plan.md)
- [Admin Features Overview](09_admin_features.md)
- [Google Auth Troubleshooting](14_google_auth_troubleshooting.md)
- [Session Isolation & Cleanup](08_session_isolation_guide.md)
- [Server Health Checks](10_server_health_checks.md)
- [Firebase Terminal Management](11_firebase_terminal_management.md)
- [Publishing a New Release](12_github_releases_guide.md)
- [CI/CD, Branching & GitHub Actions](18_github_workflow_guide.md) — how to run CI manually, enable auto-triggers, and ship a release
- [Deep Architecture Restructure Plan](17_deep_restructure_plan.md)
- [Legacy Python Restructure Plan](16_restructure_plan.md)
