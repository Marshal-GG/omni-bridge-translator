"""
Google Translate model via deep-translator.
Used when 'google' engine is selected.
"""

from deep_translator import GoogleTranslator


class GoogleModel:
    """Wraps deep-translator's GoogleTranslator."""

    def is_ready(self) -> bool:
        return True  # Always available — no API key needed

    def translate(self, text: str, source_lang: str, target_lang: str) -> str | None:
        """
        Translate *text* from *source_lang* to *target_lang*.
        Returns the translated string, or None on failure.
        """
        try:
            src = source_lang if source_lang != "auto" else "auto"
            result = GoogleTranslator(source=src, target=target_lang).translate(text)
            return result if result else None
        except Exception as e:
            print(f"Google Translate error: {e}")
            return None
