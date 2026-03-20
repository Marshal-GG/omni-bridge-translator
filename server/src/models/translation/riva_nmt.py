"""
NVIDIA Riva NMT implementation.
"""

import logging
import time
import riva.client  # type: ignore[import]
from src.utils.language_support import RIVA_NMT_LANGS as RIVA_SUPPORTED_LANGS

class RivaNMTModel:
    """Wraps NVIDIA Riva Neural Machine Translation (NMT)."""

    def __init__(self, api_key: str):
        self.api_key = api_key
        self.nmt_client = None
        self._setup()

    def _setup(self):
        try:
            if not self.api_key:
                return
            
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
            logging.error(f"Riva NMT setup failed: {e}")

    def reload(self, api_key: str):
        self.api_key = api_key
        self._setup()

    def is_ready(self) -> bool:
        return self.nmt_client is not None and bool(self.api_key)

    def supports_translation_pair(self, source_lang: str, target_lang: str) -> bool:
        src = source_lang if source_lang != "auto" else "auto"
        return (
            src in RIVA_SUPPORTED_LANGS
            and target_lang in RIVA_SUPPORTED_LANGS
        )

    def translate(self, text: str, source_lang: str, target_lang: str) -> tuple[str, dict]:
        """Translate using Riva gRPC NMT."""
        src = source_lang if source_lang != "auto" else "auto"
        
        if not self.supports_translation_pair(src, target_lang) or self.nmt_client is None:
            raise RuntimeError(f"Riva NMT does not support {src}→{target_lang} or client not ready.")

        start = time.monotonic()
        response = self.nmt_client.translate(
            [text],
            model="",
            source_language=src,
            target_language=target_lang,
        )
        result = response.translations[0].text.strip()
        latency_ms = int((time.monotonic() - start) * 1000)
        
        return result, {
            "engine": "riva-grpc-mt",
            "model": "nvidia/riva-translate-4b",
            "latency_ms": latency_ms,
            "input_tokens": len(text),
            "output_tokens": len(result),
        }
