"""
MyMemory free translation model.
Uses the MyMemory public REST API — no key needed, supports 70+ languages.
Free tier: ~1000 words/day per IP. Pass an email for 10x higher quota.
"""

import time
import urllib.parse
import urllib.request
import json


class MyMemoryModel:
    """Wraps the MyMemory free translation API."""

    BASE_URL = "https://api.mymemory.translated.net/get"

    def __init__(self, email: str = ""):
        # Optional: provide an email for higher daily quota
        self._email = email

    def is_ready(self) -> bool:
        return True

    def translate(self, text: str, source_lang: str, target_lang: str) -> tuple[str | None, dict]:
        start = time.monotonic()
        try:
            src = "en" if source_lang == "auto" else source_lang
            lang_pair = f"{src}|{target_lang}"
            params = {"q": text, "langpair": lang_pair}
            if self._email:
                params["de"] = self._email

            url = f"{self.BASE_URL}?{urllib.parse.urlencode(params)}"
            with urllib.request.urlopen(url, timeout=8) as resp:
                data = json.loads(resp.read().decode())

            match = data.get("responseData", {})
            result = match.get("translatedText") or None

            latency_ms = int((time.monotonic() - start) * 1000)
            return result, {
                "engine": "mymemory-translate",
                "model": "mymemory-free",
                "latency_ms": latency_ms,
                "input_tokens": len(text),
                "output_tokens": len(result) if result else 0,
            }

        except Exception as e:
            print(f"[MyMemory] Translation error: {e}")
            latency_ms = int((time.monotonic() - start) * 1000)
            return None, {
                "engine": "mymemory-translate",
                "model": "mymemory-free",
                "latency_ms": latency_ms,
                "error": str(e),
                "input_tokens": len(text),
            }
