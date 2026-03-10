# Copyright (c) 2026 Omni Bridge. All rights reserved.
# 
# Licensed under the PERSONAL STUDY & LEARNING LICENSE v1.0.
# Commercial use and public redistribution of modified versions are strictly prohibited.
# See the LICENSE file in the project root for full license terms.

"""
Flutter Integration: WebSocket Server
Wraps nim_api.py + audio_capture.py and streams translated captions to Flutter over WebSocket.

Install dependencies:
    pip install fastapi uvicorn websockets

Run with:
    python flutter_server.py
"""
import asyncio
import json
import logging
import os
import signal
import sys
import threading
import time
from typing import Set

try:
    import psutil
    HAS_PSUTIL = True
except ImportError:
    HAS_PSUTIL = False

import uvicorn
from fastapi import FastAPI, Request, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware

# Import existing modules (must be in same directory)
from nim_api import NimApiClient
from audio_capture import AudioCapture
from audio_meter import AudioMeter
from models.whisper_model import (
    get_download_status,
    start_download as whisper_start_download,
    delete_model as whisper_delete_model,
)

from contextlib import asynccontextmanager

@asynccontextmanager
async def lifespan(app):
    """Capture the running event loop once uvicorn starts, and install a
    global async exception handler so silent task failures are logged
    instead of killing the process."""
    global _event_loop, _pyaudio_lock
    loop = asyncio.get_running_loop()
    _event_loop = loop
    _pyaudio_lock = asyncio.Lock()

    def _handle_exception(loop, context):
        msg = context.get("exception", context["message"])
        print(f"[asyncio] Unhandled exception in task: {msg}")

    loop.set_exception_handler(_handle_exception)
    yield  # server runs here

app = FastAPI(lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

# --- Active WebSocket connections ---
active_connections: Set[WebSocket] = set()
nim_api: NimApiClient = None
audio_capture: AudioCapture = None
audio_meter: AudioMeter = AudioMeter()
is_running = False
audio_thread = None
_meter_task = None
_event_loop: asyncio.AbstractEventLoop = None  # Set on startup; used by sync callbacks
_pyaudio_lock: asyncio.Lock = None             # Serialises PyAudio opens to avoid WASAPI crash

current_source_lang: str = "auto"
current_target_lang: str = "en"
current_ai_engine: str = "google"            # kept for legacy compat
current_transcription_model: str = "online"  # online | whisper-tiny | whisper-base | whisper-small | whisper-medium
current_translation_model: str = "google"    # google | mymemory | riva | llama
current_api_key: str = ""  # Overridden per-session by the Flutter client
current_use_mic: bool = False
current_input_device_index: int | None = None
current_output_device_index: int | None = None
current_desktop_volume: float = 1.0
current_mic_volume: float = 1.0


async def broadcast(message: dict):
    """Send a JSON message to all connected Flutter clients."""
    dead = set()
    for ws in list(active_connections):
        try:
            await ws.send_text(json.dumps(message))
        except Exception:
            dead.add(ws)
    active_connections.difference_update(dead)


def caption_callback(text, is_error, is_final=True, original_text=None, usage_stats=None):
    """Called by nim_api on each transcript/translation. Broadcasts to all clients.
    This runs in a background sync thread, so we schedule onto uvicorn's event loop."""
    msg = {
        "type": "error" if is_error else "caption",
        "text": text,
        "original": original_text or "",
        "is_final": is_final,
    }
    if _event_loop and not _event_loop.is_closed():
        asyncio.run_coroutine_threadsafe(broadcast(msg), _event_loop)
        # Emit usage stats as a separate message so Flutter can log them independently
        if usage_stats and not is_error and is_final:
            if isinstance(usage_stats, list):
                for stat in usage_stats:
                    if not stat.get("total_tokens"):
                        total_c = stat.get("input_chars", 0) + stat.get("output_chars", 0)
                        stat["total_tokens"] = max(1, total_c // 4) if total_c > 0 else 0

                    stats_msg = {
                        "type": "usage_stats",
                        "source_lang": current_source_lang,
                        "target_lang": current_target_lang,
                        **stat,
                    }
                    asyncio.run_coroutine_threadsafe(broadcast(stats_msg), _event_loop)
            else:
                if not usage_stats.get("total_tokens"):
                    total_c = usage_stats.get("input_chars", 0) + usage_stats.get("output_chars", 0)
                    usage_stats["total_tokens"] = max(1, total_c // 4) if total_c > 0 else 0

                stats_msg = {
                    "type": "usage_stats",
                    "source_lang": current_source_lang,
                    "target_lang": current_target_lang,
                    **usage_stats,
                }
                asyncio.run_coroutine_threadsafe(broadcast(stats_msg), _event_loop)


def audio_poll_loop():
    """Background thread: polls audio capture queue and feeds to nim_api."""
    global is_running, current_source_lang, current_target_lang
    stream_started = False
    try:
        while is_running:
            item = audio_capture.get_audio_chunk()
            if item is not None:
                chunk, sample_rate = item
                if not stream_started:
                    nim_api.start_stream(
                        sample_rate=sample_rate,
                        source_lang=current_source_lang,
                        target_lang=current_target_lang,
                        ai_engine=current_ai_engine,
                        transcription_model=current_transcription_model,
                        translation_model=current_translation_model,
                        callback=caption_callback,
                    )
                    stream_started = True
                nim_api.append_audio(chunk)
            else:
                time.sleep(0.01)
    except Exception as e:
        print(f"[audio_poll_loop] Crashed: {e}")
        is_running = False

async def audio_level_broadcast_loop():
    """Broadcast audio RMS levels to all connected Flutter clients ~13 fps."""
    while is_running:
        msg = {
            "type": "audio_levels",
            "input_level": audio_meter.input_level,
            "output_level": audio_meter.output_level,
        }
        await broadcast(msg)
        await asyncio.sleep(0.075)


# ── Whisper model management endpoints ────────────────────────────────────────

@app.get("/whisper/status")
async def whisper_status(size: str = "base"):
    """Return Whisper model download status."""
    return get_download_status(size)


@app.post("/whisper/download")
async def whisper_download(request: Request):
    """Start background download of a Whisper model."""
    body = {}
    try:
        body = await request.json()
    except Exception:
        pass
    size = body.get("size", "base")
    started = whisper_start_download(size)
    status = get_download_status(size)
    return {"status": "started" if started else status["status"], **status}


@app.get("/whisper/progress")
async def whisper_progress(request: Request):
    """Return current download progress (0–100) for a given model size."""
    size = request.query_params.get("size", "base")
    return get_download_status(size)


@app.delete("/whisper/model")
async def whisper_delete(request: Request):
    """Delete the cached Whisper model for a given size."""
    size = request.query_params.get("size", "base")
    success = whisper_delete_model(size)
    return {"status": "deleted" if success else "error"}


@app.get("/devices")
async def list_devices():
    """Return available mic input (WASAPI only) and loopback output devices."""
    import pyaudiowpatch as pyaudio
    inputs = []
    outputs = []
    default_input_name = "Default"
    default_output_name = "Default"
    # Acquire lock so we don't open PyAudio while audio_capture is initialising
    async with _pyaudio_lock:
        try:
            from shared_pyaudio import get_pyaudio
            p = get_pyaudio()
            # 1. Resolve WASAPI host API index safely
            wasapi_index = -1
            for i in range(p.get_host_api_count()):
                try:
                    hapi = p.get_host_api_info_by_index(i)
                    if hapi.get("type") == pyaudio.paWASAPI:
                        wasapi_index = i
                        break
                except Exception:
                    continue

            if wasapi_index == -1:
                return {"input": [], "output": [], "error": "WASAPI not found"}

            # Resolve default input name
            for i in range(p.get_device_count()):
                try:
                    info = p.get_device_info_by_index(i)
                    name = info.get("name", "")
                    if "Primary Sound Driver" in name or "Microsoft Sound Mapper" in name:
                        continue
                    if info.get("hostApi") == wasapi_index and info.get("maxInputChannels", 0) > 0:
                        default_input_name = name
                        break
                except Exception:
                    continue

            # Resolve default output loopback name
            for loopback in p.get_loopback_device_info_generator():
                name = loopback.get("name", "")
                if "Primary Sound Driver" in name or "Microsoft Sound Mapper" in name:
                    continue
                default_output_name = name.replace(" [Loopback]", "").strip()
                break

            # WASAPI input devices only (no duplicates)
            for i in range(p.get_device_count()):
                try:
                    info = p.get_device_info_by_index(i)
                    name = info.get("name", "")
                    # Filter out virtual mappings that cause PortAudio drift/assertions
                    if "Primary Sound Driver" in name or "Microsoft Sound Mapper" in name:
                        continue

                    if (
                        info.get("hostApi") == wasapi_index
                        and info.get("maxInputChannels", 0) > 0
                        and not info.get("isLoopbackDevice", False)
                    ):
                        inputs.append({"index": i, "name": name})
                except Exception:
                    continue

            # Loopback outputs
            for loopback in p.get_loopback_device_info_generator():
                name = loopback.get("name", "")
                if "Primary Sound Driver" in name or "Microsoft Sound Mapper" in name:
                    continue
                clean_name = name.replace(" [Loopback]", "").strip()
                outputs.append({"index": loopback["index"], "name": clean_name})

        except Exception as e:
            print(f"[/devices] Error: {e}")
    return {
        "input": inputs,
        "output": outputs,
        "default_input_name": default_input_name,
        "default_output_name": default_output_name,
    }


@app.post("/start")
async def start_capture(
    source_lang: str = "auto",
    target_lang: str = "en",
    ai_engine: str = "google",
    use_mic: bool = False,
    input_device_index: int = None,
    output_device_index: int = None,
    api_key: str = "",
    transcription_model: str = "online",
    translation_model: str = "",
):
    global nim_api, audio_capture, is_running, audio_thread, _meter_task
    global current_source_lang, current_target_lang, current_ai_engine, current_use_mic
    global current_input_device_index, current_output_device_index
    global current_desktop_volume, current_mic_volume, current_api_key
    global current_transcription_model, current_translation_model

    current_source_lang = source_lang
    current_target_lang = target_lang
    current_ai_engine = ai_engine
    current_use_mic = use_mic
    current_input_device_index = input_device_index
    current_output_device_index = output_device_index
    current_transcription_model = transcription_model
    current_translation_model = translation_model or ai_engine  # fallback to ai_engine
    # Use the user-supplied key if non-empty
    current_api_key = api_key or ""

    # Guard: Riva/Llama translation requires an API key
    if current_translation_model in ("riva", "llama") and not current_api_key:
        await broadcast({
            "type": "error",
            "text": f"⚠ {current_translation_model.capitalize()} requires an API key. Open Settings → Translation Engine and paste your NVIDIA NIM key.",
            "is_final": True,
            "original": "",
        })
        return {"status": "error", "message": "API key missing"}

    # Serialise against /devices so two PyAudio instances never open at the same time
    async with _pyaudio_lock:
        try:
            if is_running:
                await stop_capture()
                await asyncio.sleep(0.5)

            nim_api = NimApiClient(
                api_key=current_api_key,
            )
            # Adaptive chunk duration — guarantees account-wide NIM usage stays ≤ 40 RPM.
            # NIM's 40 RPM limit is account-wide (shared across all model calls).
            #   2 keyed → 2 API calls per chunk → need ≥ 3.0s  (2 × 20 chunks/min = 40 RPM)
            #   1 keyed → 1 API call per chunk  → need ≥ 1.5s  (1 × 40 chunks/min = 40 RPM)
            #   0 keyed → no NIM calls          → 0.75s (free services, no rate limit)
            _keyed_count = (
                (1 if transcription_model in {"riva"} else 0) +
                (1 if translation_model   in {"riva", "llama"} else 0)
            )
            _chunk_dur = {0: 0.75, 1: 1.5, 2: 3.0}.get(_keyed_count, 1.5)

            audio_capture = AudioCapture(
                sample_rate=16000,
                chunk_duration=_chunk_dur,
                use_mic=current_use_mic,
                input_device_index=current_input_device_index,
                output_device_index=current_output_device_index,
                desktop_volume=current_desktop_volume,
                mic_volume=current_mic_volume,
            )
            is_running = True
            audio_capture.start()
            audio_thread = threading.Thread(target=audio_poll_loop, daemon=True)
            audio_thread.start()

            # Delay meter start by 2 s so audio_capture's WASAPI loopback stream
            # has time to fully open before we try to open a second one in the meter.
            async def _delayed_meter_start():
                await asyncio.sleep(2.0)
                if not is_running:
                    return
                audio_meter.configure(
                    input_device_index=current_input_device_index if current_use_mic else None,
                    output_device_index=current_output_device_index,
                )
                audio_meter.start()

            asyncio.create_task(_delayed_meter_start())
            _meter_task = asyncio.create_task(audio_level_broadcast_loop())

            return {"status": "started", "source": source_lang, "target": target_lang, "use_mic": current_use_mic}

        except Exception as e:
            print(f"[start_capture] Error: {e}")
            is_running = False
            await broadcast({"type": "error", "text": f"Failed to start capture: {e}", "is_final": True, "original": ""})
            return {"status": "error", "message": str(e)}


@app.post("/stop")
async def stop_capture():
    global is_running, nim_api, audio_capture, _meter_task
    is_running = False
    if _meter_task:
        _meter_task.cancel()
        _meter_task = None
    audio_meter.stop()
    if audio_capture:
        audio_capture.stop()
    if nim_api:
        nim_api.stop_stream()
    return {"status": "stopped"}


@app.get("/status")
async def get_status():
    return {"running": is_running, "clients": len(active_connections)}


# ── WebSocket endpoint ──────────────────────────────────────────────────────

@app.websocket("/captions")
async def captions_ws(websocket: WebSocket):
    """Flutter connects here and receives captions as JSON frames."""
    global current_desktop_volume, current_mic_volume
    await websocket.accept()
    active_connections.add(websocket)
    try:
        # Keep connection alive; handle control messages from Flutter
        while True:
            data = await websocket.receive_text()
            msg = json.loads(data)
            # Flutter can send {"cmd": "start", "source": "auto", "target": "en"}
            if msg.get("cmd") in ("start", "settings_update"):
                # Parse volume multipliers (1.0 = no change, 0.0 = silence, 2.0 = double)
                current_desktop_volume = float(msg.get("desktop_volume", 1.0))
                current_mic_volume = float(msg.get("mic_volume", 1.0))
                await start_capture(
                    source_lang=msg.get("source", "auto"),
                    target_lang=msg.get("target", "en"),
                    ai_engine=msg.get("ai_engine", "google"),
                    use_mic=msg.get("use_mic", False),
                    input_device_index=msg.get("input_device_index"),
                    output_device_index=msg.get("output_device_index"),
                    api_key=msg.get("api_key", ""),
                    transcription_model=msg.get("transcription_model", "online"),
                    translation_model=msg.get("translation_model", ""),
                )
            elif msg.get("cmd") == "volume_update":
                # Lightweight volume change — no restart, just update the running capture
                current_desktop_volume = float(msg.get("desktop_volume", current_desktop_volume))
                current_mic_volume = float(msg.get("mic_volume", current_mic_volume))
                if audio_capture:
                    audio_capture.desktop_volume = max(0.0, current_desktop_volume)
                    audio_capture.mic_volume = max(0.0, current_mic_volume)
            elif msg.get("cmd") == "stop":
                await stop_capture()
    except WebSocketDisconnect:
        active_connections.discard(websocket)
    except Exception as exc:
        print(f"[WebSocket] Unhandled error: {exc}")
        active_connections.discard(websocket)


def kill_process_on_port(port: int):
    """Kill any process listening on the given port using netstat + taskkill (Windows).
    Works without psutil."""
    import subprocess
    try:
        result = subprocess.run(
            ["netstat", "-ano"],
            capture_output=True, text=True, timeout=5
        )
        current_pid = str(os.getpid())
        for line in result.stdout.splitlines():
            if f":{port}" in line and "LISTENING" in line:
                parts = line.split()
                pid = parts[-1]
                if pid == current_pid:
                    continue
                print(f"[Main] Killing process on port {port} (PID: {pid})")
                subprocess.run(["taskkill", "/F", "/PID", pid],
                               capture_output=True, timeout=5)
    except Exception as e:
        print(f"[Main] Port cleanup failed: {e}")


def kill_other_instances():
    """Find and kill other running instances of this server to prevent port conflicts."""
    # Always free the port first — works without psutil
    kill_process_on_port(8765)

    if not HAS_PSUTIL:
        return

    current_pid = os.getpid()
    target_exe = "omni_bridge_server.exe"

    print(f"[Main] Checking for existing instances (Current PID: {current_pid})...")

    for proc in psutil.process_iter(['pid', 'name']):
        try:
            pinfo = proc.info
            pid = pinfo['pid']
            name = pinfo['name']

            if pid == current_pid:
                continue

            # ONLY kill the packaged EXE. User requested not to touch python.exe.
            if name == target_exe:
                print(f"[Main] Terminating stale instance: {name} (PID: {pid})")
                proc.terminate()
                try:
                    proc.wait(timeout=3)
                except psutil.TimeoutExpired:
                    print(f"[Main] Force killing PID {pid}")
                    proc.kill()
        except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
            continue

if __name__ == "__main__":
    kill_other_instances()
    uvicorn.run(app, host="127.0.0.1", port=8765)
