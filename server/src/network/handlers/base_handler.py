# Copyright (c) 2026 Omni Bridge. All rights reserved.

import asyncio
from typing import Dict, Any, Optional
from src.pipeline import InferenceOrchestrator
from src.audio.capture import AudioCapture
from src.audio.meter import AudioMeter

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

    def reset(self):
        """Clears user-specific configuration and the orchestrator to ensure a fresh session."""
        self.orchestrator = None
        self.config["api_key"] = ""
        self.config["google_credentials_json"] = ""
        self.is_running = False
        self.session_id = 0
        # Revert to defaults
        self.config["source_lang"] = "auto"
        self.config["target_lang"] = "en"
        self.config["ai_engine"] = "google"
        self.config["transcription_model"] = "online"
        self.config["translation_model"] = "google"

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
