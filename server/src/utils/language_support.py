"""
language_support.py — Single source of truth for model language support.

Update this file when adding new models or languages.
All other modules should import from here rather than defining their own sets.
"""

# ── ASR lang code map (app code → BCP-47 for Riva) ────────────────────────────
# Used by InferenceOrchestrator to build Riva ASR configs.
LANG_TO_BCP47: dict[str, str] = {
    "en": "en-US",
    "es": "es-US",
    "fr": "fr-FR",
    "de": "de-DE",
    "zh": "zh-CN",
    "ja": "ja-JP",
    "ko": "ko-KR",
    "ru": "ru-RU",
    "pt": "pt-BR",
    "it": "it-IT",
    "ar": "ar-AR",
    "hi": "hi-IN",
    "nl": "nl-NL",
    "tr": "tr-TR",
    "vi": "vi-VN",
    "pl": "pl-PL",
    "id": "id-ID",
    "th": "th-TH",
    "bn": "bn-IN",
    "he": "he-IL",
    "da": "da-DK",
    "cs": "cs-CZ",
    "sv": "sv-SE",
}

# ── Riva Parakeet ASR ──────────────────────────────────────────────────────────
# BCP-47 codes supported by the Parakeet multilingual model.
# Canary handles the remainder.
RIVA_PARAKEET_ASR_LANGS: set[str] = {
    "en-US", "en-GB",
    "es-US", "es-ES",
    "fr-FR", "fr-CA",
    "de-DE",
    "it-IT",
    "ar-AR",
    "ko-KR",
    "pt-BR", "pt-PT",
    "ru-RU",
    "hi-IN",
    "nl-NL",
    "da-DK", "nn-NO", "nb-NO",
    "cs-CZ",
    "pl-PL",
    "sv-SE",
    "th-TH",
    "tr-TR",
    "he-IL",
    "bn-IN",
}

# ── Riva NMT Translation ───────────────────────────────────────────────────────
# App-level language codes (not BCP-47) supported by Riva Neural Machine
# Translation. Both source AND target must be in this set.
RIVA_NMT_LANGS: set[str] = {
    "en", "de", "es", "fr", "pt", "ru", "zh", "ja", "ko", "ar",
}

# ── Google Translate (free) ────────────────────────────────────────────────────
# Supports all app languages via deep-translator. None = unrestricted.
GOOGLE_FREE_LANGS = None

# ── Google Cloud Translation API ──────────────────────────────────────────────
# Supports 130+ languages. None = unrestricted within the app language list.
GOOGLE_CLOUD_LANGS = None

# ── MyMemory ──────────────────────────────────────────────────────────────────
# Public REST API, 70+ language pairs. None = unrestricted within the app list.
MYMEMORY_LANGS = None

# ── Llama 3.1 8B (NVIDIA NIM) ─────────────────────────────────────────────────
# LLM-based translation — handles any language pair. None = unrestricted.
LLAMA_LANGS = None
