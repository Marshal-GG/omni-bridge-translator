# Omni Bridge: Live AI Translator

Omni Bridge: Live AI Translator is a real-time translating live-caption overlay built with Flutter and Python. It captures system audio (or microphone input) on Windows, sends it to a local Python WebSocket server, processes the audio using NVIDIA Riva/NIM and OpenAI for translation, and streams the translated captions back to a transparent, draggable, always-on-top desktop widget.

## Architecture

The project is split into two main components:
1. **Python Backend (`server/`)**: 
   - Uses `fastapi` and `websockets` to host a local server (`ws://localhost:8765/captions`).
   - Uses `pyaudiowpatch` to capture Windows system audio via WASAPI loopback.
   - Streams audio chunks to an NVIDIA Riva ASR service.
   - Translates transcribed text using an OpenAI-compatible endpoint (Llama fallback).
2. **Flutter Frontend (`lib/`)**:
   - Built using Desktop window management plugins (`bitsdojo_window`, `window_manager`) to create a transparent, frameless overlay.
   - Connects to the Python server via `web_socket_channel`.
   - Displays real-time interim and final translated captions.

## Prerequisites

- **Flutter SDK** (for the UI)
- **Python 3.10+** (for the backend server)
- **Windows OS** (required for `pyaudiowpatch` loopback capture)
- **NVIDIA Riva & Translation API Keys**

## Setup Instructions

### 1. Python Server Configuration
The Python backend uses a virtual environment located in `server_env/`.

You must provide your API keys before running the server. 
1. Copy the `server/.env.example` file and rename the copy to `server/.env`.
2. Edit `server/.env` and replace `your_nvidia_nim_api_key_here` with your actual NVIDIA NIM API key.

### 2. Running the Server
The easiest way to start the backend is to double-click the **`start_server.bat`** file in the root directory. 

Alternatively, run from the command line:
```ps1
.\server_env\Scripts\activate
cd server
python flutter_server.py
```
The server will start on `ws://0.0.0.0:8765`.

### 3. Running the Flutter App
Open a separate terminal and run the Flutter application:
```ps1
flutter run -d windows
```

## Usage
1. Make sure the Python server is running (`start_server.bat`).
2. Launch the Omni Bridge: Live AI Translator Flutter app.
3. Click the **Gear (Settings)** icon in the top right of the overlay.
4. Select your **Source Language** (or leave as Auto-Detect) and your desired **Target Language**.
5. Close the settings panel. Omni Bridge: Live AI Translator will connect to the server and begin displaying live translations for any audio playing on your PC.

## Dependencies

**Flutter (`pubspec.yaml`)**:
- `web_socket_channel`: WebSocket communication.
- `dropdown_search`: Searchable language selection UI.
- `bitsdojo_window` & `window_manager`: Frameless, draggable desktop overlay.
- `flutter_acrylic`: Transparent background support.

**Python (`server/requirements.txt`)**:
- `fastapi`, `uvicorn`, `websockets`
- `pyaudiowpatch`, `PyAudio`
- `numpy`
- `nvidia-riva-client`
- `openai`
