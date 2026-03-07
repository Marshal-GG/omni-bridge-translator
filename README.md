# Omni Bridge: Live AI Translator 🌉

Omni Bridge: Live AI Translator is a real-time translating live-caption overlay built with Flutter and Python. It captures system audio (or microphone input) on Windows, sends it to a local Python WebSocket server, processes the audio using **NVIDIA Riva**, **Whisper (Offline)**, or **Google Free ASR**, and translates or transcribes captions using **OpenAI (Llama)**, **Google Translate**, **MyMemory**, or **Riva NMT**, streaming them back to a transparent, draggable, always-on-top desktop widget.

<div align="center">

| Normal View | Mini View |
| :---: | :---: |
| <img src="assets/screenshots/image3.png" width="400"/> | <img src="assets/screenshots/image2.png" width="400"/> |

| Settings |
| :---: |
| <img src="assets/screenshots/image1.png" width="380"/> |

</div>

## 🏗️ Architecture

The project is split into two main components:
1. **Python Backend (`server/`)**: 
   - Uses `pyaudiowpatch` to capture Windows system audio via WASAPI loopback.
   - **Decoupled Engine Architecture**:
     - **ASR**: NVIDIA Riva (Multilingual), Whisper (Offline - 4 sizes), Google Speech-to-Text.
     - **Translation**: Google Translate, MyMemory (Free), NVIDIA Riva NMT, Llama (via OpenAI compatible endpoint).
   - High-performance WebSocket streaming for real-time captions.
2. **Flutter Frontend (`lib/`)**:
   - Built using Desktop window management plugins (`bitsdojo_window`, `window_manager`) to create a transparent, frameless overlay.
   - Connects to the Python server via `web_socket_channel`.
   - Displays real-time interim and final translated captions.

## 📋 Prerequisites

- **Flutter SDK** (for the UI)
- **Python 3.10+** (for the backend server)
- **Windows OS** (required for `pyaudiowpatch` loopback capture)
- **NVIDIA Riva & Translation API Keys**

## 🚀 Setup Instructions

### 1. Python Server Configuration
The Python backend requires its own virtual environment and dependencies.

1. Navigate to the `server` folder:
   ```ps1
   cd server
   ```
2. Create a virtual environment named `server_env`:
   ```ps1
   python -m venv server_env
   ```
3. Activate the environment:
   ```ps1
   .\server_env\Scripts\activate
   ```
4. Install the required dependencies:
   ```ps1
   pip install -r requirements.txt
   ```

### 2. Configure Environment Variables
You must provide your API keys before running the server. 
1. Copy the `server/.env.example` file and rename the copy to `server/.env`.
2. Edit `server/.env` and replace the placeholder API key with your actual NVIDIA NIM API key.

### 3. Running the Server
The easiest way to start the backend is to double-click the **`start_server.bat`** file in the root directory. 

Alternatively, if you want to run it from the command line, make sure your virtual environment is activated:
```ps1
cd server
.\server_env\Scripts\activate
python main.py
```
*(Note: Replace `main.py` with your actual entry point script, e.g. `flutter_server.py`)*

The server will start on `ws://0.0.0.0:8765`.

### 4. Running the Flutter App
Open a separate terminal and run the Flutter application:
```ps1
flutter run -d windows
```

## 🛠️ Building for Production

To create a standalone installer that bundles both the Python server and the Flutter UI:

1. **Build Python Executable:**
   Open a terminal in the `server` directory, activate the environment, and use PyInstaller.
   ```ps1
   cd server
   .\server_env\Scripts\activate
   pyinstaller --noconfirm --clean omni_bridge_server.spec
   ```
   This generates `dist/omni_bridge_server.exe`.

2. **Build Flutter Release:**
   Open a terminal in the root directory and build the Windows app.
   ```ps1
   flutter build windows
   ```

3. **Create Windows Installer (Inno Setup):**
   Open `installer_setup.iss` in Inno Setup Compiler and click "Compile". This will bundle everything into a single `.exe` installer inside the `installers/` folder.

## 💡 Usage
1. Make sure the Python server is running (`start_server.bat`).
2. Launch the Omni Bridge: Live AI Translator Flutter app.
3. Sign in with **Google**, **Email/Password**, or continue as a **Guest**. (Google Sign-In uses your system browser and the `omni-bridge://` custom URL scheme).
4. Click the **Gear (Settings)** icon in the top right of the overlay.
5. (Optional) Toggle **Microphone Translation** to translate your mic input instead of system audio.
6. Select your **Speech Recognition** model:
   - **Online (Google)**: Standard fast ASR.
   - **NVIDIA Riva**: High-performance multilingual ASR (requires Riva key).
   - **Offline (Whisper)**: Run locally without internet. Supports **Tiny, Base, Small, and Medium** models which can be downloaded directly from the settings.
7. Select your **Translation Engine**:
   - **Google Translate**: Standard online translation.
   - **MyMemory**: Alternative free translation service.
   - **Llama / Riva**: AI-powered translation (requires API keys).
8. Select your **Target Language**. You can select **Original Source (Transcription)** to bypass translation and only transcribe the speech.
9. Close the settings panel. Omni Bridge: Live AI Translator will connect to the server and begin displaying live translations or transcriptions for any audio playing on your PC (or from your microphone).

### � Account Screen
- Access your account via the **person icon** on the translator overlay.
- Displays your **display name**, **email**, and a badge showing your sign-in method (e.g. *Email Account*, *Google Account*, or *Guest Mode*).
- Edit your **display name** and save it directly from the account panel.
- The back arrow in the **top-left of the header** returns you to the translator overlay.

## �📦 Dependencies

**Flutter (`pubspec.yaml`)**:
- `web_socket_channel`: WebSocket communication.
- `dropdown_search`: Searchable language selection UI.
- `bitsdojo_window` & `window_manager`: Frameless, draggable desktop overlay.
- `flutter_acrylic`: Transparent background support.
- `firebase_auth` & `firebase_core`: User authentication.
- `app_links`: Custom URL scheme (`omni-bridge://`) handling for Windows Google Sign-In.

**Python (`server/requirements.txt`)**:
- `fastapi`, `uvicorn`, `websockets`
- `pyaudiowpatch`, `PyAudio`
- `numpy`
- `nvidia-riva-client`
- `openai`
