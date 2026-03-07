# Omni Bridge — Server Architecture & Setup Guide

## Overview

Omni Bridge uses a **hybrid two-server architecture**:

| Layer | Where It Runs | Responsibility |
|---|---|---|
| **Local Python Server** | User's PC (bundled in installer) | Capture Windows audio, manage devices, relay audio to cloud |
| **Cloud Server** | Google Cloud Run | Hold API keys, call NVIDIA Riva + OpenAI, return captions |
| **Flutter Frontend** | User's PC | Display captions, send settings via WebSocket |

```
User PC
┌──────────────────────────────────────────────┐
│  Flutter App  ←──WS(captions)──→  Local Py  │
│                                      Server  │
│    (ws://localhost:8765)          (pyaudio,  │
│                                   devices)   │
└────────────────────┬─────────────────────────┘
                     │ raw audio (WSS)
                     ▼
         Google Cloud Run
         ┌─────────────────────────┐
         │  Cloud Server           │
         │  - NVIDIA Riva (ASR)    │
         │  - OpenAI/Llama (trans) │
         │  - API keys stored here │
         └─────────────────────────┘
```

---

## Directory Structure

```
omni_bridge/
│
├── server/                        # Python backend
│   ├── flutter_server.py          # Local server (entry point for installed app)
│   ├── cloud_server.py            # Cloud server (deployed to Google Cloud Run)
│   ├── nim_api.py                 # AI engine orchestrator (Riva / Llama / Google)
│   ├── audio_capture.py           # Windows WASAPI audio capture (local-only)
│   ├── audio_meter.py             # Real-time RMS metering (local-only)
│   ├── shared_pyaudio.py          # Singleton PyAudio instance
│   ├── models/
│   │   ├── riva_model.py          # NVIDIA Riva ASR + translation
│   │   ├── llama_model.py         # Llama 3.1 8B via NVIDIA NIM
│   │   └── google_model.py        # Google Translate fallback
│   ├── requirements.txt           # Local server dependencies (includes pyaudiowpatch)
│   ├── requirements_cloud.txt     # Cloud server dependencies (no Windows libs)
│   ├── Dockerfile                 # Container definition for Cloud Run
│   ├── omni_bridge_server.spec    # PyInstaller spec to build local server EXE
│   └── .env.example               # Template for server env vars
│
├── lib/                           # Flutter application source
│   ├── main.dart
│   ├── app.dart
│   ├── core/
│   │   ├── services/
│   │   │   ├── auth_service.dart  # Firebase Authentication logic
│   │   │   └── tracking_service.dart  # Firestore session tracking
│   │   └── ...
│   └── screens/
│       ├── login/                 # Login screen
│       ├── settings/              # Device & language settings
│       └── ...
│
├── .env                           # Flutter app env vars (shipped in installer)
├── .env.example                   # Template for Flutter app env vars
├── installer_setup.iss            # Inno Setup script to build Windows installer
└── start_server.bat               # Dev shortcut to launch local server
```

---

## Environment Variables Reference

### Flutter App — `.env` (Shipped to user's PC via the installer)

| Variable | Safe to Ship? | Notes |
|---|---|---|
| `GOOGLE_CLIENT_ID` | ✅ **Yes — Public** | Designed to be public. Needed for OAuth redirect. |
| `FIREBASE_API_KEY` | ✅ **Yes — Public** | Firebase security comes from Security Rules, not key secrecy. |
| `FIREBASE_APP_ID` | ✅ **Yes — Public** | Simply identifies your app to Firebase. |
| `AUTH_SUCCESS_REDIRECT_URL` | ✅ Yes | Just a URL, no secret. |
| `CLOUD_SERVER_URL` | ✅ Yes | Your Cloud Run URL, not a secret. |

> [!TIP]
> Firebase, Google Client ID, and App ID are safe to include in your installer because they are **public identifiers**, not billing secrets. Security for Firestore/Auth is enforced by Firebase Security Rules in the Firebase Console.

### Cloud Server — Environment Variables (Set in Google Cloud Run, NEVER shipped to users)

| Variable | Safe to Ship? | Notes |
|---|---|---|
| `NVIDIA_API_KEY` | ❌ **No — Billing Secret** | Used to call NVIDIA Riva ASR + NIM. Exposed = bill theft. |
| `OPENAI_API_KEY` | ❌ **No — Billing Secret** | If using OpenAI directly. |

> [!CAUTION]
> The `NVIDIA_API_KEY` must **never** appear in the installer or in the local `.env`. It lives only as a Google Cloud Run environment variable (or Secret Manager secret), inaccessible to end users.

---

## Local Server — Setup & Running

The local server runs on the user's PC after installation. For development:

```powershell
# 1. Navigate to server directory
cd server

# 2. Activate virtual environment
..\server_env\Scripts\activate

# 3. Set your env vars (copy example and fill in)
copy .env.example .env

# 4. Run the local server
python flutter_server.py
```

The server starts on `ws://localhost:8765`.

### Key Endpoints

| Endpoint | Method | Description |
|---|---|---|
| `/captions` | WebSocket | Flutter connects here to receive live captions |
| `/devices` | GET | Returns available microphone and speaker devices |
| `/start` | POST | Starts audio capture with given settings |
| `/stop` | POST | Stops audio capture |
| `/status` | GET | Returns running state and connected client count |

---

## Cloud Server — Setup & Deployment

The cloud server uses only cross-platform dependencies (no `pyaudiowpatch`).

### Local Development (Testing the Cloud Server)

```powershell
# Install cloud-only dependencies
pip install -r requirements_cloud.txt

# Set your secure API keys in a local .env (DO NOT COMMIT)
set NVIDIA_API_KEY=your_key_here

# Run the cloud server locally on port 8766 to test it
python cloud_server.py
```

### Deploy to Google Cloud Run

```bash
# 1. Build the Docker image
gcloud builds submit --tag gcr.io/YOUR_PROJECT_ID/omni-bridge-cloud-server

# 2. Deploy to Cloud Run
gcloud run deploy omni-bridge-cloud \
  --image gcr.io/YOUR_PROJECT_ID/omni-bridge-cloud-server \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars NVIDIA_API_KEY=your_key_here

# 3. Get the deployed URL and set it in your Flutter app's .env
# CLOUD_SERVER_URL=wss://omni-bridge-cloud-XXXX-uc.a.run.app/stream
```

> [!IMPORTANT]
> Use **Google Cloud Secret Manager** instead of `--set-env-vars` in production to store `NVIDIA_API_KEY` more securely. It prevents the key from appearing in Cloud Run's deployment history and console logs.

---

## Building the Installer

The installer bundles the Flutter app + local Python server EXE.

```powershell
# Step 1: Build the local Python server EXE
cd server
..\server_env\Scripts\python.exe -m PyInstaller --noconfirm --clean omni_bridge_server.spec

# Step 2: Build the Flutter Windows release
cd ..
flutter build windows

# Step 3: Compile the Inno Setup installer
# Open installer_setup.iss in Inno Setup Compiler and click "Compile"
# Output: installers/OmniBridge_Setup_v1.2.1.exe
```

---

## AI Engine Reference

| Engine Key | ASR | Translation | Notes |
|---|---|---|---|
| `riva` | NVIDIA Riva | NVIDIA NIM / Riva | Default. Best quality. Falls back to Llama. |
| `llama` | NVIDIA Riva | Llama 3.1 8B | Direct Llama translation. |
| `google` | NVIDIA Riva | Google Translate | Free. Falls back to Llama on failure. |
