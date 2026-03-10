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

---

## 1. Python Server

The Python server acts as the local orchestrator for audio capture and AI processing.

```powershell
# 1. Navigate to the server directory
cd server

# 2. Create and activate a Virtual Environment
python -m venv .venv
.\.venv\Scripts\activate

# 3. Install core dependencies
pip install -r requirements.txt
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

> [!IMPORTANT]
> `firebase_options.dart` and `app_config.dart` are listed in `.gitignore` and must **never** be committed.

### Run the server

```powershell
# From the server/ directory with venv active:
python flutter_server.py
```

Or from the project root, double-click **`start_server.bat`**.

The server starts at `ws://127.0.0.1:8765`.

---

## 3. Flutter App

From the project root:

```powershell
flutter pub get
flutter run -d windows
```

---

## 4. Building for Production

### Python server → EXE (Production)

To create a production build, you must first obfuscate the source code and then package it:

```powershell
cd server
.\.venv\Scripts\activate

# 1. Obfuscate source code
pyarmor gen --output dist_obfuscated .

# 2. Package into EXE (Spec file automatically uses dist_obfuscated)
pyinstaller --noconfirm --clean omni_bridge_server.spec
```

Output: `dist/omni_bridge_server.exe`

### Flutter → Windows release

```powershell
flutter build windows
```

### Installer (Inno Setup)

Open `installer_setup.iss` in [Inno Setup Compiler](https://jrsoftware.org/isinfo.php) and click **Compile**.

Output: `installers/OmniBridge_Setup_v1.2.3.exe`

---

## VS Code

A `.vscode/settings.json` is included to help manage project execution natively. This file configures:
- **`python.defaultInterpreterPath`**: Automatically points to the `server/.venv/Scripts/python.exe` virtual environment. If you encounter interpreter path errors, ensure your virtual environment was created precisely as `server/.venv`.
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

---

## 6. Copyright & Legal Safeguards

While copyright is automatic upon creation, formalizing your protection is highly recommended for commercial-grade software.

1. **Formal Registration**: It is recommended to register your software with the **U.S. Copyright Office** (or your local equivalent). This creates a public record of ownership and is a prerequisite for filing infringement lawsuits in many jurisdictions.
2. **Deposit Source Code**: During registration, you will likely need to deposit a portion of your source code. Ensure you deposit the "Redacted" or key logic portions that you wish to protect most.
3. **Professional Counsel**: For critical commercial protection, always consult with an Intellectual Property (IP) attorney to ensure your custom license and registration are robust.

---

## 7. Additional Developer Documentation

- [Flutter Architecture](flutter_architecture.md)
- [Python Server Architecture](python_architecture.md)
- [Database Schema](database_schema.md)
- [Monetization Plan](monetization_plan.md)
- [Admin Features Overview](admin_features_overview.md)
- [Google Auth Troubleshooting](google_auth_troubleshooting.md)
- [Publishing a New Release](github_releases_guide.md)
