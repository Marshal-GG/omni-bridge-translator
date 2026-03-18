"""
NVIDIA Riva ASR + NMT Translation model.
Handles speech recognition via Riva Parakeet/Canary and translation via
Riva NMT (gRPC). Fallback logic is handled by the orchestrator.
"""

import re
import time
import logging
import riva.client  # type: ignore[import]
from src.utils.language_support import RIVA_NMT_LANGS as RIVA_SUPPORTED_LANGS, RIVA_PARAKEET_ASR_LANGS


class RivaModel:
    """Wraps NVIDIA Riva ASR and the Riva/Llama translation endpoint."""

    def __init__(self, api_key: str):
        self.api_key = api_key
        self.asr_parakeet = None
        self.asr_canary = None
        self.nmt_client = None
        self._setup()

    # ── Setup ────────────────────────────────────────────────────────────────

    def _setup(self):
        try:
            if not self.api_key:
                return
            
            # Parakeet Multilingual (supports en-US, hi-IN, bn-IN, and 'multi' / 'auto')
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

            # Canary (supports everything else: es, fr, de, zh, ja, ko, ru, pt, it, ar, nl, tr, vi, pl, id, th)
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

            # Neural Machine Translation (NMT) via gRPC
            auth_nmt = riva.client.Auth(
                None,
                use_ssl=True,
                uri="grpc.nvcf.nvidia.com:443",
                metadata_args=[
                    ["authorization", f"Bearer {self.api_key}"],
                    ["function-id", "10f92bba-1512-429a-9e5c-7d3129486c12"],
                ],
            )
            self.nmt_client = riva.client.NeuralMachineTranslationClient(auth_nmt)
        except Exception as e:
            import logging
            logging.error(f"Riva setup failed: {e}")

    def reload(self, api_key: str):
        self.api_key = api_key
        self._setup()

    def is_ready(self) -> bool:
        return getattr(self, "asr_parakeet", None) is not None and bool(self.api_key)

    def get_status(self) -> dict:
        """Return status for Riva models."""
        ready = self.is_ready()
        status = "ready" if ready else ("no_api_key" if not self.api_key else "error")
        message = "Riva is ready." if ready else ("Riva requires an API key." if not self.api_key else "Riva setup failed.")
        
        return {
            "name": "riva",
            "status": status,
            "ready": ready,
            "message": message,
            "progress": 100.0 if ready else 0.0,
            "details": {"has_key": bool(self.api_key)}
        }

    def supports_translation_pair(self, source_lang: str, target_lang: str) -> bool:
        src = source_lang if source_lang != "auto" else "auto"
        return (
            src in RIVA_SUPPORTED_LANGS
            and target_lang in RIVA_SUPPORTED_LANGS
        )

    # ── ASR ──────────────────────────────────────────────────────────────────

    def transcribe(self, audio_bytes: bytes, config) -> tuple[str | None, dict | None]:
        """Run offline ASR and return the transcript, or None if empty."""
        import time
        start = time.monotonic()
        
        # Route to the appropriate model function ID
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
                # Extract detected language if available (usually in result.language_code for multi/canary)
                detected_lang = getattr(result, "language_code", None)

                # Filter out single-character hallucinations (like "P")
                if len(raw_transcript) <= 1:
                    return None, None

                # Filter low-confidence results — hallucinations on silence typically
                # score below 0.5. Real speech almost always scores above 0.7.
                confidence = getattr(alt, "confidence", None)
                if confidence is not None and confidence < 0.5:
                    logging.debug(f"[RivaASR] Low confidence ({confidence:.2f}) filtered: {raw_transcript!r}")
                    return None, None

                transcript = raw_transcript
                
        stats = None
        if transcript:
            # Safely handle detected_lang which might be a gRPC object or lang-region code
            safe_lang = ""
            if detected_lang:
                safe_lang = str(detected_lang).split("-")[0].lower() # "ja-JP" -> "ja"

            stats = {
                "engine": "riva-asr",
                "model": model_name,
                "latency_ms": int((time.monotonic() - start) * 1000),
                "input_tokens": len(transcript),
                "output_tokens": 0,
                "detected_lang": safe_lang
            }
        return transcript, stats

    def make_asr_config(self, sample_rate: int, lang: str):
        return riva.client.RecognitionConfig(
            encoding=riva.client.AudioEncoding.LINEAR_PCM,
            sample_rate_hertz=sample_rate,
            language_code=lang,
            max_alternatives=1,
            enable_automatic_punctuation=True,
            audio_channel_count=1,
        )

    # ── Translation ──────────────────────────────────────────────────────────

    def translate(self, text: str, source_lang: str, target_lang: str) -> tuple[str, dict]:
        """Translate using Riva gRPC NMT only. Raises if unsupported or unavailable.
        Fallback logic is handled by the caller (orchestrator).
        """
        src = source_lang if source_lang != "auto" else "auto"
        is_riva_supported = self.supports_translation_pair(src, target_lang)

        if not is_riva_supported or self.nmt_client is None:
            raise RuntimeError(f"Riva NMT does not support {src}→{target_lang}.")

        start = time.monotonic()
        response = self.nmt_client.translate(
            [text],
            model="",
            source_language=src,
            target_language=target_lang,
        )
        result = response.translations[0].text.strip()  # type: ignore[union-attr]
        latency_ms = int((time.monotonic() - start) * 1000)
        return result, {
            "engine": "riva-grpc-mt",
            "model": "nvidia/riva-translate-4b",
            "latency_ms": latency_ms,
            "input_tokens": len(text),
            "output_tokens": len(result),
        }
