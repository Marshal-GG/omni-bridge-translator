"""
Offline Whisper ASR model (openai-whisper).
Downloads the 'base' model (~145 MB) on demand to ~/.cache/whisper/
Runs entirely on CPU/GPU — no API key needed.
"""

import io
import os
import wave
import numpy as np
import threading

# Path where whisper stores its models
_WHISPER_CACHE = os.path.join(os.path.expanduser("~"), ".cache", "whisper")
_MODEL_NAME = "base"
_MODEL_FILE = os.path.join(_WHISPER_CACHE, f"{_MODEL_NAME}.pt")

# Download progress tracking
_download_progress: float = 0.0       # 0.0 – 100.0
_download_status: str = "idle"        # idle | downloading | done | error
_download_lock = threading.Lock()


def get_download_status() -> dict:
    with _download_lock:
        downloaded = os.path.exists(_MODEL_FILE)
        size_mb = 0.0
        if downloaded:
            try:
                size_mb = round(os.path.getsize(_MODEL_FILE) / (1024 * 1024), 1)
            except Exception:
                pass
        return {
            "downloaded": downloaded,
            "size_mb": size_mb,
            "progress": _download_progress,
            "status": "done" if downloaded and _download_status != "downloading" else _download_status,
        }


def delete_model() -> bool:
    """Delete the cached Whisper model file."""
    global _download_status, _download_progress
    try:
        if os.path.exists(_MODEL_FILE):
            os.remove(_MODEL_FILE)
        with _download_lock:
            _download_status = "idle"
            _download_progress = 0.0
        return True
    except Exception as e:
        print(f"[WhisperModel] Delete failed: {e}")
        return False


def start_download() -> bool:
    """Start downloading the Whisper base model in a background thread."""
    global _download_status, _download_progress
    with _download_lock:
        if _download_status == "downloading":
            return False  # Already in progress
        if os.path.exists(_MODEL_FILE):
            _download_status = "done"
            _download_progress = 100.0
            return False  # Already downloaded
        _download_status = "downloading"
        _download_progress = 0.0

    thread = threading.Thread(target=_do_download, daemon=True)
    thread.start()
    return True


def _do_download():
    """Background thread: stream-download the model and track progress."""
    global _download_status, _download_progress
    import requests

    # Whisper model URLs (same as openai-whisper uses internally)
    url = "https://openaipublic.azureedge.net/main/whisper/models/ed3a0b6b1c0edf879ad9b11b1af5a0e6ab5db9205f891f668f8b0e6c6326e34e/base.pt"
    os.makedirs(_WHISPER_CACHE, exist_ok=True)
    tmp_path = _MODEL_FILE + ".tmp"

    try:
        resp = requests.get(url, stream=True, timeout=30)
        resp.raise_for_status()
        total = int(resp.headers.get("content-length", 0))
        downloaded_bytes = 0

        with open(tmp_path, "wb") as f:
            for chunk in resp.iter_content(chunk_size=65536):
                if chunk:
                    f.write(chunk)
                    downloaded_bytes += len(chunk)
                    if total > 0:
                        with _download_lock:
                            _download_progress = round(downloaded_bytes / total * 100, 1)

        os.replace(tmp_path, _MODEL_FILE)
        with _download_lock:
            _download_status = "done"
            _download_progress = 100.0
        print("[WhisperModel] Download complete.")

    except Exception as e:
        print(f"[WhisperModel] Download failed: {e}")
        if os.path.exists(tmp_path):
            try:
                os.remove(tmp_path)
            except Exception:
                pass
        with _download_lock:
            _download_status = "error"
            _download_progress = 0.0


class WhisperModel:
    """Lazy-loaded Whisper ASR model for offline transcription."""

    def __init__(self):
        self._model = None
        self._load_lock = threading.Lock()

    def is_downloaded(self) -> bool:
        return os.path.exists(_MODEL_FILE)

    def _ensure_loaded(self):
        if self._model is not None:
            return
        with self._load_lock:
            if self._model is None:
                try:
                    import whisper
                    print("[WhisperModel] Loading model into memory...")
                    self._model = whisper.load_model(_MODEL_NAME)
                    print("[WhisperModel] Model loaded.")
                except Exception as e:
                    print(f"[WhisperModel] Load failed: {e}")
                    raise

    def transcribe(self, audio_bytes: bytes, sample_rate: int) -> str | None:
        """
        Transcribe raw PCM mono int16 audio.
        Returns transcript string or None.
        """
        if not self.is_downloaded():
            return None

        try:
            self._ensure_loaded()
            import whisper

            # Convert PCM int16 → float32 normalised [-1, 1]
            audio_np = np.frombuffer(audio_bytes, dtype=np.int16).astype(np.float32) / 32768.0

            # Resample to 16kHz if needed (whisper expects 16kHz)
            if sample_rate != 16000:
                import resampy
                audio_np = resampy.resample(audio_np, sample_rate, 16000)

            result = self._model.transcribe(audio_np, fp16=False)
            text = result.get("text", "").strip()
            return text if text else None

        except Exception as e:
            print(f"[WhisperModel] Transcribe error: {e}")
            return None
