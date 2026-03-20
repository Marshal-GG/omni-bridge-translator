# Copyright (c) 2026 Omni Bridge. All rights reserved.

import asyncio
import logging
import threading
from typing import Dict, Any

from .base_handler import BaseHandler
from src.pipeline import InferenceOrchestrator
from src.audio.capture import AudioCapture
from src.audio.handler import (
    audio_poll_loop, 
    audio_level_broadcast_loop, 
    status_broadcast_loop,
    caption_callback
)

class SessionHandler(BaseHandler):
    async def start(self, websocket, msg: Dict[str, Any]):
        # Update config from message
        updates = {
            "source_lang": msg.get("source"),
            "target_lang": msg.get("target"),
            "translation_model": msg.get("translation_model") or msg.get("ai_engine"),
            "transcription_model": msg.get("transcription_model"),
            "api_key": msg.get("api_key"),
            "google_credentials_json": msg.get("google_credentials_json"),
            "use_mic": msg.get("use_mic"),
            "input_device_index": msg.get("input_device_index"),
            "output_device_index": msg.get("output_device_index"),
            "desktop_volume": msg.get("desktop_volume"),
            "mic_volume": msg.get("mic_volume"),
        }

        for key, value in updates.items():
            if value is not None:
                self.ctx.config[key] = value
        
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
                _chunk_dur = 3.0
            else:
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
