"""
NVIDIA Riva ASR implementation.
"""

import logging
import time
import riva.client  # type: ignore[import]
from src.utils.language_support import RIVA_PARAKEET_ASR_LANGS

class RivaASRModel:
    """Wraps NVIDIA Riva ASR (Parakeet and Canary)."""

    def __init__(self, api_key: str, parakeet_fid: str = "", canary_fid: str = ""):
        self.api_key = api_key.strip() if api_key else ""
        self.parakeet_fid = parakeet_fid.strip() if parakeet_fid else ""
        self.canary_fid = canary_fid.strip() if canary_fid else ""
        self.asr_parakeet = None
        self.asr_canary = None
        self._is_loading = False
        self._setup()

    def _setup(self):
        self._is_loading = True
        try:
            if not self.api_key:
                logging.warning("[RivaASR] No API key provided, skipping setup.")
                return
            
            # Redact API key for logs
            redacted_key = f"{self.api_key[:6]}...{self.api_key[-4:]}" if len(self.api_key) > 10 else "***"
            logging.info(f"[RivaASR] Setting up with IDs: Parakeet='{self.parakeet_fid}', Canary='{self.canary_fid}' (Key: {redacted_key})")
            
            # Parakeet Multilingual
            auth_parakeet = riva.client.Auth(
                None,
                use_ssl=True,
                uri="grpc.nvcf.nvidia.com:443",
                metadata_args=[
                    ["authorization", f"Bearer {self.api_key}"],
                    ["function-id", self.parakeet_fid],
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
                    ["function-id", self.canary_fid],
                ],
            )
            self.asr_canary = riva.client.ASRService(auth_canary)
        except Exception as e:
            logging.error(f"Riva ASR setup failed: {e}")
        finally:
            self._is_loading = False

    def reload(self, api_key: str, parakeet_fid: str = "", canary_fid: str = ""):
        self.api_key = api_key.strip() if api_key else ""
        if parakeet_fid:
            self.parakeet_fid = parakeet_fid.strip()
        if canary_fid:
            self.canary_fid = canary_fid.strip()
        self._setup()

    def is_ready(self) -> bool:
        return not self._is_loading and getattr(self, "asr_parakeet", None) is not None and bool(self.api_key)

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
                # Adjust confidence threshold for Riva (specifically Canary).
                # Sometimes Canary returns 0.00 even for valid transcripts.
                # We allow literal 0.0 (possibly "not reported") or anything >= 0.3.
                if confidence is not None and 0.0 < confidence < 0.3:
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
                "input_tokens": (len(transcript) + 3) // 4,
                "output_tokens": 0,
                "detected_lang": safe_lang
            }
        return transcript, stats

    def get_status(self) -> dict:
        """Return readiness status for Riva ASR."""
        ready = self.is_ready()
        
        if self._is_loading:
            status = "loading"
            message = "Riva ASR is connecting..."
        else:
            status = "ready" if ready else ("no_api_key" if not self.api_key else "error")
            message = "Riva ASR is ready." if ready else ("Riva ASR requires an NVIDIA API key." if not self.api_key else "Riva ASR setup failed.")
            
        return {
            "name": "riva-asr",
            "status": status,
            "ready": ready,
            "message": message,
            "progress": 1.0 if ready else (0.5 if self._is_loading else 0.0),
            "details": {
                "parakeet": self.asr_parakeet is not None,
                "canary": self.asr_canary is not None,
                "loading": self._is_loading,
            }
        }

    def make_config(self, sample_rate: int, lang: str):
        # Riva Triton server does not accept 'multi' as a valid BCP-47 code.
        # Fallback to en-US to prevent grpc exception. 
        safe_lang = "en-US" if lang.lower() == "multi" else lang
        
        return riva.client.RecognitionConfig(
            encoding=riva.client.AudioEncoding.LINEAR_PCM,
            sample_rate_hertz=sample_rate,
            language_code=safe_lang,
            max_alternatives=1,
            enable_automatic_punctuation=True,
            audio_channel_count=1,
        )
