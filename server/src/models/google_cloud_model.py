"""
Google Cloud Translation API model (Official SDK v3 gRPC).
Strictly uses Service Account JSON for maximum performance.
"""

import time
import logging
import os
import json
from google.cloud import translate_v3 as translate

class GoogleCloudModel:
    """
    Wraps official Google Cloud Translation API (v3 gRPC).
    Requires a Service Account JSON path for authentication.
    """

    def __init__(self, json_path: str = "", project_id: str = "omni-bridge-ai-translator"):
        self.json_path = json_path.strip()
        self.project_id = project_id
        self._client = None
        self._location = "global"
        
        # Lazy initialization: don't call _init_client() here to avoid startup noise.

    def _init_client(self):
        """Initialize the v3 gRPC client using the Service Account JSON."""
        if not self.json_path:
            return

        import traceback
        logging.info(f"[GoogleCloudModel] Initialization triggered by:\n{''.join(traceback.format_stack()[-5:])}")

        try:
            full_path = self.json_path
            if not os.path.isabs(full_path):
                full_path = os.path.abspath(full_path)
            
            if not os.path.isfile(full_path):
                logging.error(f"[GoogleCloudModel] JSON file not found: {full_path}")
                return

            # Extract project ID from JSON if possible
            try:
                with open(full_path, "r") as f:
                    creds = json.load(f)
                    if "project_id" in creds:
                        self.project_id = creds["project_id"]
            except Exception as e:
                logging.warning(f"[GoogleCloudModel] Could not read project_id from JSON: {e}")

            # Initialize v3 gRPC client
            self._client = translate.TranslationServiceClient.from_service_account_json(full_path)
            logging.info(f"[GoogleCloudModel] Initialized V3 gRPC client (Global) for project: {self.project_id}")
        except Exception as e:
            logging.error(f"[GoogleCloudModel] Failed to initialize v3 client: {e}")
            self._client = None

    def reload(self, json_path: str):
        """Update the path if changed. Client will be lazily initialized on next translate."""
        new_path = json_path.strip()
        if self.json_path != new_path:
            self.json_path = new_path
            self._client = None  # Reset client so next translate() re-initializes
            # No _init_client() call here!

    def is_ready(self) -> bool:
        """Smarter ready check: ready if client is live OR if path exists (lazy)."""
        if self._client is not None:
            return True
        if not self.json_path:
            return False
        # Check if file exists without initializing heavy client
        return os.path.isfile(self.json_path)

    def get_status(self) -> dict:
        ready = self.is_ready()
        return {
            "name": "google_api",
            "status": "ready" if ready else "no_credentials",
            "ready": ready,
            "message": "Google Cloud v3 (gRPC) is ready." if ready else "Requires Service Account JSON path.",
            "progress": 100.0 if ready else 0.0,
            "details": {"version": "v3_grpc", "project_id": self.project_id}
        }

    def translate(self, text: str, source_lang: str, target_lang: str) -> tuple[str | None, dict]:
        """
        Translate *text* using Google Cloud v3 gRPC.
        """
        start = time.monotonic()
        
        # Initialize client lazily if not already done
        if self._client is None and self.json_path:
            self._init_client()

        if not self.is_ready():
            return None, {"error": "Google v3 client not initialized"}

        try:
            # Handle same-language passthrough
            src = source_lang if source_lang != "auto" else ""
            if src and src == target_lang:
                return text, {
                    "engine": "google-cloud-v3-grpc",
                    "latency_ms": 0,
                    "version": "v3_grpc",
                }

            parent = f"projects/{self.project_id}/locations/{self._location}"
            
            response = self._client.translate_text(
                request={
                    "parent": parent,
                    "contents": [text],
                    "mime_type": "text/plain",
                    "source_language_code": src if src else None,
                    "target_language_code": target_lang,
                }
            )
            
            result = response.translations[0].translated_text
            latency_ms = int((time.monotonic() - start) * 1000)
            logging.info(f"[GoogleAPI v3_grpc] Text: '{text[:20]}...' | Total: {latency_ms}ms | Chars: {len(text)}")

            return result, {
                "engine": "google-cloud-v3-grpc",
                "latency_ms": latency_ms,
                "version": "v3_grpc",
                "input_tokens": len(text),
                "output_tokens": len(result) if result else 0,
                # Keep chars for backward compatibility if needed
                "input_chars": len(text),
                "output_chars": len(result) if result else 0,
            }

        except Exception as e:
            logging.error(f"Google Cloud v3 gRPC error: {e}")
            latency_ms = int((time.monotonic() - start) * 1000)
            return None, {
                "engine": "google-cloud-v3-grpc",
                "latency_ms": latency_ms,
                "error": str(e),
                "version": "v3_grpc",
            }
