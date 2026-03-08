# Python Server Architecture

## Overview

The Python server is the local backend for Omni Bridge. It captures system audio (or microphone), runs ASR and translation, and streams results to the Flutter UI via WebSocket.

---

## Directory Structure

```
server/
├── models/
│   ├── google_model.py         # Google Translate (via deep-translator)
│   ├── llama_model.py          # Llama 3.1 via NVIDIA NIM (OpenAI-compatible)
│   ├── mymemory_model.py       # MyMemory free REST translation API
│   ├── riva_model.py           # NVIDIA Riva NMT + ASR
│   ├── speech_recognition_model.py  # Google Cloud Speech (online ASR)
│   └── whisper_model.py        # Offline Whisper ASR (tiny/base/small/medium)
├── audio_capture.py            # WASAPI loopback + mic capture (pyaudiowpatch)
├── audio_meter.py              # Real-time audio level monitoring
├── flutter_server.py           # WebSocket server entry point
├── nim_api.py                  # Core model router and ASR→Translation pipeline
├── shared_pyaudio.py           # Shared PyAudio instance (avoids conflicts)
└── requirements.txt
```

**Whisper cache:** `~/.cache/whisper/` (`.pt` files, auto-downloaded)

---

## Key Components

### `flutter_server.py`
WebSocket server (`ws://127.0.0.1:8765`). Handles all command routing from the Flutter client:
- `start` — starts audio capture + ASR + translation pipeline
- `stop` — stops all processing
- `settings` — hot-updates model / language / device config
- `get_devices` — returns available audio input/output devices
- Streams JSON caption events back to connected Flutter clients

### `nim_api.py`
Core pipeline orchestrator:
- Dynamically loads the configured ASR model and translation model
- Feeds audio chunks from `audio_capture.py` → ASR model → translation model
- Broadcasts `{ originalText, translatedText, isFinal, stats }` payloads
- Manages model switching without full restart
- **Offline Model Memory Management**: Explicitly unloads Whisper offline models from memory when switching to other engines to release system resources.

### `audio_capture.py`
- **Desktop loopback**: captures system audio via WASAPI (Windows-only, `pyaudiowpatch`)
- **Microphone**: captures mic input via standard PyAudio
- Volume scaling applied before sending to ASR
- **Hybrid Audio Chunking**: Implements a dual-trigger flushing strategy for ASR chunks:
  - VAD-based flush: Triggers after 0.5s of silence to reduce latency.
  - Time-based limit: Enforces a maximum duration (e.g., 3.5s) per chunk to guarantee API translation calls even during continuous speech, avoiding rate-limits and stalls.

### `models/`

| Model | Type | Notes |
|-------|------|-------|
| `WhisperModel` | ASR (offline) | 4 sizes, auto-downloaded; resamples to 16kHz |
| `SpeechRecognitionModel` | ASR (online) | Google Cloud Speech via `speech_recognition` |
| `RivaModel` | ASR + Translation | NVIDIA NIM endpoint (API key required) |
| `LlamaModel` | Translation | Llama 3.1 8B via NVIDIA NIM (OpenAI-compatible) |
| `GoogleModel` | Translation | `deep-translator` → Google Translate |
| `MyMemoryModel` | Translation | Free REST API, ~5k chars/day without email |

---

## Data Flow

```
Flutter "start" command
 └─ flutter_server.py → NimApiClient.start()
     └─ audio_capture.py (loopback / mic)
         └─ audio chunks → ASR model
             └─ transcript text → Translation model
                 └─ { originalText, translatedText, isFinal }
                     └─ WebSocket → Flutter UI
```

---

## Same-Language Handling

- **GoogleModel**: when `source == target` (non-auto), the original text is returned directly (no API call) — `deep-translator` rejects same-language pairs
- **MyMemoryModel**: passes through normally; the API returns the original text for same-language pairs

## Environment Variables

| Variable | Used By |
|----------|---------|
| `NVIDIA_API_KEY` | RivaModel, LlamaModel |

Set in `server/.env` (copy from `server/.env.example`).
