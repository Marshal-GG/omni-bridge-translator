import logging
import time
from typing import Any, Dict, Optional, Tuple

from src.models.translation import (
    RivaNMTModel,
    LlamaModel,
    GoogleModel,
    MyMemoryModel,
    GoogleCloudTranslationModel
)

class TranslationDispatcher:
    """
    Handles translation logic, language detection, and fallbacks.
    """
    def __init__(
        self,
        riva_nmt: RivaNMTModel,
        llama: LlamaModel,
        google_free: GoogleModel,
        mymemory: MyMemoryModel,
        google_api: Optional[GoogleCloudTranslationModel] = None
    ):
        self.riva_nmt = riva_nmt
        self.llama = llama
        self.google_free = google_free
        self.mymemory = mymemory
        self.google_api = google_api

        self.source_lang = "auto"
        self.target_lang = None
        self.translation_model = "google"

    def translate(self, text: str, source_hint: Optional[str] = None) -> Tuple[Optional[str], Optional[Dict]]:
        """Routes translation to the correct engine with built-in fallbacks."""
        if not self.target_lang or self.target_lang == "none":
            return text, None

        source = self.source_lang
        target = self.target_lang
        model = self.translation_model

        # 1. Language Detection Hint
        if (self.source_lang == "auto") and source_hint and source_hint != "multi":
            actual_hint = source_hint.split("-")[0] if "-" in source_hint else source_hint
            if actual_hint != source:
                source = actual_hint
        
        # 2. Script-based check (fallback if hint fails or is missing)
        if (self.source_lang == "auto") and not source_hint:
            script_lang = self._detect_lang_from_script(text)
            if script_lang and script_lang != source:
                source = script_lang

        # 3. Dispatching
        try:
            if model == "google_api":
                if self.google_api:
                    res, stats = self.google_api.translate(text, source, target)
                    if res: return res, stats
                return self._google_fallback(text, source, target, "google_api")

            if model == "mymemory":
                res, stats = self.mymemory.translate(text, source, target)
                if res: return res, stats
                return self._google_fallback(text, source, target, "mymemory")

            if model == "llama":
                return self.llama.translate(text, target)

            if model == "riva":
                if source != "auto" and not self.riva_nmt.supports_translation_pair(source, target):
                    logging.info(f"[Translation] Skipping Riva for {source}->{target}; using Llama fallback.")
                    return self._llama_fallback(text, "riva")
                try: 
                    return self.riva_nmt.translate(text, source, target)
                except Exception as e:
                    logging.warning(f"[Translation] Riva failed ({e}), falling back to Llama.")
                    return self._llama_fallback(text, "riva")

            # Default: Google Free
            res, stats = self.google_free.translate(text, source, target)
            if res: return res, stats
            
            # Final fallback to Llama
            return self._llama_fallback(text, "google")
            
        except Exception as e:
            logging.error(f"[TranslationDispatcher] Global translation error: {e}")
            return None, None

    def _google_fallback(self, text, source, target, original_engine) -> Tuple[str, Dict]:
        res, stats = self.google_free.translate(text, source, target)
        if stats:
            stats["fallback_from"] = original_engine
        return res or text, stats

    def _llama_fallback(self, text: str, original_engine: str) -> Tuple[Optional[str], Optional[Dict]]:
        try:
            res, stats = self.llama.translate(text, self.target_lang)
            if stats:
                stats["fallback_from"] = original_engine
            return res, stats
        except Exception as e:
            logging.warning(f"[Translation] Llama fallback failed: {e}")
            return None, None

    def _detect_lang_from_script(self, text: str) -> Optional[str]:
        """Heuristic to detect language based on Unicode script ranges."""
        counts = {"hi": 0, "bn": 0, "ta": 0}
        total_scripts = 0
        for char in text:
            cp = ord(char)
            if 0x0900 <= cp <= 0x097F: counts["hi"] += 1; total_scripts += 1
            elif 0x0980 <= cp <= 0x09FF: counts["bn"] += 1; total_scripts += 1
            elif 0x0B80 <= cp <= 0x0BFF: counts["ta"] += 1; total_scripts += 1
        
        if total_scripts == 0: return None
        # Fix max() to find the key with the highest value
        best_lang = max(counts.items(), key=lambda x: x[1])[0]
        return best_lang if counts[best_lang] > 0 else None

