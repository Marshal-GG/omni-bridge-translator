# OmniBridge Python Server Architecture

## Overview
The Python server operates as the local backend for the OmniBridge application. It acts as the bridge connecting the user's system audio to the AI processing layer. The server is responsible for capturing audio streams (both desktop loopback and microphone input), transcribing speech in real-time, translating the recognized text into a target language, and streaming the output via WebSockets back to the Dart client. 

This server manages all computationally-intensive tasks off-suite from the UI.

## Directory Structure
```text
server/
├── models/                     # AI engine specific implementations
│   ├── \__init\__.py           # Package init
│   ├── google_model.py         # Google Translate API integration
│   ├── llama_model.py          # Llama (Nvidia NIM) translation integration
│   ├── mymemory_model.py       # MyMemory REST API translation
│   ├── riva_model.py           # Riva (Nvidia NIM) translation integration
│   ├── speech_recognition_model.py # SpeechRecognition ASR (online/offline)
│   └── whisper_model.py        # Local Whisper ASR models
├── audio_capture.py            # Interfaces with loopback and mic audio drivers
├── audio_meter.py              # Visual audio level measuring utility
├── flutter_server.py           # FastAPI and WebSocket application server
├── nim_api.py                  # Core Model Router & Audio Processor
├── shared_pyaudio.py           # Shared PyAudio instance
└── requirements.txt            # Python environment dependencies
```

## Key Components

### 1. `flutter_server.py`
This module acts as the networking entry point. It hosts a local server (`http://127.0.0.1:8000`) built with FastAPI and Uvicorn.
- **REST APIs**: It provides an API layout to fetch system audio devices, adjust volumes, and trigger translation sessions via the `/start` and `/stop` endpoints. Settings inputs such as `transcription_model`, `translation_model`, `target_lang`, `api_key` are extracted from the payload HTTP bodies.
- **WebSocket Endpoint (`/ws/captions`)**: Manages real-time bidirectional messaging for publishing the translated payload back to the Flutter UI asynchronously.

### 2. `nim_api.py`
The overarching orchestration core for AI routing.
- **Model Orchestration**: Determines which ASR (Automatic Speech Recognition) classes and which translation model classes to dynamically instantiate based on the user's preferences.
- **Data Pipeline**: Transports chunks of captured audio data into the ASR models. Transports the decoded string payload from ASR sequentially into the Translation models.
- **Decoupled Engine Logic**: Enforces a rigid structure splitting operations strictly between ASR parsing and NLP translating, minimizing vendor-lock integration challenges.

### 3. Audio Handlers (`audio_capture.py`)
Utilizes libraries to hook directly into the user's OS audio system.
- Leverages OS-level "Loopback" mapping logic (via `sounddevice` / `pyaudio`) to grab raw audio from desktop output (like a YouTube video playing).
- Provides capture features to support native USB microphone hardware seamlessly.

### 4. Language Models (`models/`)
Modular implementations representing different vendor layers:
- **`SpeechRecognitionModel`**: Standard Python API proxy connecting to cloud ASR services like Google.
- **`WhisperModel`**: A self-dependent transcription implementation capable of dynamically downloading and loading OpenAI Whisper variants (tiny, base, small, medium) directly into server RAM.
- **`LlamaModel`, `RivaModel`**: Adapters communicating natively with the NVIDIA NIM endpoints using `openai` API patterns.
- **`GoogleModel`, `MyMemoryModel`**: Abstracted clients translating unstructured text chunks over generalized web APIs.

## Data Flow
1. The Flutter client issues a `/start` REST call specifying the target language, audio source, and desired AI backends (`transcription_model` & `translation_model`).
2. `flutter_server.py` initializes the `NimApiClient` from `nim_api.py`, injecting the given user configurations.
3. The specified audio capture interface engages the system driver and grabs raw `bytes`/`NumPy` audio streams continuously.
4. The streams funnel into the specified ASR model.
5. Detected textual transcripts hit the specified generic Translation model.
6. The compiled results `{"originalText": ..., "translatedText": ..., "isFinal": ...}` are broadcast sequentially out of the WebSocket channel for the Flutter UI.
