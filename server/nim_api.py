"""
nim_api.py — Central orchestrator for AI translation engines.

Imports each engine from the `models/` package and routes
ASR + translation work to the one the user selected.

Engines:
  - 'riva'   → NVIDIA Riva ASR + Riva/Llama NIM translation  (models/riva_model.py)
  - 'llama'  → Llama 3.1 8B via NVIDIA NIM                   (models/llama_model.py)
  - 'google' → Google Translate via deep-translator           (models/google_model.py)
"""

import threading
import queue

from models.riva_model import RivaModel
from models.llama_model import LlamaModel
from models.google_model import GoogleModel


class NimApiClient:
    """
    Orchestrates speech recognition and translation across multiple AI engines.
    The active engine is set per-session via `start_stream(ai_engine=...)`.
    """

    def __init__(self, api_key: str):
        self.api_key = api_key
        self.is_running = False
        self.audio_queue: queue.Queue = queue.Queue()

        # Instantiate all engines upfront
        self.riva = RivaModel(api_key)
        self.llama = LlamaModel(api_key)
        self.google = GoogleModel()

        # Active session state
        self._ai_engine = "riva"
        self._source_lang = "auto"
        self._target_lang = None
        self._sample_rate = 16000
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
        ai_engine: str = "riva",
        callback=None,
    ):
        if not self.riva.is_ready() and ai_engine != "google":
            if callback:
                callback("Error: API Key or Riva setup is missing.", True, is_final=True)
            return

        if self.is_running:
            return

        self.is_running = True
        self._source_lang = source_lang
        self._target_lang = target_lang
        self._ai_engine = ai_engine
        self._callback = callback
        self._sample_rate = sample_rate

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
        # Language code map for Riva ASR
        lang_map = {
            "en": "en-US", "es": "es-US", "fr": "fr-FR", "de": "de-DE",
            "zh": "zh-CN", "ja": "ja-JP", "ko": "ko-KR", "ru": "ru-RU",
            "pt": "pt-BR", "it": "it-IT", "ar": "ar-AR", "hi": "hi-IN",
            "nl": "nl-NL", "tr": "tr-TR", "vi": "vi-VN", "pl": "pl-PL",
            "id": "id-ID", "th": "th-TH", "bn": "bn-IN",
        }

        use_auto = self._source_lang == "auto"
        asr_lang = "multi" if use_auto else lang_map.get(self._source_lang, "en-US")
        fell_back = False

        config = self.riva.make_asr_config(self._sample_rate, asr_lang)

        while self.is_running:
            try:
                chunk = self.audio_queue.get(timeout=1.0)
                if chunk is None:
                    break

                # ── ASR (always via Riva) ────────────────────────────────
                try:
                    transcript = self.riva.transcribe(chunk.tobytes(), config)
                except Exception as asr_err:
                    err_str = str(asr_err)
                    try:
                        with open("asr_error.log", "a") as f:
                            f.write(f"[ASR ERROR] lang={asr_lang} err={err_str}\n")
                    except Exception:
                        pass

                    if use_auto and not fell_back:
                        print(f"[ASR] Auto mode failed ({err_str[:120]}), falling back to en-US")
                        asr_lang = "en-US"
                        config = self.riva.make_asr_config(self._sample_rate, asr_lang)
                        fell_back = True
                        if self._callback:
                            self._callback("__source_lang_override__:en", False, is_final=False)
                        try:
                            transcript = self.riva.transcribe(chunk.tobytes(), config)
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
                    translated, usage_stats = self._translate(clean, self._source_lang, self._target_lang)
                    if self._callback:
                        self._callback(translated, False, is_final=True, original_text=clean, usage_stats=usage_stats)
                else:
                    if self._callback:
                        self._callback(clean, False, is_final=True)

            except queue.Empty:
                continue
            except Exception as e:
                if self._callback:
                    self._callback(f"ASR Error: {e}", True, is_final=True)

    # ── Translation dispatcher ────────────────────────────────────────────────

    def _translate(self, text: str, source_lang: str, target_lang: str) -> tuple[str, dict]:
        """Route translation to the active engine, with Llama as final fallback.
        Returns (translated_text, usage_stats).
        """

        # Google engine
        if self._ai_engine == "google":
            result, stats = self.google.translate(text, source_lang, target_lang)
            if result:
                return result, stats
            print("Google Translate failed, falling back to Llama...")
            result, stats = self.llama.translate(text, target_lang)
            stats["fallback_from"] = "google"
            return result, stats

        # Llama engine (direct)
        if self._ai_engine == "llama":
            return self.llama.translate(text, target_lang)

        # Riva engine (default) — falls back to Llama internally for unsupported langs
        try:
            return self.riva.translate(text, source_lang, target_lang)
        except Exception as e:
            print(f"Riva translation error ({e}), falling back to Llama...")
            result, stats = self.llama.translate(text, target_lang)
            stats["fallback_from"] = "riva"
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
