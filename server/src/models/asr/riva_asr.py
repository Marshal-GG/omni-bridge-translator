"""
NVIDIA Riva ASR implementation.
"""

import logging
import time
import riva.client  # type: ignore[import]
from src.utils.language_support import RIVA_PARAKEET_ASR_LANGS

class RivaASRModel:
    """Wraps NVIDIA Riva ASR (Parakeet and Canary)."""

    def __init__(self, api_key: str):
        self.api_key = api_key
        self.asr_parakeet = None
        self.asr_canary = None
        self._setup()

    def _setup(self):
        try:
            if not self.api_key:
                return
            
            # Parakeet Multilingual
            auth_parakeet = riva.client.Auth(
                None,
                use_ssl=True,
                uri="grpc.nvcf.nvidia.com:443",
                metadata_args=[
                    ["authorization", f"Bearer {self.api_key}"],
                    ["function-id", "71203149-d3b7-4460-8231-1be2543a1fca"],
                ],
            )
            self.asr_parakeet = riva.client.ASRService(auth_parakeet)

            # Canary
            auth_canary = riva.client.Auth(
                None,
                use_ssl=True,
                uri="grpc.nvcf.nvidia.com:443",
                metadata_args=[
                    ["authorization", f"Bearer {self.api_key}"],
                    ["function-id", "b0e8b4a5-217c-40b7-9b96-17d84e666317"],
                ],
            )
            self.asr_canary = riva.client.ASRService(auth_canary)
        except Exception as e:
            logging.error(f"Riva ASR setup failed: {e}")

    def reload(self, api_key: str):
        self.api_key = api_key
        self._setup()

    def is_ready(self) -> bool:
        return getattr(self, "asr_parakeet", None) is not None and bool(self.api_key)

    def transcribe(self, audio_bytes: bytes, config) -> tuple[str | None, dict | None]:
        """Run offline ASR and return the transcript, or None if empty."""
        start = time.monotonic()
        
        lang = config.language_code
        if lang in RIVA_PARAKEET_ASR_LANGS:
            service = getattr(self, "asr_parakeet", None)
            model_name = "riva-parakeet"
        else:
            service = getattr(self, "asr_canary", None)
            model_name = "riva-canary"

        if not service:
            return None, None

        try:
            response = service.offline_recognize(audio_bytes, config)
        except Exception as e:
            logging.warning(f"[RivaASR] offline_recognize failed ({model_name}, lang={lang}): {type(e).__name__}: {e}")
            return None, None

        transcript = None
        detected_lang = None
        if response and response.results:
            result = response.results[0]
            if result.alternatives:
                alt = result.alternatives[0]
                raw_transcript = alt.transcript.strip()
                detected_lang = getattr(result, "language_code", None)

                if len(raw_transcript) <= 1:
                    return None, None

                confidence = getattr(alt, "confidence", None)
                if confidence is not None and confidence < 0.5:
                    logging.debug(f"[RivaASR] Low confidence ({confidence:.2f}) filtered: {raw_transcript!r}")
                    return None, None

                transcript = raw_transcript
                
        stats = None
        if transcript:
            safe_lang = ""
            if detected_lang:
                safe_lang = str(detected_lang).split("-")[0].lower()

            stats = {
                "engine": "riva-asr",
                "model": model_name,
                "latency_ms": int((time.monotonic() - start) * 1000),
                "input_tokens": len(transcript),
                "output_tokens": 0,
                "detected_lang": safe_lang
            }
        return transcript, stats

    def make_config(self, sample_rate: int, lang: str):
        return riva.client.RecognitionConfig(
            encoding=riva.client.AudioEncoding.LINEAR_PCM,
            sample_rate_hertz=sample_rate,
            language_code=lang,
            max_alternatives=1,
            enable_automatic_punctuation=True,
            audio_channel_count=1,
        )
