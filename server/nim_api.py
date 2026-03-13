# Copyright (c) 2026 Omni Bridge. All rights reserved.
# 
# Licensed under the PERSONAL STUDY & LEARNING LICENSE v1.0.
# Commercial use and public redistribution of modified versions are strictly prohibited.
# See the LICENSE file in the project root for full license terms.

"""
nim_api.py — Central orchestrator for AI translation engines.

Transcription (ASR) and translation are now fully decoupled:
  - transcription_model: 'online' | 'whisper-tiny' | 'whisper-base' | 'whisper-small' | 'whisper-medium'
  - translation_model:   'google' | 'mymemory' | 'riva' | 'llama'

Legacy `ai_engine` parameter is still accepted for backward compat
(determines translation engine when translation_model is absent).
"""

import queue
import os
import threading
import logging
import time

from models.riva_model import RivaModel
from models.llama_model import LlamaModel
from models.google_model import GoogleModel
from models.google_cloud_model import GoogleCloudModel
from models.mymemory_model import MyMemoryModel
from models.speech_recognition_model import SpeechRecognitionModel
from models.whisper_model import WhisperModel, get_gpu_info

# Valid transcription model IDs
_WHISPER_SIZES = {"whisper-tiny", "whisper-base", "whisper-small", "whisper-medium"}


class NimApiClient:
    """
    Orchestrates speech recognition and translation across multiple AI engines.
    Transcription and translation are now independently configurable.
    """

    def __init__(self, nvidia_api_key: str = "", google_json_path: str = ""):
        self.nvidia_api_key = nvidia_api_key
        if not google_json_path:
            # Auto-detect JSON in server/json/
            json_dir = os.path.join(os.path.dirname(__file__), "json")
            if os.path.exists(json_dir):
                files = [f for f in os.listdir(json_dir) if f.endswith(".json")]
                if files:
                    google_json_path = os.path.join(json_dir, files[0])
                    logging.info(f"[NimApiClient] Auto-detected Google JSON: {google_json_path}")

        self.google_json_path = google_json_path
        self.is_running = False
        self.audio_queue: queue.Queue = queue.Queue()
        self._translation_queue: queue.Queue = queue.Queue()
        self._whisper_suspended = False
        self._is_first_chunk = True

        # Instantiate all engines upfront
        self.riva = RivaModel(nvidia_api_key)
        self.llama = LlamaModel(nvidia_api_key)
        self.google = GoogleModel()
        self.google_api = GoogleCloudModel(google_json_path)
        self.mymemory = MyMemoryModel()
        self.speech_recognition = SpeechRecognitionModel()
        self.whisper = WhisperModel("base")   # model_size updated per session

        # Active session state (set in start_stream)
        self._transcription_model: str = "online"
        self._translation_model: str = "google"
        self._source_lang: str = "auto"
        self._target_lang: str | None = None
        self._sample_rate: int = 16000
        self._callback = None

    # ── Key management ───────────────────────────────────────────────────────

    def set_api_keys(self, nvidia_key: str, google_json_path: str):
        self.nvidia_api_key = nvidia_key
        self.google_json_path = google_json_path
        self.riva.reload(nvidia_key)
        self.llama.reload(nvidia_key)
        self.google_api.reload(google_json_path)

    # ── Stream lifecycle ─────────────────────────────────────────────────────

    def start_stream(
        self,
        sample_rate: int,
        source_lang: str = "auto",
        target_lang: str | None = None,
        ai_engine: str = "google",          # legacy compat
        transcription_model: str = "online",
        translation_model: str = "",        # empty → derive from ai_engine
        callback=None,
        suspended: bool = False,
    ):
        # Derive translation_model from legacy ai_engine if not provided
        if not translation_model:
            translation_model = {
                "google": "google",
                "llama":  "llama",
                "riva":   "riva",
            }.get(ai_engine, "google")

        logging.info(f"[NimApiClient] Starting stream: transcription={transcription_model}, translation={translation_model}, lang={source_lang}->{target_lang}, suspended={suspended}")

        # Normalise whisper-* IDs
        transcription_model = transcription_model.lower().strip()
        translation_model = translation_model.lower().strip()

        # Guards
        use_riva_asr = transcription_model == "riva"
        use_whisper  = transcription_model in _WHISPER_SIZES

        if use_riva_asr and not self.riva.is_ready():
            if callback:
                callback("Error: API Key is missing for Riva ASR.", True, is_final=True)
            return

        if use_whisper:
            whisper_size = transcription_model.split("-", 1)[1]  # e.g. "base"
            self.whisper.model_size = whisper_size
            if not self.whisper.is_downloaded():
                if callback:
                    callback(
                        f"⚠ Whisper {whisper_size} model not downloaded. Open Settings → Speech Recognition to download it.",
                        True, is_final=True,
                    )
                return
            self._whisper_suspended = suspended
            self._is_first_chunk = True
        else:
            # Explicitly unload the Whisper model from memory when not in use
            self.whisper_unload()

        if translation_model == "google_api" and not self.google_json_path:
            if callback:
                callback("Error: Google Cloud Service Account JSON is missing. Open Settings -> Translation Engine.", True, is_final=True)
            return

        if translation_model in ("riva", "llama") and not self.nvidia_api_key:
            if callback:
                callback("Error: NVIDIA API Key is missing for the selected translation engine.", True, is_final=True)
            return

        if self.is_running:
            return

        self.is_running = True
        self._transcription_model = transcription_model
        self._translation_model   = translation_model
        self._source_lang  = source_lang
        self._target_lang  = target_lang
        self._sample_rate  = sample_rate
        self._callback     = callback

        # Drain stale audio
        while not self.audio_queue.empty():
            try:
                self.audio_queue.get_nowait()
            except Exception:
                break

        # Using 1 worker thread guarantees that audio chunks are processed 
        # in the exact order they were recorded, and reduces resource usage.
        t_audio = threading.Thread(target=self._worker, name="NimAudioWorker", daemon=True)
        t_audio.start()

        # Dedicated translation worker to avoid blocking ASR
        t_trans = threading.Thread(target=self._translation_worker, name="NimTranslationWorker", daemon=True)
        t_trans.start()

    def get_all_statuses(self) -> list:
        """Aggregate statuses from all available models into a flat list."""
        all_statuses = []
        
        # ASR Models
        if self.whisper:
            all_statuses.extend(self.whisper.get_all_statuses())
            
        # Add System GPU status
        gpu_info = get_gpu_info()
        all_statuses.append({
            "name": "system-gpu",
            "status": "available" if gpu_info["available"] else "unavailable",
            "ready": gpu_info["available"],
            "message": f"GPU: {gpu_info['name']}" if gpu_info["available"] else "No compatible GPU detected",
            "device_name": gpu_info["name"],
            "vram_used": gpu_info.get("vram_used", 0.0),
            "vram_total": gpu_info.get("vram_total", 0.0),
            "details": gpu_info
        })
            
        if self.riva:
            all_statuses.append(self.riva.get_status())
            
        if self.speech_recognition:
            all_statuses.append(self.speech_recognition.get_status())
            
        # Translation Models
        if self.llama:
            all_statuses.append(self.llama.get_status())
            
        if self.google:
            all_statuses.append(self.google.get_status())
            
        if self.google_api:
            all_statuses.append(self.google_api.get_status())
            
        if self.mymemory:
            all_statuses.append(self.mymemory.get_status())
            
        return all_statuses


    def whisper_unload(self):
        """Explicitly unload Whisper and mark as suspended to prevent re-load until restart."""
        self._whisper_suspended = True
        self.whisper.unload_model()

    def stop_stream(self):
        self.is_running = False
        self.audio_queue.put(None)
        self._translation_queue.put(None)

    def audio_clear(self):
        """Drain audio and translation queues."""
        while not self.audio_queue.empty():
            try: self.audio_queue.get_nowait()
            except: break
        while not self._translation_queue.empty():
            try: self._translation_queue.get_nowait()
            except: break

    def append_audio(self, audio_data):
        if self.is_running:
            self.audio_queue.put(audio_data)

    # ── Audio worker ─────────────────────────────────────────────────────────

    def _worker(self):
        lang_map = {
            "en": "en-US", "es": "es-US", "fr": "fr-FR", "de": "de-DE",
            "zh": "zh-CN", "ja": "ja-JP", "ko": "ko-KR", "ru": "ru-RU",
            "pt": "pt-BR", "it": "it-IT", "ar": "ar-AR", "hi": "hi-IN",
            "nl": "nl-NL", "tr": "tr-TR", "vi": "vi-VN", "pl": "pl-PL",
            "id": "id-ID", "th": "th-TH", "bn": "bn-IN",
        }

        use_auto    = self._source_lang == "auto"
        asr_lang    = "multi" if use_auto else lang_map.get(self._source_lang, "en-US")
        fell_back   = False
        use_riva_asr = self._transcription_model == "riva"
        use_whisper  = self._transcription_model in _WHISPER_SIZES

        config = self.riva.make_asr_config(self._sample_rate, asr_lang) if use_riva_asr else None

        while self.is_running:
            try:
                chunk = self.audio_queue.get(timeout=1.0)
                if chunk is None:
                    break

                # ── ASR ─────────────────────────────────────────────────────
                asr_start_time = time.monotonic()
                try:
                    asr_stats = None
                    if use_riva_asr:
                        transcript, asr_stats = self.riva.transcribe(chunk.tobytes(), config)
                    elif use_whisper:
                        if self._whisper_suspended:
                            if self._is_first_chunk:
                                logging.info("[NimApiClient] Whisper is suspended. Skipping transcription until Play is clicked.")
                                self._is_first_chunk = False
                            transcript, asr_stats = None, None
                        else:
                            if self._is_first_chunk:
                                logging.info(f"[NimApiClient] Loading/Starting Whisper model: {self._transcription_model}")
                                self._is_first_chunk = False
                            transcript, asr_stats = self.whisper.transcribe(
                                chunk.tobytes(), self._sample_rate,
                                source_lang=self._source_lang,
                            )
                    else:
                        # Online Google free ASR
                        transcript, asr_stats = self.speech_recognition.transcribe(
                            chunk.tobytes(),
                            self._sample_rate,
                            source_lang=self._source_lang,
                        )
                except Exception as asr_err:
                    _ = str(asr_err)
                    try:
                        log_dir = "logs"
                        if not os.path.exists(log_dir):
                            os.makedirs(log_dir)
                        with open(os.path.join(log_dir, "asr_error.log"), "a") as f:
                            f.write(f"[ASR ERROR] model={self._transcription_model} lang={asr_lang} err={asr_err}\n")
                    except Exception:
                        pass

                    if use_riva_asr and use_auto and not fell_back:
                        print(f"[ASR] Auto mode failed ({asr_err}), falling back to en-US")
                        asr_lang = "en-US"
                        self._source_lang = "en"
                        config = self.riva.make_asr_config(self._sample_rate, asr_lang)
                        fell_back = True
                        if self._callback:
                            self._callback("__source_lang_override__:en", False, is_final=False)
                        try:
                            transcript, asr_stats = self.riva.transcribe(chunk.tobytes(), config)
                        except Exception as retry_err:
                            if self._callback:
                                self._callback(f"ASR Error: {retry_err}", True, is_final=True)
                            continue
                    else:
                        if self._callback:
                            self._callback(f"ASR Error: {asr_err}", True, is_final=True)
                        continue

                if not transcript:
                    continue

                asr_total_time = int((time.monotonic() - asr_start_time) * 1000)
                logging.info(f"[ASR] Latency: {asr_total_time}ms | Engine: {self._transcription_model} | Text: {transcript[:50]}...")

                clean = self._clean_stutters(transcript)
                
                # Offload translation to the dedicated worker
                # Offload translation to the dedicated worker with a creation timestamp
                self._translation_queue.put({
                    "text": clean,
                    "asr_stats": asr_stats,
                    "created_at": time.time()
                })

            except queue.Empty:
                continue
            except Exception as e:
                if self._callback:
                    self._callback(f"ASR Error: {e}", True, is_final=True)

    def _translation_worker(self):
        """Worker thread that processes transcripts from the translation queue."""
        while self.is_running:
            try:
                item = self._translation_queue.get(timeout=1.0)
                if item is None:
                    break
                
                # Skip stale items if queue is backing up to prevent lag accumulation
                while not self._translation_queue.empty():
                    next_item = self._translation_queue.get_nowait()
                    if next_item is None:
                        # Put it back so the main loop can break on the next iteration
                        self._translation_queue.put(None)
                        break
                    # Replace current item with the newer one
                    item = next_item
                
                dwell_time = int((time.time() - item["created_at"]) * 1000)
                clean = item["text"]
                asr_stats = item["asr_stats"]

                # ── Translation ──────────────────────────────────────────
                if self._target_lang and self._target_lang != "none":
                    trans_start_time = time.monotonic()
                    translated, trans_stats = self._translate(clean, self._source_lang, self._target_lang)
                    trans_total_time = int((time.monotonic() - trans_start_time) * 1000)
                    
                    if trans_stats:
                        trans_stats["queue_dwell_ms"] = dwell_time

                    logging.info(f"[Translation] Latency: {trans_total_time}ms | Queue Dwell: {dwell_time}ms | Engine: {self._translation_model}")
                    
                    stats_list = []
                    if asr_stats:
                        stats_list.append(asr_stats)
                    if trans_stats:
                        stats_list.append(trans_stats)
                    if self._callback:
                        self._callback(translated, False, is_final=True, original_text=clean, usage_stats=stats_list if stats_list else None)
                else:
                    stats_list = [asr_stats] if asr_stats else None
                    if self._callback:
                        self._callback(clean, False, is_final=True, original_text=clean, usage_stats=stats_list)

            except queue.Empty:
                continue
            except Exception as e:
                logging.error(f"[TranslationWorker] Error: {e}")
                if self._callback:
                    self._callback(f"Translation Error: {e}", True, is_final=True)

    # ── Translation dispatcher ────────────────────────────────────────────────

    def _translate(self, text: str, source_lang: str, target_lang: str) -> tuple[str, dict]:
        """Route translation to the selected translation_model."""

        if self._translation_model == "mymemory":
            result, stats = self.mymemory.translate(text, source_lang, target_lang)
            if result:
                return result, stats
            # Fallback to Google
            result, stats = self.google.translate(text, source_lang, target_lang)
            stats["fallback_from"] = "mymemory"
            return result or text, stats

        if self._translation_model == "llama":
            return self.llama.translate(text, target_lang)

        if self._translation_model == "riva":
            try:
                return self.riva.translate(text, source_lang, target_lang)
            except Exception as e:
                print(f"Riva translation error ({e}), falling back to Llama...")
                result, stats = self.llama.translate(text, target_lang)
                stats["fallback_from"] = "riva"
                return result, stats

        if self._translation_model == "google_api":
            result, stats = self.google_api.translate(text, source_lang, target_lang)
            if result:
                return result, stats
            # Fallback to Google Free
            result, stats = self.google.translate(text, source_lang, target_lang)
            stats["fallback_from"] = "google_api"
            return result or text, stats

        # Default: Google Translate
        result, stats = self.google.translate(text, source_lang, target_lang)
        if result:
            return result, stats
        print("Google Translate failed, falling back to Llama...")
        result, stats = self.llama.translate(text, target_lang)
        stats["fallback_from"] = "google"
        return result, stats

    # ── Utilities ─────────────────────────────────────────────────────────────

    @staticmethod
    def _clean_stutters(text: str) -> str:
        """Remove words repeated 3+ times consecutively (stutter removal)."""
        words = text.split()
        cleaned = []
        for w in words:
            if len(cleaned) >= 2 and cleaned[-1] == w and cleaned[-2] == w:
                continue
            cleaned.append(w)
        return " ".join(cleaned)
