# Copyright (c) 2026 Omni Bridge. All rights reserved.
# 
# Licensed under the PERSONAL STUDY & LEARNING LICENSE v1.0.
# Commercial use and public redistribution of modified versions are strictly prohibited.
# See the LICENSE file in the project root for full license terms.

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
        from shared_pyaudio import get_pyaudio
        try:
            p = get_pyaudio()
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

            import time
            while self._running:
                try:
                    if not stream.is_active():
                        time.sleep(0.1)
                        continue
                        
                    try:
                        data = stream.read(_FRAMES, exception_on_overflow=False)
                    except IOError:
                        time.sleep(0.1)
                        continue

                    arr = np.frombuffer(data, dtype=np.int16).astype(np.float32)
                    if channels > 1:
                        arr = arr.reshape(-1, channels).mean(axis=1)
                        
                    # Calculate true RMS
                    rms = float(np.sqrt(np.mean(arr ** 2)))
                    
                    if rms > 1.0:  # Ignore microscopic noise floor
                        db = 20 * np.log10(rms / 32768.0)
                        # Map roughly -50dB (quiet) to 0.0, and 0dB (loud) to 1.0
                        level = (db + 50.0) / 50.0
                        level = max(0.0, min(level, 1.0))
                    else:
                        level = 0.0

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
            # 1. Resolve WASAPI host API index safely (avoid get_host_api_info_by_type)
            wasapi_index = -1
            for i in range(p.get_host_api_count()):
                try:
                    hapi = p.get_host_api_info_by_index(i)
                    if hapi.get("type") == pyaudio.paWASAPI:
                        wasapi_index = i
                        break
                except Exception:
                    continue

            if is_input:
                if self._input_device_index is not None:
                    try:
                        info = p.get_device_info_by_index(self._input_device_index)
                        if info: return info
                    except Exception: pass
                
                # Default input (WASAPI preferred)
                # Find any WASAPI input
                for i in range(p.get_device_count()):
                    try:
                        info = p.get_device_info_by_index(i)
                        name = info.get("name", "")
                        if "Primary Sound Driver" in name or "Microsoft Sound Mapper" in name:
                            continue
                        if info.get("hostApi") == wasapi_index and info.get("maxInputChannels", 0) > 0:
                            return info
                    except Exception: continue
                # Fallback: find ANY input
                for i in range(p.get_device_count()):
                    try:
                        info = p.get_device_info_by_index(i)
                        name = info.get("name", "")
                        if "Primary Sound Driver" in name or "Microsoft Sound Mapper" in name:
                            continue
                        if info.get("maxInputChannels", 0) > 0:
                            return info
                    except Exception: continue
                return None
            else:
                # Loopback output selection
                if self._output_device_index is not None:
                    try:
                        target = p.get_device_info_by_index(self._output_device_index)
                        # We MUST use a loopback version of the target for WASAPI
                        for lb in p.get_loopback_device_info_generator():
                            if target["name"] in lb["name"]:
                                return lb
                    except Exception: pass

                # Default loopback

                # Fallback: Search all WASAPI loopbacks, avoiding virtual drivers
                for lb in p.get_loopback_device_info_generator():
                    name = lb.get("name", "")
                    if "Primary Sound Driver" in name or "Microsoft Sound Mapper" in name:
                        continue
                    return lb
                return None
        except Exception as e:
            print(f"[AudioMeter] resolve_device error: {e}")
            return None
