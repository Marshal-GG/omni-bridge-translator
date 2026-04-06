"""
Google Cloud Translation API model (gRPC v3).

Service account credentials are supplied at runtime as a JSON string.
The JSON content is stored in Firestore (system/translation_config → service_account)
and passed from the Flutter client — no credentials file is bundled with the server.
"""

import json
import time
import logging
from typing import Any, Union, Optional


class GoogleCloudTranslationModel:
    """
    Wraps Google Cloud Translation API v3 (gRPC).
    Authenticated via service account JSON content passed from the client.
    Credentials are stored in Firestore and cached in Flutter secure storage.
    """

    def __init__(self, credentials: Any = ""):
        self._credentials = credentials
        self._client = None
        self._project_id = ""
        self._location = "global"
        self._is_loading = False
        self._reload_client()

    def reload(self, credentials: Any):
        self._credentials = credentials
        self._client = None
        self._reload_client()

    def _reload_client(self):
        if not self._credentials or str(self._credentials).lower() in ("undefined", "null", "none"):
            self._client = None
            return

        self._is_loading = True
        try:
            from google.cloud import translate_v3 as translate
            from google.oauth2 import service_account

            if isinstance(self._credentials, dict):
                info = self._credentials
                logging.debug(f"[GoogleCloudTranslationModel] Received credentials as dict")
            elif isinstance(self._credentials, str):
                # Clean up the string (strip whitespace, handles potential double-quotes)
                cred_str = self._credentials.strip()
                if cred_str.startswith('"') and cred_str.endswith('"'):
                    cred_str = cred_str[1:-1]

                logging.debug(f"[GoogleCloudTranslationModel] Parsing credentials string (len: {len(cred_str)})")
                
                # Using strict=False allows raw control characters (like newlines)
                # which are common in service account JSONs pasted into configurations.
                info = json.loads(cred_str, strict=False)
            else:
                raise ValueError(f"Credentials must be a dict or JSON string, got {type(self._credentials).__name__}")

            if not isinstance(info, dict):
                raise ValueError(f"Credentials content must be a dictionary object, got {type(info).__name__}")

            self._project_id = info.get("project_id", "")
            if not self._project_id:
                raise ValueError("Credentials missing required 'project_id' field")

            # Sanitize private_key (handles common double-escaping of newlines)
            if "private_key" in info and isinstance(info["private_key"], str):
                info["private_key"] = info["private_key"].replace("\\n", "\n")

            credentials = service_account.Credentials.from_service_account_info(
                info,
                scopes=["https://www.googleapis.com/auth/cloud-translation"],
            )
            self._client = translate.TranslationServiceClient(credentials=credentials)
            logging.info("[GoogleCloudTranslationModel] gRPC client initialized successfully.")
        except (json.JSONDecodeError, ValueError) as e:
            # If parsing fails, log a bit more context if it's a string
            diagnostic = ""
            if isinstance(self._credentials, str):
                cred_str = self._credentials.strip()
                diagnostic = f" | Snippet: {cred_str[:50]}...{cred_str[-20:]}"
            logging.error(f"[GoogleCloudTranslationModel] Invalid credentials content: {e}{diagnostic}")
            self._client = None
        except Exception as e:
            logging.error(f"[GoogleCloudTranslationModel] Failed to init gRPC client: {type(e).__name__}")
            self._client = None
        finally:
            self._is_loading = False

    def is_ready(self) -> bool:
        return not self._is_loading and self._client is not None and bool(self._project_id)

    def get_status(self) -> dict:
        ready = self.is_ready()
        
        if self._is_loading:
            status = "loading"
            message = "Google Cloud Translation is connecting..."
        else:
            # If not ready, we use "fallback" instead of "no_credentials" to avoid red indicator
            # since the system automatically falls back to the free engine.
            status = "ready" if ready else "fallback"
            message = ("Google Cloud Translation (gRPC) is ready." if ready 
                       else "Using fallback engine (Google Free). Configure credentials for gRPC v3.")
            
        return {
            "name": "google_api",
            "status": status,
            "ready": ready,
            "message": message,
            "progress": 100.0 if ready else (50.0 if self._is_loading else 0.0),
            "details": {
                "version": "v3_grpc",
                "loading": self._is_loading
            },
        }

    def translate(self, text: str, source_lang: str, target_lang: str) -> tuple:
        start = time.monotonic()

        if not self.is_ready():
            return None, {"error": "Google Cloud credentials not configured"}
        assert self._client is not None

        # Same-language passthrough
        src = source_lang if source_lang != "auto" else None
        if src and src == target_lang:
            return text, {"engine": "google-cloud-v3-grpc", "latency_ms": 0}

        try:
            parent = f"projects/{self._project_id}/locations/{self._location}"
            request = {
                "parent": parent,
                "contents": [text],
                "target_language_code": target_lang,
                "mime_type": "text/plain",
            }
            if src:
                request["source_language_code"] = src

            response = self._client.translate_text(request=request)
            translation = response.translations[0]
            result = translation.translated_text
            detected = translation.detected_language_code or (src or "")
            latency_ms = int((time.monotonic() - start) * 1000)

            return result, {
                "engine": "google-cloud-v3-grpc",
                "latency_ms": latency_ms,
                "input_chars": len(text),
                "output_chars": len(result) if result else 0,
                "input_tokens": len(text),
                "output_tokens": len(result) if result else 0,
                "detected_language": str(detected),
            }

        except Exception as e:
            logging.error(f"Google Cloud v3 gRPC error: {type(e).__name__}: {e}")
            latency_ms = int((time.monotonic() - start) * 1000)
            return None, {
                "engine": "google-cloud-v3-grpc",
                "latency_ms": latency_ms,
                "error": str(e),
            }
