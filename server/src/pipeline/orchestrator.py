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

    def __init__(self, nvidia_api_key: str = "", google_credentials: Any = "", 
                 riva_translation_id: str = "", riva_asr_parakeet_id: str = "", riva_asr_canary_id: str = ""):
        self.nvidia_api_key = nvidia_api_key
        self.google_credentials = google_credentials
        self.riva_translation_id = riva_translation_id
        self.riva_asr_parakeet_id = riva_asr_parakeet_id
        self.riva_asr_canary_id = riva_asr_canary_id
        
        # Explicitly define models for linter and clarity
        self.riva_asr: Optional[RivaASRModel] = None
        self.riva_nmt: Optional[RivaNMTModel] = None
        self.whisper: Optional[WhisperModel] = None
        self.llama: Optional[LlamaModel] = None
        self.google_free: Optional[GoogleModel] = None
        self.google_api: Optional[GoogleCloudTranslationModel] = None
        self.mymemory: Optional[MyMemoryModel] = None
        self.local_asr: Optional[SpeechRecognitionModel] = None

        self.logger = structlog.get_logger()

        self.is_running = False
        self.audio_queue: queue.Queue = queue.Queue()
        self._translation_queue: queue.Queue = queue.Queue()
        self._reloader_lock = threading.Lock()
        
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
        self.riva_asr = RivaASRModel(self.nvidia_api_key, parakeet_fid=self.riva_asr_parakeet_id, canary_fid=self.riva_asr_canary_id)
        self.riva_nmt = RivaNMTModel(self.nvidia_api_key, function_id=self.riva_translation_id)
        self.llama = LlamaModel(self.nvidia_api_key)
        self.google_free = GoogleModel()
        self.google_api = GoogleCloudTranslationModel(self.google_credentials)
        self.mymemory = MyMemoryModel()
        self.local_asr = SpeechRecognitionModel()
        self.whisper = WhisperModel("base")

    # ── Configuration ────────────────────────────────────────────────────────

    def set_api_keys(self, nvidia_key: str, google_credentials: Any, 
                     riva_translation_id: str = "", riva_asr_parakeet_id: str = "", riva_asr_canary_id: str = ""):
        """Update API keys across all relevant engines."""
        self.nvidia_api_key = nvidia_key
        if google_credentials is not None:
            self.google_credentials = google_credentials
        self.riva_translation_id = riva_translation_id or self.riva_translation_id
        self.riva_asr_parakeet_id = riva_asr_parakeet_id or self.riva_asr_parakeet_id

        logging.info("[Orchestrator] Starting background model reload...")

        def _do_reload():
            with self._reloader_lock:
                try:
                    if self.riva_asr:
                        self.riva_asr.reload(nvidia_key, parakeet_fid=self.riva_asr_parakeet_id, canary_fid=self.riva_asr_canary_id)
                    if self.riva_nmt:
                        self.riva_nmt.reload(nvidia_key, function_id=self.riva_translation_id)
                    if self.llama:
                        self.llama.reload(nvidia_key)
                    if self.google_api:
                        self.google_api.reload(self.google_credentials)
                    logging.info("[Orchestrator] Background model reload complete.")
                except Exception as e:
                    logging.error(f"Error updating model API keys: {e}")

        threading.Thread(target=_do_reload, daemon=True).start()

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
        
        # Unload Whisper to free up VRAM when not in use
        if self.whisper:
            self.whisper.unload_model()

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
        # Ensure any pending model reloads are complete before validating
        with self._reloader_lock:
            asr_id = self.asr_dispatcher.transcription_model.lower().strip()
            trans_id = self.translation_dispatcher.translation_model.lower().strip()
            
            # 1. Riva ASR Check
            if asr_id == "riva":
                if self.riva_asr and self.riva_asr._is_loading:
                    self._emit_error("Riva ASR is still initializing. Please wait.")
                    return False
                if not self.riva_asr or not self.riva_asr.is_ready():
                    self._emit_error("Riva ASR is not ready. Check NVIDIA API key.")
                    return False

            # 2. Whisper Check
            elif asr_id in _WHISPER_SIZES:
                whisper_size = asr_id.split("-", 1)[1]
                if self.whisper:
                    self.whisper.model_size = whisper_size
                    if not self.whisper.is_downloaded():
                        self._emit_error(f"Whisper {whisper_size} model not downloaded. Open Settings to fix.")
                        return False
            elif self.whisper:
                self.whisper.unload_model()

            # 3. Translation Checks
            if trans_id == "riva":
                if self.riva_nmt and self.riva_nmt._is_loading:
                    self._emit_error("Riva NMT is still initializing. Please wait.")
                    return False
                if not self.riva_nmt or not self.riva_nmt.is_ready():
                    logging.warning("[Orchestrator] Riva NMT not ready; using fallback.")
                    # Allow stream to start; TranslationDispatcher will use fallback

            elif trans_id == "llama":
                if self.llama and self.llama._is_loading:
                    self._emit_error("Llama is still initializing. Please wait.")
                    return False
                if not self.llama or not self.llama.is_ready():
                    logging.warning("[Orchestrator] Llama not ready; using fallback if possible.")
                    # Allow stream to start; TranslationDispatcher will try next fallback

            elif trans_id == "google_api":
                if self.google_api and self.google_api._is_loading:
                    self._emit_error("Google Cloud Translation is still initializing. Please wait.")
                    return False
                if not self.google_api or not self.google_api.is_ready():
                    logging.warning("[Orchestrator] Google Cloud Translation not ready; using fallback.")
                    # Allow stream to start; TranslationDispatcher will use fallback

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
            
        # Separate Riva ASR and NMT status
        asr_status = self.riva_asr.get_status() if self.riva_asr else {"name": "riva-asr", "status": "error", "ready": False}
        nmt_status = self.riva_nmt.get_status() if self.riva_nmt else {"name": "riva-nmt", "status": "error", "ready": False}
        
        statuses.append(asr_status)
        statuses.append(nmt_status)
        
        if self.local_asr: statuses.append(self.local_asr.get_status())
        if self.llama: statuses.append(self.llama.get_status())
        if self.google_free: statuses.append(self.google_free.get_status())
        if self.google_api: statuses.append(self.google_api.get_status())
        if self.mymemory: statuses.append(self.mymemory.get_status())
        return statuses


    def get_capabilities(self) -> Dict[str, Any]:
        """Returns a map of server capabilities."""
        gpu = get_gpu_info()
        return {
            "has_gpu": gpu["available"],
            "gpu_name": gpu["name"],
            "vram_gb": (gpu.get("vram_total", 0) / 1024) if gpu.get("vram_total") else 0,
            "has_google_auth": bool(self.google_api and self.google_api.is_ready()),
            "has_nvidia_auth": bool(self.riva_asr and self.riva_asr.is_ready()),
            "whisper_models": {
                size.split("-")[1]: self.whisper.is_downloaded(size.split("-")[1]) if self.whisper else False
                for size in _WHISPER_SIZES
            }
        }
