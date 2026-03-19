# Copyright (c) 2026 Omni Bridge. All rights reserved.

import asyncio
import logging
import threading
import json
from typing import Dict, Any, Optional

from src.network.orchestrator import InferenceOrchestrator
from src.audio.capture import AudioCapture
from src.audio.meter import AudioMeter
from src.audio.handler import (
    audio_poll_loop, 
    audio_level_broadcast_loop, 
    status_broadcast_loop,
    caption_callback
)

class ServerContext:
    """Holds global server state to avoid global variables in entry point."""
    def __init__(self, manager):
        self.manager = manager
        self.orchestrator: Optional[InferenceOrchestrator] = None
        self.audio_capture: Optional[AudioCapture] = None
        self.audio_meter: AudioMeter = AudioMeter()
        self.is_running = False
        self.session_id = 0
        self.pyaudio_lock = asyncio.Lock()
        self.meter_task: Optional[asyncio.Task] = None
        
        # Current Configuration
        self.config = {
            "source_lang": "auto",
            "target_lang": "en",
            "ai_engine": "google",
            "transcription_model": "online",
            "translation_model": "google",
            "api_key": "",
            "google_credentials_json": "",
            "use_mic": False,
            "input_device_index": None,
            "output_device_index": None,
            "desktop_volume": 1.0,
            "mic_volume": 1.0,
        }

    def get_server_context(self):
        """Returns context for audio_poll_loop."""
        return {
            "session_id": self.session_id,
            "source_lang": self.config["source_lang"],
            "target_lang": self.config["target_lang"],
            "ai_engine": self.config["ai_engine"],
            "transcription_model": self.config["transcription_model"],
            "translation_model": self.config["translation_model"],
            "initial_suspension": False,
        }

class BaseHandler:
    def __init__(self, context: ServerContext):
        self.ctx = context

class SessionHandler(BaseHandler):
    async def start(self, websocket, msg: Dict[str, Any]):
        # Update config from message
        # Map client keys (source, target) to internal config keys (source_lang, target_lang)
        if "source" in msg:
            self.ctx.config["source_lang"] = msg["source"]
        if "target" in msg:
            self.ctx.config["target_lang"] = msg["target"]

        for key in self.ctx.config:
            if key in msg:
                self.ctx.config[key] = msg[key]
        
        # derive models
        if not msg.get("translation_model"):
            self.ctx.config["translation_model"] = msg.get("ai_engine", self.ctx.config["ai_engine"])
        
        # Validations
        tl_model = str(self.ctx.config.get("translation_model") or "unknown")
        if self.ctx.config.get("translation_model") in ("riva", "llama") and not self.ctx.config.get("api_key"):
            await self.ctx.manager.broadcast({
                "type": "error",
                "text": f"⚠ {tl_model.capitalize()} requires an NVIDIA API key.",
                "is_final": True,
                "original": "",
            })
            return

        async with self.ctx.pyaudio_lock:
            if self.ctx.is_running:
                await self.stop(websocket, msg)
                await asyncio.sleep(0.5)

            self.ctx.session_id += 1
            if self.ctx.orchestrator is None:
                self.ctx.orchestrator = InferenceOrchestrator(
                    nvidia_api_key=self.ctx.config["api_key"],
                    google_credentials_json=self.ctx.config["google_credentials_json"]
                )
            else:
                self.ctx.orchestrator.set_api_keys(self.ctx.config["api_key"], self.ctx.config["google_credentials_json"])

            is_nim_asr = self.ctx.config["transcription_model"] == "riva"
            is_nim_trans = self.ctx.config["translation_model"] in ("riva", "llama")
            num_nim = (1 if is_nim_asr else 0) + (1 if is_nim_trans else 0)

            if self.ctx.config["transcription_model"] == "online":
                _chunk_dur = 3.2
            elif num_nim == 2:
                # Both ASR and Translation are NIM - use 3.0s to stay under 40 RPM total
                _chunk_dur = 3.0
            else:
                # 1 NIM or local models - 1.5s is safe (40 RPM) and very responsive
                _chunk_dur = 1.5
            _first_chunk_dur = min(_chunk_dur, 1.0)
            
            logging.info(
                f"[Handler] Calculated chunk_duration: {_chunk_dur}s "
                f"(first chunk: {_first_chunk_dur}s, NIM models: {num_nim})"
            )

            self.ctx.audio_capture = AudioCapture(
                sample_rate=16000,
                chunk_duration=_chunk_dur,
                first_chunk_duration=_first_chunk_dur,
                use_mic=self.ctx.config["use_mic"],
                input_device_index=self.ctx.config["input_device_index"],
                output_device_index=self.ctx.config["output_device_index"],
                desktop_volume=self.ctx.config["desktop_volume"],
                mic_volume=self.ctx.config["mic_volume"],
            )


            self.ctx.is_running = True
            self.ctx.audio_capture.start()

            # Capture the running loop to pass to background threads
            loop = asyncio.get_running_loop()

            def wrap_callback(*args, **kwargs):
                caption_callback(*args, **kwargs, 
                                 event_loop=loop, 
                                 manager=self.ctx.manager, 
                                 session_id=self.ctx.session_id,
                                 source_lang=self.ctx.config["source_lang"],
                                 target_lang=self.ctx.config["target_lang"])

            threading.Thread(
                target=audio_poll_loop,
                args=(self.ctx.session_id, lambda: self.ctx.is_running, self.ctx.audio_capture, 
                      self.ctx.orchestrator, self.ctx.get_server_context, wrap_callback),
                daemon=True
            ).start()

            await self._start_metering()
            await self.ctx.manager.broadcast_status(self.ctx.orchestrator)
            logging.info(f"[Handler] Started session {self.ctx.session_id}")

    async def _start_metering(self):
        await asyncio.sleep(2.0)
        if not self.ctx.is_running: return
        self.ctx.audio_meter.configure(
            input_device_index=self.ctx.config["input_device_index"] if self.ctx.config["use_mic"] else None,
            output_device_index=self.ctx.config["output_device_index"]
        )
        self.ctx.audio_meter.start()
        self.ctx.meter_task = asyncio.create_task(audio_level_broadcast_loop(lambda: self.ctx.is_running, self.ctx.audio_meter, self.ctx.manager))
        asyncio.create_task(status_broadcast_loop(lambda: self.ctx.is_running, self.ctx.manager, self.ctx.orchestrator))

    async def stop(self, websocket, msg: Dict[str, Any]):
        self.ctx.is_running = False
        if self.ctx.meter_task:
            self.ctx.meter_task.cancel()
            self.ctx.meter_task = None
        self.ctx.audio_meter.stop()
        if self.ctx.audio_capture:
            self.ctx.audio_capture.stop()
        if self.ctx.orchestrator:
            self.ctx.orchestrator.stop_stream()
        logging.info("[Handler] Stopped session")

class ConfigHandler(BaseHandler):
    async def update_settings(self, websocket, msg: Dict[str, Any]):
        new_source = msg.get("source", self.ctx.config["source_lang"])
        new_target = msg.get("target", self.ctx.config["target_lang"])
        new_engine = msg.get("ai_engine", self.ctx.config["ai_engine"])
        new_mic = msg.get("use_mic", self.ctx.config["use_mic"])
        new_key = msg.get("api_key", self.ctx.config["api_key"])
        new_trans = msg.get("transcription_model", self.ctx.config["transcription_model"])
        new_tl = msg.get("translation_model", self.ctx.config["translation_model"])
        new_google_creds = msg.get("google_credentials_json", self.ctx.config["google_credentials_json"])

        has_changed = (
            self.ctx.config["source_lang"] != new_source or
            self.ctx.config["target_lang"] != new_target or
            self.ctx.config["ai_engine"] != new_engine or
            self.ctx.config["use_mic"] != new_mic or
            self.ctx.config["api_key"] != new_key or
            self.ctx.config["transcription_model"] != new_trans or
            self.ctx.config["translation_model"] != new_tl or
            self.ctx.config["google_credentials_json"] != new_google_creds
        )

        self.ctx.config.update({
            "source_lang": new_source,
            "target_lang": new_target,
            "ai_engine": new_engine,
            "use_mic": new_mic,
            "api_key": new_key,
            "transcription_model": new_trans,
            "translation_model": new_tl,
            "google_credentials_json": new_google_creds,
        })

        if self.ctx.is_running and has_changed:
            logging.info("[Handler] Settings changed while running. Restarting...")
            await SessionHandler(self.ctx).start(websocket, self.ctx.config)
        elif not self.ctx.is_running:
            if self.ctx.orchestrator:
                self.ctx.orchestrator.set_api_keys(new_key, self.ctx.config["google_credentials_json"])
                await self.ctx.manager.broadcast_status(self.ctx.orchestrator)

    async def update_volume(self, websocket, msg: Dict[str, Any]):
        self.ctx.config["desktop_volume"] = float(msg.get("desktop_volume", self.ctx.config["desktop_volume"]))
        self.ctx.config["mic_volume"] = float(msg.get("mic_volume", self.ctx.config["mic_volume"]))
        if self.ctx.audio_capture:
            self.ctx.audio_capture.desktop_volume = max(0.0, self.ctx.config["desktop_volume"])
            self.ctx.audio_capture.mic_volume = max(0.0, self.ctx.config["mic_volume"])

class DeviceHandler(BaseHandler):
    async def get_device_list(self):
        """Returns the list of input and output devices."""
        import pyaudiowpatch as pyaudio
        inputs, outputs = [], []
        async with self.ctx.pyaudio_lock:
            try:
                from src.audio.shared_pyaudio import get_pyaudio
                p = get_pyaudio()
                wasapi_index = -1
                for i in range(p.get_host_api_count()):
                    if p.get_host_api_info_by_index(i).get("type") == pyaudio.paWASAPI:
                        wasapi_index = i
                        break

                if wasapi_index == -1:
                    return {"error": "WASAPI not found"}

                for i in range(p.get_device_count()):
                    info = p.get_device_info_by_index(i)
                    name = info.get("name", "")
                    if "Primary Sound Driver" in name or "Microsoft Sound Mapper" in name: continue
                    if info.get("hostApi") == wasapi_index and info.get("maxInputChannels", 0) > 0 and not info.get("isLoopbackDevice", False):
                        inputs.append({"index": i, "name": name})
                
                for loopback in p.get_loopback_device_info_generator():
                    name = loopback.get("name", "")
                    if "Primary Sound Driver" in name or "Microsoft Sound Mapper" in name: continue
                    outputs.append({"index": loopback["index"], "name": name.replace(" [Loopback]", "").strip()})

                return {
                    "input": inputs,
                    "output": outputs
                }
            except Exception as e:
                logging.error(f"[Handler] Device listing error: {e}")
                return {"error": str(e)}

    async def list_devices(self, websocket, msg: Dict[str, Any]):
        devices = await self.get_device_list()
        await websocket.send_text(json.dumps({
            "type": "devices",
            **devices
        }))

class StatusHandler(BaseHandler):
    async def get_system_status(self):
        """Basic health check and session info."""
        return {
            "status": "online",
            "session_id": self.ctx.session_id,
            "is_running": self.ctx.is_running,
            "active_clients": len(self.ctx.manager.active_connections)
        }

    async def get_model_status(self):
        """Physical model health and capabilities."""
        # Lazy init orchestrator if needed for health check
        if not self.ctx.orchestrator:
            self.ctx.orchestrator = InferenceOrchestrator(
                nvidia_api_key=self.ctx.config["api_key"],
                google_credentials_json=self.ctx.config["google_credentials_json"]
            )
        
        return {
            "type": "models_status",
            "models": self.ctx.orchestrator.get_all_statuses()
        }

    async def whisper_unload(self):
        """Unload Whisper model from memory."""
        if self.ctx.orchestrator:
            self.ctx.orchestrator.whisper_unload()
            return {"status": "unloaded"}
        return {"status": "no_orchestrator"}
