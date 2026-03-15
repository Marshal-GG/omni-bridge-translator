# Copyright (c) 2026 Omni Bridge. All rights reserved.
# 
# Licensed under the PERSONAL STUDY & LEARNING LICENSE v1.0.
# Commercial use and public redistribution of modified versions are strictly prohibited.
# See the LICENSE file in the project root for full license terms.

"""
orchestrator.py — Central orchestrator for AI transcription and translation.

This module coordinates:
  1. Transcription (ASR): Riva, Whisper (local), or Google (online).
  2. Translation: Google, MyMemory, Riva, or Llama.
"""

import queue
import os
import threading
import logging
import time
import structlog
import pysbd
from typing import Any, Callable, Dict, List, Optional, Tuple

from src.models.riva_model import RivaModel
from src.models.llama_model import LlamaModel
from src.models.google_model import GoogleModel
from src.models.google_cloud_model import GoogleCloudModel
from src.models.mymemory_model import MyMemoryModel
from src.models.speech_recognition_model import SpeechRecognitionModel
from src.models.whisper_model import WhisperModel, get_gpu_info

# Valid transcription model IDs
_WHISPER_SIZES = {"whisper-tiny", "whisper-base", "whisper-small", "whisper-medium"}

# BCP-47 language codes mapping
_LANG_MAP = {
    "en": "en-US", "es": "es-US", "fr": "fr-FR", "de": "de-DE",
    "zh": "zh-CN", "ja": "ja-JP", "ko": "ko-KR", "ru": "ru-RU",
    "pt": "pt-BR", "it": "it-IT", "ar": "ar-AR", "hi": "hi-IN",
    "nl": "nl-NL", "tr": "tr-TR", "vi": "vi-VN", "pl": "pl-PL",
    "id": "id-ID", "th": "th-TH", "bn": "bn-IN",
}

class RateLimiter:
    """Manages NVIDIA NIM RPM limits (default 40)."""
    def __init__(self, rpm: int = 40):
        self.rpm = rpm
        self.history = []
        self.lock = threading.Lock()

    def wait_if_needed(self):
        with self.lock:
            now = time.monotonic()
            # Cleanup old history
            self.history = [t for t in self.history if now - t < 60]
            if len(self.history) >= self.rpm:
                # Wait for the oldest to expire
                sleep_time = 60 - (now - self.history[0])
                if sleep_time > 0:
                    time.sleep(sleep_time)
            self.history.append(time.monotonic())

class InferenceOrchestrator:
    """
    Orchestrates speech recognition and translation across multiple AI engines.
    Handles thread management, resource lifecycle, and error fallbacks.
    """

    riva: RivaModel
    llama: LlamaModel
    google: GoogleModel
    google_api: GoogleCloudModel
    mymemory: MyMemoryModel
    speech_recognition: SpeechRecognitionModel
    whisper: WhisperModel

    def __init__(self, nvidia_api_key: str = "", google_json_path: str = ""):
        self.nvidia_api_key = nvidia_api_key
        self.google_json_path = google_json_path
        
        self.logger = structlog.get_logger()
        self.rate_limiter = RateLimiter(rpm=40)
        self.seg = pysbd.Segmenter(language="en", clean=False)

        self.is_running = False
        self.audio_queue: queue.Queue = queue.Queue()
        self._translation_queue: queue.Queue = queue.Queue()
        
        self._whisper_suspended = False
        self._is_first_chunk = True

        # Initialize Models
        self._init_models()

        # Session state
        self._transcription_model: str = "online"
        self._translation_model: str = "google"
        self._source_lang: str = "auto"
        self._target_lang: Optional[str] = None
        self._sample_rate: int = 16000
        self._callback: Optional[Callable] = None

    def _init_models(self):
        """Pre-instantiate model wrappers."""
        self.riva = RivaModel(self.nvidia_api_key)
        self.llama = LlamaModel(self.nvidia_api_key)
        self.google = GoogleModel()
        self.google_api = GoogleCloudModel(self.google_json_path)
        self.mymemory = MyMemoryModel()
        self.speech_recognition = SpeechRecognitionModel()
        self.whisper = WhisperModel("base")

    # ── Configuration ────────────────────────────────────────────────────────

    def set_api_keys(self, nvidia_key: str, google_json_path: str):
        """Update API keys across all relevant engines."""
        self.nvidia_api_key = nvidia_key
        
        if not google_json_path:
            # Point to server/json/ (we are in server/src/network/orchestrator.py)
            json_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "json")
                
            if os.path.exists(json_dir):
                files = [f for f in os.listdir(json_dir) if f.endswith(".json")]
                if files:
                    google_json_path = os.path.join(json_dir, files[0])
                    logging.info(f"[Orchestrator] Auto-detected Google JSON: {google_json_path}")

        self.google_json_path = google_json_path
        self.riva.reload(nvidia_key)
        self.llama.reload(nvidia_key)
        self.google_api.reload(google_json_path)

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
        """Initialize and start background worker threads for ASR and Translation."""
        if self.is_running:
            return

        # Legacy Engine Mapping
        if not translation_model:
            translation_model = {
                "google": "google",
                "llama":  "llama",
                "riva":   "riva",
            }.get(ai_engine, "google")

        self._transcription_model = transcription_model.lower().strip()
        self._translation_model = translation_model.lower().strip()
        self._source_lang = source_lang
        self._target_lang = target_lang
        self._sample_rate = sample_rate
        self._callback = callback
        self._whisper_suspended = suspended
        self._is_first_chunk = True

        if not self._validate_preflight():
            return

        self.is_running = True
        self.audio_clear()

        # Start Workers
        threading.Thread(target=self._asr_worker, name="ASRWorker", daemon=True).start()
        threading.Thread(target=self._translation_worker, name="TranslationWorker", daemon=True).start()

        logging.info(f"[Orchestrator] Stream started: Trans={self._transcription_model}, Translat={self._translation_model}")

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
        # Riva ASR Check
        if self._transcription_model == "riva" and not self.riva.is_ready():
            self._emit_error("API Key missing for Riva ASR")
            return False

        # Whisper Check
        if self._transcription_model in _WHISPER_SIZES:
            whisper_size = self._transcription_model.split("-", 1)[1]
            self.whisper.model_size = whisper_size
            if not self.whisper.is_downloaded():
                self._emit_error(f"Whisper {whisper_size} model not downloaded. Open Settings to fix.")
                return False
        else:
            self.whisper.unload_model() # Save VRAM if not using whisper

        # Translation Checks
        if self._translation_model == "google_api" and not self.google_json_path:
            self._emit_error("Google Cloud JSON missing. Check Translation settings.")
            return False

        if self._translation_model in ("riva", "llama") and not self.nvidia_api_key:
            self._emit_error(f"NVIDIA API Key missing for {self._translation_model}.")
            return False

        return True

    def _emit_error(self, msg: str):
        if self._callback:
            self._callback(f"Error: {msg}", True, is_final=True)

    # ── Workers ──────────────────────────────────────────────────────────────

    def _asr_worker(self):
        """Processes audio chunks into text transcripts."""
        use_auto = self._source_lang == "auto"
        asr_lang = "multi" if use_auto else _LANG_MAP.get(self._source_lang, "en-US")
        fell_back = False
        
        config = self.riva.make_asr_config(self._sample_rate, asr_lang) if self._transcription_model == "riva" else None

        while self.is_running:
            try:
                chunk = self.audio_queue.get(timeout=1.0)
                if chunk is None: break

                start_time = time.monotonic()
                transcript, asr_stats = self._perform_asr(chunk, config, asr_lang)

                # Fallback for Riva Auto mode
                if not transcript and self._transcription_model == "riva" and use_auto and not fell_back:
                    asr_lang = "en-US"
                    config = self.riva.make_asr_config(self._sample_rate, asr_lang)
                    fell_back = True
                    if self._callback: self._callback("__source_lang_override__:en", False, is_final=False)
                    transcript, asr_stats = self.riva.transcribe(chunk.tobytes(), config)

                if transcript:
                    # Rate limiting for Riva/Llama
                    if self._transcription_model == "riva":
                        self.rate_limiter.wait_if_needed()

                    latency = int((time.monotonic() - start_time) * 1000)
                    self.logger.info("asr_complete", latency_ms=latency, model=self._transcription_model, text=transcript[:50])
                    
                    self._translation_queue.put({
                        "text": self._clean_stutters(transcript),
                        "asr_stats": asr_stats,
                        "created_at": time.time()
                    })

            except Exception as e:
                logging.error(f"[ASRWorker] Error: {e}")
                self._emit_error(f"ASR Failure: {e}")

    def _perform_asr(self, chunk: Any, config: Any, asr_lang: str) -> Tuple[Optional[str], Optional[Dict]]:
        """Dispatcher for different ASR models."""
        model = self._transcription_model
        try:
            if model == "riva":
                return self.riva.transcribe(chunk.tobytes(), config)
            
            if model in _WHISPER_SIZES:
                if self._whisper_suspended:
                    return None, None
                return self.whisper.transcribe(chunk.tobytes(), self._sample_rate, self._source_lang)

            # Default: Google Online
            return self.speech_recognition.transcribe(chunk.tobytes(), self._sample_rate, self._source_lang)
        except Exception as e:
            self._log_asr_error(e, asr_lang)
            raise e

    def _translation_worker(self):
        """Processes transcripts into translations."""
        while self.is_running:
            try:
                item = self._translation_queue.get(timeout=1.0)
                if item is None: break
                
                # Coalesce: Skip stale items if queue is building up
                while not self._translation_queue.empty():
                    next_item = self._translation_queue.get_nowait()
                    if next_item is None:
                        self._translation_queue.put(None)
                        break
                    item = next_item
                
                dwell_time = int((time.time() - item["created_at"]) * 1000)
                text = item["text"]
                asr_stats = item["asr_stats"]

                if self._target_lang and self._target_lang != "none":
                    # Rate limiting for Riva/Llama translation
                    if self._translation_model in ("riva", "llama"):
                        self.rate_limiter.wait_if_needed()

                    start_time = time.monotonic()
                    translated, trans_stats = self._dispatch_translation(text)
                    latency = int((time.monotonic() - start_time) * 1000)
                    
                    if trans_stats:
                        trans_stats["queue_dwell_ms"] = dwell_time

                    logging.info(f"[Translation] {latency}ms | Dwell: {dwell_time}ms | {self._translation_model}")
                    
                    stats = [s for s in [asr_stats, trans_stats] if s]
                    if self._callback:
                        self._callback(translated, False, is_final=True, original_text=text, usage_stats=stats)
                else:
                    if self._callback:
                        self._callback(text, False, is_final=True, original_text=text, usage_stats=[asr_stats] if asr_stats else None)

            except Exception as e:
                logging.error(f"[TranslationWorker] Error: {e}")
                self._emit_error(f"Translation Failure: {e}")

    def _dispatch_translation(self, text: str) -> Tuple[str, Dict]:
        """Routes translation to the correct engine with built-in fallbacks."""
        source, target = self._source_lang, self._target_lang
        model = self._translation_model

        if model == "mymemory":
            res, stats = self.mymemory.translate(text, source, target)
            if res: return res, stats
            return self._google_fallback(text, source, target, "mymemory")

        if model == "llama":
            return self.llama.translate(text, target)

        if model == "riva":
            try: return self.riva.translate(text, source, target)
            except Exception:
                res, stats = self.llama.translate(text, target)
                stats["fallback_from"] = "riva"
                return res, stats

        if model == "google_api":
            res, stats = self.google_api.translate(text, source, target)
            if res: return res, stats
            return self._google_fallback(text, source, target, "google_api")

        # Default: Google Free
        res, stats = self.google.translate(text, source, target)
        if res: return res, stats
        res, stats = self.llama.translate(text, target)
        stats["fallback_from"] = "google"
        return res, stats

    def _google_fallback(self, text, source, target, original_engine) -> Tuple[str, Dict]:
        res, stats = self.google.translate(text, source, target)
        stats["fallback_from"] = original_engine
        return res or text, stats

    # ── Status & Utilities ───────────────────────────────────────────────────

    def whisper_unload(self):
        """Unload Whisper model from memory."""
        self.whisper.unload_model()

    def get_all_statuses(self) -> List[Dict]:
        """Collect statuses from all internal models for UI display."""
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
            
        # Others
        statuses.append(self.riva.get_status())
        statuses.append(self.speech_recognition.get_status())
        statuses.append(self.llama.get_status())
        statuses.append(self.google.get_status())
        statuses.append(self.google_api.get_status())
        statuses.append(self.mymemory.get_status())
        return statuses

    def get_capabilities(self) -> Dict[str, Any]:
        """Returns a map of what the server is capable of based on current hardware/auth."""
        gpu = get_gpu_info()
        return {
            "has_gpu": gpu["available"],
            "gpu_name": gpu["name"],
            "vram_gb": (gpu.get("vram_total", 0) / 1024) if gpu.get("vram_total") else 0,
            "has_google_auth": bool(self.google_api.is_ready()),
            "has_nvidia_auth": bool(self.riva.is_ready()),
            "whisper_models": {
                size.split("-")[1]: self.whisper.is_downloaded(size.split("-")[1])
                for size in _WHISPER_SIZES
            }
        }

    def _log_asr_error(self, err: Exception, lang: str):
        try:
            log_dir = "logs"
            os.makedirs(log_dir, exist_ok=True)
            with open(os.path.join(log_dir, "asr_error.log"), "a") as f:
                ts = time.strftime("%Y-%m-%d %H:%M:%S")
                f.write(f"[{ts}] [ASR ERROR] model={self._transcription_model} lang={lang} err={err}\n")
        except: pass

    def _clean_stutters(self, text: str) -> str:
        """Removes word-level or sentence-level repetitions using pysbd."""
        if not text: return ""
        
        # Segment and deduplicate sentences
        sentences = self.seg.segment(text)
        deduped_sentences = []
        for s in sentences:
            if not deduped_sentences or s != deduped_sentences[-1]:
                deduped_sentences.append(s)
        
        text = " ".join(deduped_sentences)
        
        # Simple word deduplication (triples)
        words = text.split()
        cleaned = []
        for w in words:
            if len(cleaned) >= 2 and cleaned[-1] == w and cleaned[-2] == w:
                continue
            cleaned.append(w)
        return " ".join(cleaned)
