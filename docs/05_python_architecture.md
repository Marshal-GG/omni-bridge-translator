# Python Server Architecture

## Overview

The Python server is the local backend for Omni Bridge. It captures system audio (or microphone), runs ASR (Automatic Speech Recognition) and translation, and streams results to the Flutter UI via WebSocket.

The server uses an **Asynchronous Modular Architecture** built on **FastAPI** and **uvicorn**, allowing for high-concurrency WebSocket management and non-blocking command execution.

---

## Directory Structure

```
server/
├── src/
│   ├── asr/
│   │   └── asr_dispatcher.py   # ASR model selection & audio chunk processing
│   ├── translation/
│   │   └── translation_dispatcher.py # Language detection & translation fallback logic
│   ├── audio/
│   │   ├── capture.py          # WASAPI loopback + mic capture (pyaudiowpatch) with VAD
│   │   ├── handler.py          # caption_callback, audio_poll_loop, level/status broadcast coroutines
│   │   ├── meter.py            # Real-time independent RMS metering for Mic & Output (dB-normalized 0.0–1.0)
│   │   └── shared_pyaudio.py   # Thread-safe global PyAudio singleton
│   ├── network/
│   │   ├── orchestrator.py     # Coordination layer delegating to dispatchers
│   │   ├── ws_manager.py       # WebSocket connection & heartbeat management
│   │   ├── router.py           # Command routing (Decouples WS from logic)
│   │   ├── base_handler.py     # Shared BaseHandler and ServerContext
│   │   ├── session_handler.py  # Session lifecycle (start/stop)
│   │   ├── config_handler.py   # Settings and Volume management
│   │   ├── device_handler.py   # Audio device enumeration
│   │   └── status_handler.py   # Health and model status reporting
│   ├── utils/
│   │   ├── server_utils.py     # structlog setup, process management
│   │   └── language_support.py # Single source of truth for all model language support
│   └── models/
│       ├── asr/
│       │   ├── local_asr.py           # Google Speech Recognition (online fallback)
│       │   ├── riva_asr.py            # NVIDIA Riva ASR implementation
│       │   └── whisper_asr.py         # Local Faster-Whisper ASR implementation
│       └── translation/
│           ├── google_api_translation.py # Google Cloud Translation gRPC v3
│           ├── google_free_translation.py# Google Translate (Free, via deep-translator)
│           ├── llama_translation.py      # NVIDIA NIM (Llama 3.1 8B) 
│           ├── mymemory_translation.py   # MyMemory public REST API
│           └── riva_nmt.py               # NVIDIA Riva NMT implementation
├── flutter_server.py           # FastAPI Entry point & Handshake
└── pyproject.toml              # Modern dependency management
```

---

## Key Components

### `flutter_server.py` & `ServerContext`
The server uses a **Dependency Injection**-like pattern via `ServerContext`.
- **ServerContext**: Encapsulates all global state (orchestrator, audio capture, metering, active config). This prevents "global variable hell" and ensures thread safety.
- **Capabilities Handshake**: Upon WebSocket connection, the server immediately emits a `capabilities` message detailing GPU availability, VRAM, and authenticated AI engines.

### Command Routing (`router.py` & Modular Handlers)
Incoming JSON commands are dispatched by the `CommandRouter` to specialized modular handlers in `src/network/`:
- **SessionHandler** (`session_handler.py`): Manages the lifecycle of an audio session (`start`/`stop`). It calculates the optimal audio chunk duration based on the selected AI engines to balance latency vs. API rate limits.
- **ConfigHandler** (`config_handler.py`): Updates settings (languages, keys, devices) in real-time. If settings change during an active session, it triggers a seamless restart.
- **DeviceHandler** (`device_handler.py`): Enumerates WASAPI input and loopback devices for the Flutter UI.
- **StatusHandler** (`status_handler.py`): Manages real-time health reporting. It provides standardized status payloads for both background broadcasting and on-demand HTTP polling.

### Audio Pipeline (`capture.py` & `meter.py`)
- **Adaptive Chunking**: `AudioCapture` uses a combination of **Voice Activity Detection (VAD)** and time-based flushing. It flushes early when silence follows speech (lowering latency) but guarantees a flush at `MAX_CHUNK_DURATION` to ensure constant feedback.
- **Volume Scaling**: Real-time gain application for both Mic and Desktop audio before mixing.
- **Dual Metering**: `AudioMeter` runs independent threads to provide RMS levels for both microphone and system output, used by the UI volume visualizers.

### Language Support (`utils/language_support.py`)
Single source of truth for all model language capabilities — imported by both models and the orchestrator. No model defines its own language sets.

| Constant | Purpose |
|---|---|
| `LANG_TO_BCP47` | Maps 23 app language codes (`"hi"` → `"hi-IN"`, `"he"` → `"he-IL"`, `"da"` → `"da-DK"`, `"cs"` → `"cs-CZ"`, `"sv"` → `"sv-SE"`, etc.) to BCP-47 for Riva ASR configs |
| `RIVA_PARAKEET_ASR_LANGS` | BCP-47 codes routed to the Parakeet model (includes `en-US`, `es-US`, `fr-FR`, `de-DE`, `it-IT`, `ar-AR`, `ko-KR`, `pt-BR`, `ru-RU`, `hi-IN`, `nl-NL`, `da-DK`, `cs-CZ`, `pl-PL`, `sv-SE`, `th-TH`, `tr-TR`, `he-IL`, `bn-IN`, and more); all others (including `"multi"` for auto-detect) go to Canary |
| `RIVA_NMT_LANGS` | App-level codes supported by Riva NMT: `en, de, es, fr, pt, ru, zh, ja, ko, ar` (both source and target must be in this set) |
| `GOOGLE_FREE_LANGS` / `GOOGLE_CLOUD_LANGS` / `MYMEMORY_LANGS` / `LLAMA_LANGS` | `None` — these models are unrestricted within the app language list |

### AI Orchestration (`orchestrator.py`)
Acts as a thin coordinator delegating tasks to specialized dispatchers.
- **ASR Dispatching** (`ASRDispatcher`): Handles selection of ASR models (Riva, Whisper, Google Free), audio preprocessing, and result aggregation.
- **Translation Dispatching** (`TranslationDispatcher`): Manages language detection scripts, model fallback trees, and translation execution (Riva, Llama, Google, MyMemory).
- **Background Thread Stability**: Implements a robust "Event Loop Capturing" pattern to ensure background threads can safely schedule callbacks in the main FastAPI loop.
- **Queue Resilience**: Worker threads gracefully handle `queue.Empty` timeouts, preventing crashes during periods of silence.
- **Speech Polishing**: Employs `pysbd` to segment text and a deduplication algorithm (`_clean_stutters`), which removes repetitions.
- **ASR Hallucination Prevention** (three-layer defence):
  1. **RMS Gate** — chunks with RMS < 120 are dropped before reaching ASR.
  2. **Confidence Filter** — Riva results with confidence < 0.5 are discarded.
  3. **Time-Window Deduplication** — identical transcripts within a short window are suppressed.

### Audio Handler (`handler.py`)
Bridges the async FastAPI event loop with background worker threads:
- **`caption_callback()`** — Called by orchestrator for each transcript/translation. Broadcasts caption JSON to all WebSocket clients and calculates total tokens from engine-specific metrics.
- **`audio_poll_loop()`** — Background thread that polls audio chunks from `AudioCapture` and feeds them to the orchestrator. Detects session superseding for clean restarts.
- **`audio_level_broadcast_loop()`** — Async coroutine broadcasting RMS audio levels to clients (~13 fps).
- **`status_broadcast_loop()`** — Async coroutine broadcasting model health status every 2 seconds.

---

## WebSocket Message Protocol

### Messages Sent to Clients

| Type | Purpose | Key Fields |
|---|---|---|
| `capabilities` | Sent on connect | `has_gpu`, `gpu_name`, `vram_gb`, `has_google_auth`, `has_nvidia_auth`, `whisper_models` |
| `caption` | Transcript/translation result | `text`, `original`, `is_final`, `session_id` |
| `usage_stats` | Per-call engine metrics | `engine`, `model`, `latency_ms`, `input_tokens`, `output_tokens`, `total_tokens` |
| `audio_levels` | Real-time RMS levels | `input_level` (0.0–1.0), `output_level` (0.0–1.0) |
| `model_status` | Model health broadcast | `models[]` with `name`, `status`, `ready`, `progress` |
| `error` | Error message | `text`, `is_final`, `original` |

### Commands Received from Clients

| Command | Purpose | Key Fields |
|---|---|---|
| `start` | Begin audio session | `source`, `target`, `transcription_model`, `translation_model`, `use_mic`, `api_key`, `google_credentials_json` |
| `stop` | End audio session | (none) |
| `settings_update` | Change settings mid-session | Same as `start` (triggers restart if running) |
| `volume_update` | Adjust gain in real-time | `desktop_volume`, `mic_volume` |
| `list_devices` | Enumerate WASAPI devices | (none) |

---

## Data Flow

```mermaid
sequenceDiagram
    participant C as Flutter Client
    participant S as FastAPI Server
    participant R as Command Router
    participant H as Handlers
    participant O as Orchestrator
    participant A as AudioCapture

    C->>S: Connect (WS)
    S->>C: Handshake (Capabilities)
    C->>S: Start Command (JSON)
    S->>R: Route("start")
    R->>H: SessionHandler.start(config)
    H->>O: Initialize / Update Credentials
    H->>A: Start(VAD + Resampling)
    A->>O: Push Audio Chunks
    O->>O: ASR -> Speech Polish -> Translation
    O->>C: Stream Captions (JSON)
```

### Google Cloud Credentials Pipeline

The `google_cloud_model.py` module uses the **Google Cloud Translation gRPC v3** API (`google.cloud.translate_v3.TranslationServiceClient`). Credentials flow:

1. Flutter sends the full service account JSON string via WebSocket (`google_credentials_json` key).
2. `ConfigHandler` passes it to `InferenceOrchestrator.set_api_keys()`.
3. `GoogleCloudModel.reload()` parses the JSON with `json.loads()`, extracts `project_id`, and creates a gRPC client via `service_account.Credentials.from_service_account_info()`.
4. Error handling is sanitized — `json.JSONDecodeError` logs a generic message, other exceptions log only `type(e).__name__` to prevent credential leakage in logs.

---

## Resilient Fallback Strategy

The `InferenceOrchestrator` implements a priority-based fallback system:

1. **Transcription**:
   - `riva` (High Quality/Low Latency) — routes to Parakeet or Canary based on `RIVA_PARAKEET_ASR_LANGS`
   - `whisper` (Local Fallback - Small/Medium)
   - `online` (Google Speech Recognition - Universal Fallback)

2. **Translation** — clean separation of concerns:
   - Each model (`riva_model`, `llama_model`) only executes its own engine and **raises** on failure.
   - All routing and fallback logic lives exclusively in `orchestrator._dispatch_translation()`.
   - `google_api` → `google` (free) on failure
   - `riva` — pre-checks `RIVA_NMT_LANGS`; if unsupported pair, goes directly to `llama`. If Riva call itself fails, falls back to `llama`. If `llama` also fails, caption is **silently dropped** (never broadcasts original text).
   - `mymemory` → `google` (free) on failure
   - `google` (free) → `llama` on failure
   - `llama` — raises on any failure; orchestrator drops caption cleanly.

---

## Observability

The server implements structured JSON logging and standard console logging via `server_utils.py`.
- **Log Levels**: 
    - `INFO` (Default): Shows high-level events (server boot, model status, session starts/stops).
    - `DEBUG`: Shows per-event results (ASR completion, Translation stats). Enable with `OMNI_BRIDGE_DEBUG=true`.
- **Log Files**: Located in `logs/server.log` (local) or `%LOCALAPPDATA%\OmniBridge\logs\server.log` (frozen/prod).
- **Latency Tracking**: Every ASR and Translation event logs its processing time and model used at the `DEBUG` level.

---

## Health & Status Endpoints

The server provides **RESTful HTTP endpoints** alongside its primary WebSocket channel for monitoring:

- **`GET /status`**: Returns basic server availability, session info, and the number of active WebSocket clients.
- **`GET /models/status`**: Returns a detailed health manifest of all AI engines (NVIDIA NIM, Faster-Whisper, Google Cloud), including GPU/VRAM utilization and model readiness.
- **`GET /devices`**: Returns available WASAPI audio input and loopback devices (mirrors the WebSocket `get_devices` command).
- **`POST /whisper/unload`**: Unloads the Faster-Whisper model from GPU/RAM to reclaim memory when not in use.
