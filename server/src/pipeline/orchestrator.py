# Copyright (c) 2026 Omni Bridge. All rights reserved.
# 
# Licensed under the PERSONAL STUDY & LEARNING LICENSE v1.0.
# Commercial use and public redistribution of modified versions are strictly prohibited.
# See the LICENSE file in the project root for full license terms.

"""
orchestrator.py — Simplified coordinator for AI transcription and translation.
Now delegates engine-specific logic to ASRDispatcher and TranslationDispatcher.
"""

import queue
import os
import threading
import logging
import time
import structlog
import pysbd
import numpy as np
from typing import Any, Callable, Dict, List, Optional, Tuple

from src.models.asr import RivaASRModel, WhisperModel, get_gpu_info, SpeechRecognitionModel

from src.models.translation import RivaNMTModel, LlamaModel, GoogleModel, MyMemoryModel, GoogleCloudTranslationModel

from src.asr import ASRDispatcher
from src.translation import TranslationDispatcher
from src.utils import LANG_TO_BCP47

# Valid transcription model IDs
_WHISPER_SIZES = {"whisper-tiny", "whisper-base", "whisper-small", "whisper-medium"}

# BCP-47 language codes mapping
_LANG_MAP = LANG_TO_BCP47


class InferenceOrchestrator:
    """
    Coordinates speech recognition and translation by delegating to specialized dispatchers.
    Handles thread management, resource lifecycle, and overall session flow.
    """

    def __init__(self, nvidia_api_key: str = "", google_credentials_json: str = ""):
        self.nvidia_api_key = nvidia_api_key
        self.google_credentials_json = google_credentials_json
        
        self.logger = structlog.get_logger()

        self.is_running = False
        self.audio_queue: queue.Queue = queue.Queue()
        self._translation_queue: queue.Queue = queue.Queue()
        
        # Models
        self._init_models()

        # Dispatchers
        self.asr_dispatcher = ASRDispatcher(
            riva=self.riva_asr,
            whisper=self.whisper,
            google_free=self.local_asr,
            sample_rate=16000
        )
        self.translation_dispatcher = TranslationDispatcher(
            riva_nmt=self.riva_nmt,
            llama=self.llama,
            google_free=self.google_free,
            mymemory=self.mymemory,
            google_api=self.google_api
        )

        # Session properties
        self._callback: Optional[Callable] = None
        self._sample_rate: int = 16000

    def _init_models(self):
        """Pre-instantiate model wrappers."""
        self.riva_asr = RivaASRModel(self.nvidia_api_key)
        self.riva_nmt = RivaNMTModel(self.nvidia_api_key)
        self.llama = LlamaModel(self.nvidia_api_key)
        self.google_free = GoogleModel()
        self.google_api = GoogleCloudTranslationModel(self.google_credentials_json)
        self.mymemory = MyMemoryModel()
        self.local_asr = SpeechRecognitionModel()
        self.whisper = WhisperModel("base")

    # ── Configuration ────────────────────────────────────────────────────────

    def set_api_keys(self, nvidia_key: str, google_credentials_json: str):
        """Update API keys across all relevant engines."""
        self.nvidia_api_key = nvidia_key
        self.google_credentials_json = google_credentials_json
        
        # Reload models
        self.riva_asr.reload(nvidia_key)
        self.riva_nmt.reload(nvidia_key)
        self.llama.reload(nvidia_key)
        self.google_api.reload(google_credentials_json)

    # ── Stream Control ────────────────────────────────────────────────────────

    def start_stream(
        self,
        sample_rate: int,
        source_lang: str = "auto",
        target_lang: Optional[str] = None,
        ai_engine: str = "google",          # legacy compat
        transcription_model: str = "online",
        translation_model: str = "",        # empty → derive from ai_engine
        callback: Optional[Callable] = None,
        suspended: bool = False,
    ):
        """Initialize and start background worker threads."""
        if self.is_running:
            return

        # Legacy Engine Mapping
        if not translation_model:
            translation_model = {
                "google": "google",
                "llama":  "llama",
                "riva":   "riva",
            }.get(ai_engine, "google")

        # Sync Dispatcher Config
        self.asr_dispatcher.transcription_model = transcription_model.lower().strip()
        self.asr_dispatcher.source_lang = source_lang
        self.asr_dispatcher.whisper_suspended = suspended
        self.asr_dispatcher.sample_rate = sample_rate
        
        self.translation_dispatcher.source_lang = source_lang
        self.translation_dispatcher.target_lang = target_lang
        self.translation_dispatcher.translation_model = translation_model.lower().strip()

        self._sample_rate = sample_rate
        self._callback = callback

        if not self._validate_preflight():
            return

        self.is_running = True
        self.audio_clear()

        # Start Workers
        threading.Thread(target=self._asr_worker, name="ASRWorker", daemon=True).start()
        threading.Thread(target=self._translation_worker, name="TranslationWorker", daemon=True).start()

        logging.info(f"[Orchestrator] Stream started: ASR={self.asr_dispatcher.transcription_model}, Translat={self.translation_dispatcher.translation_model}")

    def stop_stream(self):
        """Signal workers to stop and clear queues."""
        self.is_running = False
        self.audio_queue.put(None)
        self._translation_queue.put(None)

    def audio_clear(self):
        """Empty both ASR and Translation queues."""
        for q in [self.audio_queue, self._translation_queue]:
            while not q.empty():
                try: q.get_nowait()
                except queue.Empty: break

    def append_audio(self, audio_data: bytes):
        """Add new pcm data to the ASR queue."""
        if self.is_running:
            self.audio_queue.put(audio_data)

    def _validate_preflight(self) -> bool:
        """Check requirements for the selected models before starting."""
        asr_model = self.asr_dispatcher.transcription_model
        translation_model = self.translation_dispatcher.translation_model
        
        # Riva ASR Check
        if asr_model == "riva" and not self.riva_asr.is_ready():
            self._emit_error("API Key missing for Riva ASR")
            return False

        # Whisper Check
        if asr_model in _WHISPER_SIZES:
            whisper_size = asr_model.split("-", 1)[1]
            self.whisper.model_size = whisper_size
            if not self.whisper.is_downloaded():
                self._emit_error(f"Whisper {whisper_size} model not downloaded. Open Settings to fix.")
                return False
        else:
            self.whisper.unload_model()

        # Translation Checks
        if translation_model == "google_api" and not self.google_credentials_json:
            self._emit_error("Google Cloud JSON missing. Check Translation settings.")
            return False

        if translation_model in ("riva", "llama") and not self.nvidia_api_key:
            self._emit_error(f"NVIDIA API Key missing for {translation_model}.")
            return False

        return True

    def _emit_error(self, msg: str):
        if self._callback:
            self._callback(f"Error: {msg}", True, is_final=True)

    # ── Workers ──────────────────────────────────────────────────────────────

    def _asr_worker(self):
        """Processes audio chunks into text transcripts via ASRDispatcher."""
        use_auto = self.asr_dispatcher.source_lang == "auto"
        asr_lang = "multi" if use_auto else _LANG_MAP.get(self.asr_dispatcher.source_lang, "en-US")
        
        # Prepare model-specific config (like Riva gRPC config)
        config = self.riva_asr.make_config(self._sample_rate, asr_lang) if self.asr_dispatcher.transcription_model == "riva" else None

        while self.is_running:
            try:
                chunk = self.audio_queue.get(timeout=1.0)
                if chunk is None: break

                # ASRDispatcher now handles byte/ndarray conversion
                asr_result = self.asr_dispatcher.process_chunk(chunk, config)
                
                if asr_result:
                    self._translation_queue.put(asr_result)

            except queue.Empty:
                continue
            except Exception as e:
                logging.error(f"[ASRWorker] Error: {e}")
                self._emit_error(f"ASR Failure: {e}")

    def _translation_worker(self):
        """Processes transcripts into translations via TranslationDispatcher."""
        while self.is_running:
            try:
                item = self._translation_queue.get(timeout=1.0)
                if item is None: break
                
                dwell_time = int((time.time() - item["created_at"]) * 1000)
                text = item["text"]
                asr_stats = item["asr_stats"]

                if self.translation_dispatcher.target_lang and self.translation_dispatcher.target_lang != "none":
                    detected_hint = asr_stats.get("detected_lang") if asr_stats else None
                    translated, trans_stats = self.translation_dispatcher.translate(text, detected_hint)

                    if translated is None:
                        continue

                    if trans_stats:
                        trans_stats["queue_dwell_ms"] = dwell_time

                    stats = [s for s in [asr_stats, trans_stats] if s]
                    if self._callback:
                        self._callback(translated, False, is_final=True, original_text=text, usage_stats=stats)
                else:
                    if self._callback:
                        self._callback(text, False, is_final=True, original_text=text, usage_stats=[asr_stats] if asr_stats else None)

            except queue.Empty:
                continue
            except Exception as e:
                logging.error(f"[TranslationWorker] Error: {e}")
                self._emit_error(f"Translation Failure: {e}")

    # ── Status & Utilities ───────────────────────────────────────────────────

    def whisper_unload(self):
        """Unload Whisper model from memory."""
        self.whisper.unload_model()

    def get_all_statuses(self) -> List[Dict]:
        """Collect statuses from all internal models."""
        statuses = []
        statuses.extend(self.whisper.get_all_statuses())
        
        # GPU Info
        gpu = get_gpu_info()
        statuses.append({
            "name": "system-gpu",
            "status": "available" if gpu["available"] else "unavailable",
            "ready": gpu["available"],
            "message": f"GPU: {gpu['name']}" if gpu["available"] else "No compatible GPU",
            "device_name": gpu["name"],
            "vram_used": gpu.get("vram_used", 0.0),
            "vram_total": gpu.get("vram_total", 0.0),
            "details": gpu
        })
            
        # Combine Riva ASR and NMT status
        asr_status = self.riva_asr.get_status()
        nmt_status = self.riva_nmt.get_status()
        
        combined_riva = {
            "name": "riva",
            "status": "ready" if (asr_status["ready"] and nmt_status["ready"]) else "error",
            "ready": asr_status["ready"] and nmt_status["ready"],
            "message": f"ASR: {asr_status['message']} | NMT: {nmt_status['message']}",
            "progress": (asr_status["progress"] + nmt_status["progress"]) / 2,
            "details": {"asr": asr_status, "nmt": nmt_status}
        }
        statuses.append(combined_riva)
        
        statuses.append(self.local_asr.get_status())
        statuses.append(self.llama.get_status())
        statuses.append(self.google_free.get_status())
        statuses.append(self.google_api.get_status())
        statuses.append(self.mymemory.get_status())
        return statuses


    def get_capabilities(self) -> Dict[str, Any]:
        """Returns a map of server capabilities."""
        gpu = get_gpu_info()
        return {
            "has_gpu": gpu["available"],
            "gpu_name": gpu["name"],
            "vram_gb": (gpu.get("vram_total", 0) / 1024) if gpu.get("vram_total") else 0,
            "has_google_auth": bool(self.google_api.is_ready()),
            "has_nvidia_auth": bool(self.riva_asr.is_ready()),
            "whisper_models": {
                size.split("-")[1]: self.whisper.is_downloaded(size.split("-")[1])
                for size in _WHISPER_SIZES
            }
        }
