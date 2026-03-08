"""
Google Translate model via deep-translator.
Used when 'google' engine is selected.
"""

import time
from deep_translator import GoogleTranslator


class GoogleModel:
    """Wraps deep-translator's GoogleTranslator."""

    def __init__(self):
        self._translators = {}  # Cache translators by (source, target)

    def is_ready(self) -> bool:
        return True  # Always available — no API key needed

    def translate(self, text: str, source_lang: str, target_lang: str) -> tuple[str | None, dict]:
        """
        Translate *text* from *source_lang* to *target_lang*.
        Returns (translated_text_or_None, usage_stats).
        """
        start = time.monotonic()
        try:
            src = source_lang if source_lang != "auto" else "auto"
            # When source and target are the same, deep-translator rejects it.
            # Just return the original text directly.
            if src != "auto" and src == target_lang:
                return text, {
                    "engine": "google-translate",
                    "model": "google-translate",
                    "latency_ms": 0,
                    "prompt_tokens": 0,
                    "completion_tokens": 0,
                    "total_tokens": 0,
                    "input_chars": len(text),
                    "output_chars": len(text),
                    "same_lang_passthrough": True,
                }
            key = (src, target_lang)
            
            if key not in self._translators:
                self._translators[key] = GoogleTranslator(source=src, target=target_lang)
            
            result = self._translators[key].translate(text)
            latency_ms = int((time.monotonic() - start) * 1000)
            stats = {
                "engine": "google-translate",
                "model": "google-translate",
                "latency_ms": latency_ms,
                "prompt_tokens": 0,
                "completion_tokens": 0,
                "total_tokens": 0,
                "input_chars": len(text),
                "output_chars": len(result) if result else 0,
            }
            return (result if result else None), stats
        except Exception as e:
            print(f"Google Translate error: {e}")
            latency_ms = int((time.monotonic() - start) * 1000)
            return None, {
                "engine": "google-translate",
                "model": "google-translate",
                "latency_ms": latency_ms,
                "error": str(e),
                "input_chars": len(text),
            }
