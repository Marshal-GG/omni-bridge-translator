# Developer Setup

This guide covers running Omni Bridge from source for development.

## Prerequisites

- **Windows 10/11** (required for WASAPI loopback audio capture)
- **Flutter SDK** 3.x+ — [flutter.dev](https://flutter.dev/docs/get-started/install/windows)
- **Python 3.10+** — [python.org](https://python.org)

---

## 1. Python Server

```powershell
cd server
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
```

### Environment Variables

Copy the example env file and fill in your keys:

```powershell
copy .env.example .env
```

Edit `server/.env`:

```env
NVIDIA_API_KEY=your_nvidia_nim_key_here
```

> **Note:** The Google Translate and MyMemory engines do not require a key. Only NVIDIA Riva / Llama require `NVIDIA_API_KEY`.

### Run the server

```powershell
# From the server/ directory with venv active:
python flutter_server.py
```

Or from the project root, double-click **`start_server.bat`**.

The server starts at `ws://127.0.0.1:8765`.

---

## 2. Flutter App

From the project root:

```powershell
flutter pub get
flutter run -d windows
```

---

## 3. Building for Production

### Python server → EXE

```powershell
cd server
.\.venv\Scripts\activate
pyinstaller --noconfirm --clean omni_bridge_server.spec
```

Output: `dist/omni_bridge_server.exe`

### Flutter → Windows release

```powershell
flutter build windows
```

### Installer (Inno Setup)

Open `installer_setup.iss` in [Inno Setup Compiler](https://jrsoftware.org/isinfo.php) and click **Compile**.

Output: `installers/OmniBridge_Setup.exe`

---

## VS Code

A `.vscode/settings.json` is included to help manage project execution natively. This file configures:
- **`python.defaultInterpreterPath`**: Automatically points to the `server/.venv/Scripts/python.exe` virtual environment. If you encounter interpreter path errors, ensure your virtual environment was created precisely as `server/.venv`.
- **`python.venvFolders`** and **`python.analysis.extraPaths`**: Helps VS Code resolve server modules accurately without manual configuration for linting and IntelliSense.
- **`python.terminal.useEnvFile`**: Loads environment variables when utilizing the integrated terminal.

Recommended extensions:
- **Dart** + **Flutter** (Dart Code)
- **Python** (Microsoft)
