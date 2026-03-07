"""
Offline Whisper ASR model (openai-whisper).
Supports multiple model sizes: tiny, base, small, medium.
Each size is downloaded/cached independently to ~/.cache/whisper/
"""

import os
import threading
from typing import Literal

import numpy as np

# ── Model metadata ────────────────────────────────────────────────────────────

WhisperSize = Literal["tiny", "base", "small", "medium"]

_MODEL_INFO = {
    "tiny":   {"url": "https://openaipublic.azureedge.net/main/whisper/models/65147644a518d12f04e32d6f3b26facc3f8dd46e5390956a9424a650139c63c8/tiny.pt",   "size_mb": 75},
    "base":   {"url": "https://openaipublic.azureedge.net/main/whisper/models/ed3a0b6b1c0edf879ad9b11b1af5a0e6ab5db9205f891f668f8b0e6c6326e34e/base.pt",   "size_mb": 145},
    "small":  {"url": "https://openaipublic.azureedge.net/main/whisper/models/9ecf779972d90ba49c06d968637d720dd632c55bbf19d441fb42bf17a411e794/small.pt",  "size_mb": 465},
    "medium": {"url": "https://openaipublic.azureedge.net/main/whisper/models/345ae4da62f9b3d59415adc60127b97c714f32e89e936602e85993674d08dcb1/medium.pt", "size_mb": 1500},
}

_WHISPER_CACHE = os.path.join(os.path.expanduser("~"), ".cache", "whisper")

# Per-size state: { size -> { "progress": float, "status": str } }
_state: dict[str, dict] = {
    size: {"progress": 0.0, "status": "idle"} for size in _MODEL_INFO
}
_state_lock = threading.Lock()


def _model_file(size: str) -> str:
    return os.path.join(_WHISPER_CACHE, f"{size}.pt")


# ── Public API ────────────────────────────────────────────────────────────────

def get_download_status(size: str = "base") -> dict:
    size = size if size in _MODEL_INFO else "base"
    path = _model_file(size)
    downloaded = os.path.exists(path)
    size_mb = 0.0
    if downloaded:
        try:
            size_mb = round(os.path.getsize(path) / (1024 * 1024), 1)
        except Exception:
            pass
    with _state_lock:
        st = _state[size]
        status = "done" if downloaded and st["status"] != "downloading" else st["status"]
        progress = 100.0 if downloaded and status == "done" else st["progress"]
    return {
        "downloaded": downloaded,
        "size_mb": size_mb,
        "progress": progress,
        "status": status,
        "model_size": size,
        "expected_mb": _MODEL_INFO[size]["size_mb"],
    }


def start_download(size: str = "base") -> bool:
    """Start downloading the given Whisper model size in the background."""
    size = size if size in _MODEL_INFO else "base"
    path = _model_file(size)
    with _state_lock:
        st = _state[size]
        if st["status"] == "downloading":
            return False
        if os.path.exists(path):
            st["status"] = "done"
            st["progress"] = 100.0
            return False
        st["status"] = "downloading"
        st["progress"] = 0.0

    thread = threading.Thread(target=_do_download, args=(size,), daemon=True)
    thread.start()
    return True


def delete_model(size: str = "base") -> bool:
    """Delete a cached Whisper model file."""
    size = size if size in _MODEL_INFO else "base"
    path = _model_file(size)
    try:
        if os.path.exists(path):
            os.remove(path)
        with _state_lock:
            _state[size]["status"] = "idle"
            _state[size]["progress"] = 0.0
        return True
    except Exception as e:
        print(f"[WhisperModel] Delete failed ({size}): {e}")
        return False


def _do_download(size: str):
    import requests
    url = _MODEL_INFO[size]["url"]
    path = _model_file(size)
    tmp_path = path + ".tmp"
    os.makedirs(_WHISPER_CACHE, exist_ok=True)

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
                        with _state_lock:
                            _state[size]["progress"] = round(downloaded_bytes / total * 100, 1)

        os.replace(tmp_path, path)
        with _state_lock:
            _state[size]["status"] = "done"
            _state[size]["progress"] = 100.0
        print(f"[WhisperModel] Download complete: {size}")

    except Exception as e:
        print(f"[WhisperModel] Download failed ({size}): {e}")
        if os.path.exists(tmp_path):
            try:
                os.remove(tmp_path)
            except Exception:
                pass
        with _state_lock:
            _state[size]["status"] = "error"
            _state[size]["progress"] = 0.0


# ── WhisperModel class ────────────────────────────────────────────────────────

class WhisperModel:
    """Lazy-loaded Whisper ASR. Each instance is bound to a specific model size."""

    def __init__(self, model_size: str = "base"):
        self._size = model_size if model_size in _MODEL_INFO else "base"
        self._model = None
        self._loaded_size: str | None = None
        self._load_lock = threading.Lock()

    @property
    def model_size(self) -> str:
        return self._size

    @model_size.setter
    def model_size(self, size: str):
        size = size if size in _MODEL_INFO else "base"
        if size != self._size:
            self._size = size
            # Unload old model so next transcribe reloads
            with self._load_lock:
                self._model = None
                self._loaded_size = None

    def is_downloaded(self) -> bool:
        return os.path.exists(_model_file(self._size))

    def _ensure_loaded(self):
        if self._model is not None and self._loaded_size == self._size:
            return
        with self._load_lock:
            if self._model is None or self._loaded_size != self._size:
                import whisper
                print(f"[WhisperModel] Loading {self._size} model into memory…")
                self._model = whisper.load_model(self._size)
                self._loaded_size = self._size
                print(f"[WhisperModel] {self._size} model loaded.")

    def transcribe(self, audio_bytes: bytes, sample_rate: int, source_lang: str = "auto") -> str | None:
        if not self.is_downloaded():
            return None
        try:
            self._ensure_loaded()
            audio_np = np.frombuffer(audio_bytes, dtype=np.int16).astype(np.float32) / 32768.0
            if sample_rate != 16000:
                import resampy
                audio_np = resampy.resample(audio_np, sample_rate, 16000)
            kwargs = {"fp16": False}
            if source_lang != "auto":
                kwargs["language"] = source_lang
            result = self._model.transcribe(audio_np, **kwargs)
            text = result.get("text", "").strip()
            return text if text else None
        except Exception as e:
            print(f"[WhisperModel] Transcribe error ({self._size}): {e}")
            return None
