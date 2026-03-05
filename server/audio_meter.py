"""
audio_meter.py — Lightweight real-time RMS audio level meter.

Runs two separate pyaudio input streams (mic/loopback) in background threads
and exposes the latest normalised level (0.0–1.0) for each.
"""

import threading
import numpy as np
import pyaudiowpatch as pyaudio

_FRAMES = 512
_MAX_RMS = 8000.0  # clamp to this RMS for normalisation


class AudioMeter:
    """Streams RMS audio levels for a mic input and a loopback output device."""

    def __init__(self):
        self._input_level: float = 0.0
        self._output_level: float = 0.0
        self._input_thread: threading.Thread | None = None
        self._output_thread: threading.Thread | None = None
        self._running = False
        self._input_device_index: int | None = None
        self._output_device_index: int | None = None

    # ── Public API ────────────────────────────────────────────────────────────

    @property
    def input_level(self) -> float:
        return self._input_level

    @property
    def output_level(self) -> float:
        return self._output_level

    def configure(self, input_device_index: int | None, output_device_index: int | None):
        """Update device selection and restart streams. Both sources metered independently."""
        self._input_device_index = input_device_index
        self._output_device_index = output_device_index
        if self._running:
            self.stop()
            self.start()

    def start(self):
        if self._running:
            return
        self._running = True
        self._input_level = 0.0
        self._output_level = 0.0
        self._input_thread = threading.Thread(
            target=self._measure_loop,
            args=(True,),
            daemon=True,
            name="meter-input",
        )
        self._output_thread = threading.Thread(
            target=self._measure_loop,
            args=(False,),
            daemon=True,
            name="meter-output",
        )
        self._input_thread.start()
        self._output_thread.start()

    def stop(self):
        self._running = False
        if self._input_thread:
            self._input_thread.join(timeout=1.0)
        if self._output_thread:
            self._output_thread.join(timeout=1.0)
        self._input_thread = None
        self._output_thread = None
        self._input_level = 0.0
        self._output_level = 0.0

    # ── Internal ──────────────────────────────────────────────────────────────

    def _measure_loop(self, is_input: bool):
        """Open a pyaudio stream and continuously read RMS levels."""
        try:
            with pyaudio.PyAudio() as p:
                device_info = self._resolve_device(p, is_input)
                if device_info is None:
                    return

                channels = max(1, device_info.get("maxInputChannels", 1))
                rate = int(device_info.get("defaultSampleRate", 44100))

                stream = p.open(
                    format=pyaudio.paInt16,
                    channels=channels,
                    rate=rate,
                    input=True,
                    frames_per_buffer=_FRAMES,
                    input_device_index=device_info["index"],
                )

                while self._running:
                    try:
                        data = stream.read(_FRAMES, exception_on_overflow=False)
                        arr = np.frombuffer(data, dtype=np.int16).astype(np.float32)
                        if channels > 1:
                            arr = arr.reshape(-1, channels).mean(axis=1)
                        rms = float(np.sqrt(np.mean(arr ** 2)))
                        level = min(rms / _MAX_RMS, 1.0)
                        if is_input:
                            self._input_level = level
                        else:
                            self._output_level = level
                    except Exception:
                        break

                stream.stop_stream()
                stream.close()

        except Exception as e:
            print(f"[AudioMeter] {'input' if is_input else 'output'} error: {e}")
        finally:
            if is_input:
                self._input_level = 0.0
            else:
                self._output_level = 0.0

    def _resolve_device(self, p: pyaudio.PyAudio, is_input: bool):
        """Return the device_info dict to open, or None on failure."""
        try:
            if is_input:
                if self._input_device_index is not None:
                    return p.get_device_info_by_index(self._input_device_index)
                return p.get_default_input_device_info()
            else:
                wasapi_info = p.get_host_api_info_by_type(pyaudio.paWASAPI)
                if self._output_device_index is not None:
                    target = p.get_device_info_by_index(self._output_device_index)
                    for lb in p.get_loopback_device_info_generator():
                        if target["name"] in lb["name"]:
                            return lb
                    return None
                # Default loopback
                dev = p.get_device_info_by_index(wasapi_info["defaultOutputDevice"])
                if not dev.get("isLoopbackDevice"):
                    for lb in p.get_loopback_device_info_generator():
                        if dev["name"] in lb["name"]:
                            return lb
                return dev
        except Exception as e:
            print(f"[AudioMeter] resolve_device error: {e}")
            return None
