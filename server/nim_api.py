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

import threading
import queue

from models.riva_model import RivaModel
from models.llama_model import LlamaModel
from models.google_model import GoogleModel
from models.mymemory_model import MyMemoryModel
from models.speech_recognition_model import SpeechRecognitionModel
from models.whisper_model import WhisperModel

# Valid transcription model IDs
_WHISPER_SIZES = {"whisper-tiny", "whisper-base", "whisper-small", "whisper-medium"}


class NimApiClient:
    """
    Orchestrates speech recognition and translation across multiple AI engines.
    Transcription and translation are now independently configurable.
    """

    def __init__(self, api_key: str):
        self.api_key = api_key
        self.is_running = False
        self.audio_queue: queue.Queue = queue.Queue()

        # Instantiate all engines upfront
        self.riva = RivaModel(api_key)
        self.llama = LlamaModel(api_key)
        self.google = GoogleModel()
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

    def set_api_key(self, api_key: str):
        self.api_key = api_key
        self.riva.reload(api_key)
        self.llama.reload(api_key)

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
    ):
        # Derive translation_model from legacy ai_engine if not provided
        if not translation_model:
            translation_model = {
                "google": "google",
                "llama":  "llama",
                "riva":   "riva",
            }.get(ai_engine, "google")

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
        else:
            # Explicitly unload the Whisper model from memory when not in use
            self.whisper.unload_model()

        if translation_model in ("riva", "llama") and not self.riva.is_ready():
            if callback:
                callback("Error: API Key is missing for the selected translation engine.", True, is_final=True)
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

        for _ in range(2):
            t = threading.Thread(target=self._worker, daemon=True)
            t.start()

    def stop_stream(self):
        self.is_running = False
        self.audio_queue.put(None)
        self.audio_queue.put(None)

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
                try:
                    asr_stats = None
                    if use_riva_asr:
                        transcript, asr_stats = self.riva.transcribe(chunk.tobytes(), config)
                    elif use_whisper:
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
                    err_str = str(asr_err)
                    try:
                        log_dir = "logs"
                        if not os.path.exists(log_dir):
                            os.makedirs(log_dir)
                        with open(os.path.join(log_dir, "asr_error.log"), "a") as f:
                            f.write(f"[ASR ERROR] model={self._transcription_model} lang={asr_lang} err={err_str}\n")
                    except Exception:
                        pass

                    if use_riva_asr and use_auto and not fell_back:
                        print(f"[ASR] Auto mode failed ({err_str[:120]}), falling back to en-US")
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
                            self._callback(f"ASR Error: {err_str[:200]}", True, is_final=True)
                        continue

                if not transcript:
                    continue

                clean = self._clean_stutters(transcript)

                # ── Translation ──────────────────────────────────────────
                if self._target_lang and self._target_lang != "none":
                    translated, trans_stats = self._translate(clean, self._source_lang, self._target_lang)
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
                if self._callback:
                    self._callback(f"ASR Error: {e}", True, is_final=True)

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
