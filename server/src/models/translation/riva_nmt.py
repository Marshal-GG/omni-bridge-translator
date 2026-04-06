"""
NVIDIA Riva NMT implementation.
"""

import logging
import time
import riva.client  # type: ignore[import]
from src.utils.language_support import RIVA_NMT_LANGS as RIVA_SUPPORTED_LANGS

class RivaNMTModel:
    """Wraps NVIDIA Riva Neural Machine Translation (NMT)."""

    def __init__(self, api_key: str, function_id: str = ""):
        self.api_key = api_key.strip() if api_key else ""
        self.function_id = function_id.strip() if function_id else ""
        self.nmt_client = None
        self._is_loading = False
        self._setup()

    def _setup(self):
        self._is_loading = True
        try:
            if not self.api_key:
                return
            
            auth_nmt = riva.client.Auth(
                # Change the order to auth, then other args if needed, 
                # but riva.client.Auth(None) is used for Bearer token usually.
                None,
                use_ssl=True,
                uri="grpc.nvcf.nvidia.com:443",
                metadata_args=[
                    ["authorization", f"Bearer {self.api_key}"],
                    ["function-id", self.function_id],
                ],
            )
            self.nmt_client = riva.client.NeuralMachineTranslationClient(auth_nmt)
        except Exception as e:
            logging.error(f"Riva NMT setup failed: {e}")
        finally:
            self._is_loading = False

    def reload(self, api_key: str, function_id: str = ""):
        self.api_key = api_key.strip() if api_key else ""
        if function_id:
            self.function_id = function_id.strip()
        self._setup()

    def is_ready(self) -> bool:
        return not self._is_loading and self.nmt_client is not None and bool(self.api_key)

    def supports_translation_pair(self, source_lang: str, target_lang: str) -> bool:
        src = "en" if source_lang == "auto" else source_lang
        # Riva does not support translating a language to itself (e.g., en:en)
        if src == target_lang:
            return False
            
        return (
            src in RIVA_SUPPORTED_LANGS
            and target_lang in RIVA_SUPPORTED_LANGS
        )

    def translate(self, text: str, source_lang: str, target_lang: str) -> tuple[str, dict]:
        """Translate using Riva gRPC NMT."""
        src = "en" if source_lang == "auto" else source_lang
        
        # Immediate return if languages match (safeguard)
        if src == target_lang:
            return text, {"engine": "riva-noop", "latency_ms": 0}

        if not self.supports_translation_pair(src, target_lang) or self.nmt_client is None:
            raise RuntimeError(f"Riva NMT does not support {src}→{target_lang} or client not ready.")

        start = time.monotonic()
        client = self.nmt_client
        if client is None:
             raise RuntimeError("Riva NMT client not ready.")

        response = client.translate(
            [text],
            model="",
            source_language=src,
            target_language=target_lang,
        )
        result = response.translations[0].text.strip()  # type: ignore[attr-defined]
        latency_ms = int((time.monotonic() - start) * 1000)
        
        return result, {
            "engine": "riva-grpc-mt",
            "model": "nvidia/riva-translate-4b",
            "latency_ms": latency_ms,
            "input_tokens": len(text),
            "output_tokens": len(result),
        }

    def get_status(self) -> dict:
        """Return readiness status for Riva NMT."""
        ready = self.is_ready()
        
        if self._is_loading:
            status = "loading"
            message = "Riva NMT is connecting..."
        else:
            # If not ready, we use "fallback" instead of "no_api_key" to avoid red indicator
            # since the system automatically falls back to Llama Translation.
            status = "ready" if ready else "fallback"
            message = ("Riva NMT is ready." if ready 
                       else "Using fallback engine (Llama). Configure NVIDIA API key for Riva NMT.")
            
        return {
            "name": "riva-nmt",
            "status": status,
            "ready": ready,
            "message": message,
            "progress": 1.0 if ready else (0.5 if self._is_loading else 0.0),
            "details": {
                "loading": self._is_loading
            }
        }
