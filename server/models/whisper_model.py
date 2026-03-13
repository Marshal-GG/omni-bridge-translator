"""
Offline Whisper ASR model (openai-whisper).
Supports multiple model sizes: tiny, base, small, medium.
Each size is downloaded/cached independently to ~/.cache/whisper/
"""

import os
import threading
from typing import Literal, Any

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

# Global model cache to share memory across multiple WhisperModel instances
_MODEL_CACHE: dict[str, Any] = {}
_GLOBAL_LOAD_LOCK = threading.Lock()
_GLOBAL_METER_LOCK = threading.Lock() # For meter access if needed


def _model_file(size: str) -> str:
    return os.path.join(_WHISPER_CACHE, f"{size}.pt")


# ── Public API ────────────────────────────────────────────────────────────────

def get_download_status(size: str = "base") -> dict:
    """Get the download status of the given Whisper model size."""
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


def is_gpu_available() -> bool:
    """Check if a CUDA-compatible GPU is available."""
    try:
        import torch
        return torch.cuda.is_available()
    except ImportError:
        return False


def get_gpu_info() -> dict:
    """Return details about the available GPU, if any."""
    available = is_gpu_available()
    info = {
        "available": available, 
        "name": "None",
        "vram_used": 0.0,
        "vram_total": 0.0
    }
    if available:
        try:
            import torch
            info["name"] = torch.cuda.get_device_name(0)
            
            # Get VRAM info in GB
            properties = torch.cuda.get_device_properties(0)
            info["vram_total"] = round(properties.total_memory / (1024**3), 2)
            
            # memory_allocated is what's actually used by tensors
            # memory_reserved is what's held by the caching allocator
            # Using memory_reserved gives a better idea of what the OS/Driver sees as used
            info["vram_used"] = round(torch.cuda.memory_reserved(0) / (1024**3), 2)
        except Exception:
            info["name"] = "Unknown CUDA Device"
    return info


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
                    f.write(bytes(chunk))
                    downloaded_bytes += len(chunk)
                    if total > 0:
                        with _state_lock:
                            _state[size]["progress"] = round(float(downloaded_bytes) / total * 100, 1)

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
        self._is_loading = False
        self._lock = threading.Lock()

    @property
    def model_size(self) -> str:
        return self._size

    @model_size.setter
    def model_size(self, size: str):
        size = size if size in _MODEL_INFO else "base"
        if size != self._size:
            self._size = size
            # Note: We no longer need to nullify self._model here as we use global cache

    def is_downloaded(self) -> bool:
        return os.path.exists(_model_file(self._size))

    def _ensure_loaded(self):
        # 1. Quick check without lock
        if self._size in _MODEL_CACHE:
            return

        with _GLOBAL_LOAD_LOCK:
            # 2. Check again inside lock
            if self._size in _MODEL_CACHE:
                return

            import whisper
            import torch
            import logging
            device = "cuda" if torch.cuda.is_available() else "cpu"
            logging.info(f"[WhisperModel] Loading {self._size} model into memory using {device}...")
            self._is_loading = True
            try:
                model = whisper.load_model(self._size, device=device)
                _MODEL_CACHE[self._size] = {
                    "model": model,
                    "device": device
                }
                logging.info(f"[WhisperModel] {self._size} model loaded on {device}.")
            finally:
                self._is_loading = False

    def unload_model(self):
        """Unload the model from the global cache and clear resources."""
        import logging
        with _GLOBAL_LOAD_LOCK:
            if self._size in _MODEL_CACHE:
                logging.info(f"[WhisperModel] Unloading {self._size} model from memory...")
                del _MODEL_CACHE[self._size]
                import gc
                gc.collect()
                try:
                    import torch
                    if torch.cuda.is_available():
                        torch.cuda.empty_cache()
                except ImportError:
                    pass
                logging.info("[WhisperModel] Model unloaded.")

    def get_status(self) -> dict:
        """Return status for the currently active Whisper model size."""
        return self.get_status_for_size(self._size)

    def get_status_for_size(self, size: str) -> dict:
        """Return granular status for a calculation specific Whisper model size."""
        info = get_download_status(size)
        
        status = info["status"]
        ready = False
        message = ""
        
        if status == "done":
            if size in _MODEL_CACHE:
                status = "ready"
                ready = True
                message = f"Whisper {size} is ready."
            elif self._is_loading and self._size == size:
                status = "loading"
                message = f"Loading Whisper {size} into memory..."
            else:
                status = "downloaded"
                message = f"Whisper {size} is downloaded but not loaded."
        elif status == "downloading":
            message = f"Downloading Whisper {size}: {info['progress']}%"
        elif status == "idle":
            status = "not_downloaded"
            message = f"Whisper {size} is not downloaded."
        elif status == "error":
            message = f"Error with Whisper {size} model."

        return {
            "name": f"whisper-{size}",
            "status": status,
            "ready": ready,
            "message": message,
            "progress": info["progress"],
            "details": {
                "size_mb": info["size_mb"],
                "expected_mb": info["expected_mb"],
                "loaded": size in _MODEL_CACHE,
                "device": _MODEL_CACHE[size]["device"] if size in _MODEL_CACHE else "none",
                "is_loading": self._is_loading and self._size == size,
            }
        }

    def get_all_statuses(self) -> list:
        """Return statuses for all supported Whisper model sizes."""
        return [self.get_status_for_size(size) for size in _MODEL_INFO]

    def transcribe(self, audio_bytes: bytes, sample_rate: int, source_lang: str = "auto") -> tuple[str | None, dict | None]:
        if not self.is_downloaded():
            return None, None
        
        import time
        start = time.monotonic()
        
        try:
            self._ensure_loaded()
            audio_np = np.frombuffer(audio_bytes, dtype=np.int16).astype(np.float32) / 32768.0
            
            if audio_np.size == 0:
                return None, None
                
            if sample_rate != 16000:
                import resampy
                audio_np = resampy.resample(audio_np, sample_rate, 16000)
            from typing import Any
            cache_entry = _MODEL_CACHE.get(self._size)
            if cache_entry is None:
                print(f"[WhisperModel] Model not loaded for {self._size}")
                return None, None
            
            model = cache_entry["model"]
            device = cache_entry["device"]
            
            # Use FP16 only if we are on GPU (CUDA)
            kwargs: dict[str, Any] = {"fp16": (device == "cuda")}
            if source_lang != "auto":
                kwargs["language"] = source_lang
                
            with self._lock:
                result = model.transcribe(audio_np, **kwargs)
            text = result.get("text", "").strip()
            transcript = text if text else None
            stats = None
            if transcript:
                latency_ms = int((time.monotonic() - start) * 1000)
                stats = {
                    "engine": "whisper-asr",
                    "model": f"whisper-{self._size}",
                    "latency_ms": latency_ms,
                    "input_tokens": len(transcript),
                    "output_tokens": 0,
                }
            return transcript, stats
        except Exception:
            import traceback
            traceback.print_exc()
            print(f"[WhisperModel] Transcribe error ({self._size})")
            return None, None
