"""
Google Cloud Translation API model (gRPC v3).

Service account credentials are supplied at runtime as a JSON string.
The JSON content is stored in Firestore (system/translation_config → service_account)
and passed from the Flutter client — no credentials file is bundled with the server.
"""

import json
import time
import logging


class GoogleCloudModel:
    """
    Wraps Google Cloud Translation API v3 (gRPC).
    Authenticated via service account JSON content passed from the client.
    Credentials are stored in Firestore and cached in Flutter secure storage.
    """

    def __init__(self, credentials_json: str = ""):
        self._credentials_json = credentials_json.strip()
        self._client = None
        self._project_id = ""
        self._location = "global"
        self._reload_client()

    def reload(self, credentials_json: str):
        self._credentials_json = credentials_json.strip()
        self._client = None
        self._reload_client()

    def _reload_client(self):
        if not self._credentials_json:
            return
        try:
            from google.cloud import translate_v3 as translate
            from google.oauth2 import service_account

            info = json.loads(self._credentials_json)
            self._project_id = info.get("project_id", "")
            credentials = service_account.Credentials.from_service_account_info(
                info,
                scopes=["https://www.googleapis.com/auth/cloud-translation"],
            )
            self._client = translate.TranslationServiceClient(credentials=credentials)
            logging.info("[GoogleCloudModel] gRPC client initialized successfully.")
        except json.JSONDecodeError:
            logging.error("[GoogleCloudModel] Failed to parse credentials JSON — check Firestore field.")
            self._client = None
        except Exception as e:
            logging.error(f"[GoogleCloudModel] Failed to init gRPC client: {type(e).__name__}")
            self._client = None

    def is_ready(self) -> bool:
        return self._client is not None and bool(self._project_id)

    def get_status(self) -> dict:
        ready = self.is_ready()
        return {
            "name": "google_api",
            "status": "ready" if ready else "no_credentials",
            "ready": ready,
            "message": "Google Cloud Translation (gRPC) is ready." if ready else "Requires Google service account credentials.",
            "progress": 100.0 if ready else 0.0,
            "details": {"version": "v3_grpc"},
        }

    def translate(self, text: str, source_lang: str, target_lang: str) -> tuple:
        start = time.monotonic()

        if not self.is_ready():
            return None, {"error": "Google Cloud credentials not configured"}

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
