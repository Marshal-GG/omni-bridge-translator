<!--
 Copyright (c) 2026 Omni Bridge. All rights reserved.
 
 Licensed under the PERSONAL STUDY & LEARNING LICENSE v1.0.
 Commercial use and public redistribution of modified versions are strictly prohibited.
 See the LICENSE file in the project root for full license terms.
-->

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
- **Hybrid Audio Chunking**: Implements an adaptive dual-trigger flushing strategy for ASR chunks:
  - VAD-based flush: Triggers after 0.3s of silence to reduce latency.
  - Rate-limit adaptive limit: Dynamically enforces a maximum duration per chunk to guarantee API translation calls stay within the NIM 40 RPM account-wide tier.
    - 3.0s chunks if both ASR and Translation use NIM keyed services (2 calls per chunk = 40 RPM).
    - 1.5s chunks if only one service uses NIM (1 call per chunk = 40 RPM).
    - 0.75s chunks if relying purely on free/local services (no limit).

### `models/`

| Model | Type | Notes |
|-------|------|-------|
| `WhisperModel` | ASR (offline) | 4 sizes, auto-downloaded; resamples to 16kHz |
| `SpeechRecognitionModel` | ASR (online) | Google Cloud Speech via `speech_recognition` |
| `RivaModel` | ASR + Translation | NVIDIA NIM `riva-parakeet`/`riva-canary` ASR + `riva-translate-4b-instruct-v1.1` Translation |
| `LlamaModel` | Translation | `meta/llama-3.1-8b-instruct` via NVIDIA NIM (OpenAI-compatible) |
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
                        └─ WebSocket → Flutter UI (Used by HistoryService for 5s context refresh)
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
