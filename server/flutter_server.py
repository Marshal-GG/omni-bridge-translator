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
import threading
import os
from typing import Set

from dotenv import load_dotenv

# Load environment variables securely
load_dotenv()

import uvicorn
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware

# Import existing modules (must be in same directory)
from nim_api import NimApiClient
from audio_capture import AudioCapture

app = FastAPI()
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

# --- Active WebSocket connections ---
active_connections: Set[WebSocket] = set()
nim_api: NimApiClient = None
audio_capture: AudioCapture = None
is_running = False
audio_thread = None

# Fetch API key securely from environment
API_KEY = os.getenv("NVIDIA_API_KEY")
if not API_KEY:
    print("WARNING: NVIDIA_API_KEY is not set in .env!")


async def broadcast(message: dict):
    """Send a JSON message to all connected Flutter clients."""
    dead = set()
    for ws in list(active_connections):
        try:
            await ws.send_text(json.dumps(message))
        except Exception:
            dead.add(ws)
    active_connections.difference_update(dead)


def caption_callback(text, is_error, is_final=True, original_text=None):
    """Called by nim_api on each transcript/translation. Broadcasts to all clients."""
    msg = {
        "type": "error" if is_error else "caption",
        "text": text,
        "original": original_text or "",
        "is_final": is_final,
    }
    # Schedule coroutine from sync thread
    asyncio.run(broadcast(msg))


def audio_poll_loop():
    """Background thread: polls audio capture queue and feeds to nim_api."""
    global is_running
    stream_started = False
    while is_running:
        item = audio_capture.get_audio_chunk()
        if item is not None:
            chunk, sample_rate = item
            if not stream_started:
                nim_api.start_stream(
                    sample_rate=sample_rate,
                    source_lang="auto",
                    target_lang="en",
                    callback=caption_callback,
                )
                stream_started = True
            nim_api.append_audio(chunk)
        else:
            import time
            time.sleep(0.01)


# ── REST endpoints ──────────────────────────────────────────────────────────

@app.post("/start")
async def start_capture(source_lang: str = "auto", target_lang: str = "en"):
    global nim_api, audio_capture, is_running, audio_thread
    if is_running:
        return {"status": "already running"}

    nim_api = NimApiClient(api_key=API_KEY)
    audio_capture = AudioCapture(sample_rate=16000, chunk_duration=1.5)
    is_running = True
    audio_capture.start()
    audio_thread = threading.Thread(target=audio_poll_loop, daemon=True)
    audio_thread.start()
    return {"status": "started", "source": source_lang, "target": target_lang}


@app.post("/stop")
async def stop_capture():
    global is_running, nim_api, audio_capture
    is_running = False
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
    await websocket.accept()
    active_connections.add(websocket)
    try:
        # Keep connection alive; handle control messages from Flutter
        while True:
            data = await websocket.receive_text()
            msg = json.loads(data)
            # Flutter can send {"cmd": "start", "source": "auto", "target": "en"}
            if msg.get("cmd") == "start":
                await start_capture(
                    source_lang=msg.get("source", "auto"),
                    target_lang=msg.get("target", "en"),
                )
            elif msg.get("cmd") == "stop":
                await stop_capture()
    except WebSocketDisconnect:
        active_connections.discard(websocket)


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8765)
