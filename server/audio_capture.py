import pyaudiowpatch as pyaudio
import numpy as np
import threading
import queue
import time

def resample_audio(audio_data, orig_sr, target_sr=16000):
    if orig_sr == target_sr:
        return audio_data
    if orig_sr % target_sr == 0:
        factor = orig_sr // target_sr
        return audio_data[::factor]
    
    duration = len(audio_data) / orig_sr
    target_length = int(duration * target_sr)
    x_old = np.linspace(0, duration, len(audio_data))
    x_new = np.linspace(0, duration, target_length)
    audio_new = np.interp(x_new, x_old, audio_data)
    return audio_new.astype(np.int16)

class AudioCapture:
    def __init__(self, sample_rate=16000, chunk_duration=3, use_mic=False,
                 input_device_index=None, output_device_index=None,
                 desktop_volume=1.0, mic_volume=1.0):
        self.sample_rate = sample_rate
        self.chunk_duration = chunk_duration
        self.frames_per_chunk = self.sample_rate * self.chunk_duration
        self.use_mic = use_mic
        self.input_device_index = input_device_index
        self.output_device_index = output_device_index
        self.desktop_volume = max(0.0, float(desktop_volume))
        self.mic_volume = max(0.0, float(mic_volume))
        self.is_recording = False
        self.audio_queue = queue.Queue()
        self.recording_thread = None

    def start(self):
        if self.is_recording:
            return
        self.is_recording = True
        self.recording_thread = threading.Thread(target=self._record_loop, daemon=True)
        self.recording_thread.start()

    def stop(self):
        self.is_recording = False
        if self.recording_thread:
            self.recording_thread.join(timeout=1.0)

    def get_audio_chunk(self):
        try:
            return self.audio_queue.get_nowait()
        except queue.Empty:
            return None

    def clear(self):
        while not self.audio_queue.empty():
            try:
                self.audio_queue.get_nowait()
            except queue.Empty:
                break

    def _get_device_info(self, p):
        """Resolve the loopback output device (desktop audio) for recording."""
        # 1. Resolve WASAPI host API index safely
        wasapi_index = -1
        for i in range(p.get_host_api_count()):
            try:
                hapi = p.get_host_api_info_by_index(i)
                if hapi.get("type") == pyaudio.paWASAPI:
                    wasapi_index = i
                    break
            except Exception:
                continue

        if wasapi_index == -1:
            raise RuntimeError("WASAPI is required for desktop audio capture.")

        if self.output_device_index is not None:
            try:
                # Validate index against current device count
                if 0 <= self.output_device_index < p.get_device_count():
                    target = p.get_device_info_by_index(self.output_device_index)
                    # Ensure it's a loopback device
                    for loopback in p.get_loopback_device_info_generator():
                        if loopback["index"] == target["index"] or target["name"] in loopback["name"]:
                            return loopback
            except Exception as e:
                print(f"[AudioCapture] Error resolving manual output device {self.output_device_index}: {e}")

        # Default fallback: Search all WASAPI loopback devices
        print("[AudioCapture] Searching for default WASAPI loopback device...")

        # Find any WASAPI loopback that isn't a virtual driver
        for loopback in p.get_loopback_device_info_generator():
            name = loopback.get("name", "")
            if "Primary Sound Driver" in name or "Microsoft Sound Mapper" in name:
                continue
            print(f"[AudioCapture] Found fallback loopback: {name}")
            return loopback

        raise RuntimeError("No valid WASAPI loopback (desktop audio) device found.")

    def _get_mic_device_info(self, p):
        """Resolve the microphone input device."""
        wasapi_index = -1
        for i in range(p.get_host_api_count()):
            try:
                hapi = p.get_host_api_info_by_index(i)
                if hapi.get("type") == pyaudio.paWASAPI:
                    wasapi_index = i
                    break
            except Exception:
                continue

        if self.input_device_index is not None:
            try:
                if 0 <= self.input_device_index < p.get_device_count():
                    info = p.get_device_info_by_index(self.input_device_index)
                    if info: return info
            except Exception:
                pass

        # Default mic
        # Fallback: Find any working WASAPI input
        for i in range(p.get_device_count()):
            try:
                info = p.get_device_info_by_index(i)
                name = info.get("name", "")
                if "Primary Sound Driver" in name or "Microsoft Sound Mapper" in name:
                    continue
                if info.get("hostApi") == wasapi_index and info.get("maxInputChannels", 0) > 0:
                    return info
            except Exception:
                continue

        # If no WASAPI input, find ANY valid input
        for i in range(p.get_device_count()):
            try:
                info = p.get_device_info_by_index(i)
                name = info.get("name", "")
                if "Primary Sound Driver" in name or "Microsoft Sound Mapper" in name:
                    continue
                if info.get("maxInputChannels", 0) > 0:
                    return info
            except Exception:
                continue

        raise RuntimeError("No valid microphone input device found.")

    def _record_loop(self):
        from shared_pyaudio import get_pyaudio
        try:
            p = get_pyaudio()
            out_info = self._get_device_info(p)
            mic_info = self._get_mic_device_info(p) if self.use_mic else None

            self._stream_device(
                p=p,
                device_info=out_info,
                extra_device_info=mic_info,
            )
        except Exception as e:
            print(f"[AudioCapture] Error: {e}")
            self.is_recording = False

    def _open_stream_robust(self, p, device_info, is_mic=False):
        native_rate = int(device_info["defaultSampleRate"])
        
        # WASAPI Loopbacks often report 0 input channels, so you must use their output channel count
        if not is_mic and device_info.get("maxInputChannels", 0) == 0 and device_info.get("maxOutputChannels", 0) > 0:
            channels = int(device_info.get("maxOutputChannels", 2))
        else:
            channels = int(device_info.get("maxInputChannels", 2))
            
        if channels < 1:
            channels = 2

        try:
            stream = p.open(
                format=pyaudio.paInt16,
                channels=channels,
                rate=native_rate,
                frames_per_buffer=1024,
                input=True,
                input_device_index=device_info["index"],
            )
            return stream, channels, native_rate
        except Exception as e:
            fallback = 1 if channels >= 2 else 2
            print(f"[AudioCapture] Warning: failed opening {device_info['name']} with {channels} channels: {e}. Trying {fallback} channels...")
            try:
                stream = p.open(
                    format=pyaudio.paInt16,
                    channels=fallback,
                    rate=native_rate,
                    frames_per_buffer=1024,
                    input=True,
                    input_device_index=device_info["index"],
                )
                return stream, fallback, native_rate
            except Exception as e2:
                print(f"[AudioCapture] Error: complete failure opening device {device_info['name']}: {e2}")
                raise e

    def _stream_device(self, p, device_info, extra_device_info=None):
        """Open stream(s) and apply VAD-based chunking."""
        try:
            stream, channels, native_rate = self._open_stream_robust(p, device_info, is_mic=False)
        except Exception:
            self.is_recording = False
            return

        mic_stream = None
        mic_channels = 1
        mic_rate = native_rate
        if extra_device_info is not None:
            try:
                mic_stream, mic_channels, mic_rate = self._open_stream_robust(p, extra_device_info, is_mic=True)
            except Exception as e:
                print(f"[AudioCapture] Mic ignored due to error: {e}")
                mic_stream = None

        # ── VAD + Time-based chunking ─────────────────────────────────────
        # Primary: flush every MAX_CHUNK_DURATION seconds (guaranteed captions)
        # Secondary: flush early when silence follows speech (lower latency)
        SILENCE_THRESHOLD = 300      # RMS below this = silence  (tune if needed)
        SILENCE_DURATION  = 0.35     # seconds of silence to trigger early flush
        MIN_SPEECH_DURATION = 0.4    # don't flush if chunk is shorter than this
        MAX_CHUNK_DURATION  = 2.0    # always flush after this many seconds

        silence_frames_needed = int(native_rate * SILENCE_DURATION)
        min_speech_frames     = int(native_rate * MIN_SPEECH_DURATION)
        max_chunk_frames      = int(native_rate * MAX_CHUNK_DURATION)

        speech_buffer   = []
        silence_counter = 0
        in_speech       = False

        import time
        while self.is_recording:
            read_desktop = False
            read_mic     = False

            try:
                if stream.get_read_available() >= 1024:
                    read_desktop = True
                if mic_stream is not None and mic_stream.get_read_available() >= 1024:
                    read_mic = True
            except Exception as e:
                print(f"[AudioCapture] Loop error checking streams: {e}")
                self.is_recording = False
                break

            if not read_desktop and not read_mic:
                time.sleep(0.01)
                continue

            if read_desktop:
                try:
                    data = stream.read(1024, exception_on_overflow=False)
                    audio_data_int16 = np.frombuffer(data, dtype=np.int16)

                    # Stereo → mono for output/loopback
                    if channels > 1:
                        audio_data_int16 = (
                            audio_data_int16.reshape(-1, channels).mean(axis=1).astype(np.int16)
                        )

                    # Apply desktop volume
                    if self.desktop_volume != 1.0:
                        audio_data_int16 = np.clip(
                            audio_data_int16.astype(np.float32) * self.desktop_volume,
                            -32768, 32767,
                        ).astype(np.int16)
                except Exception as e:
                    print(f"[AudioCapture] Error reading desktop stream: {e}")
                    self.is_recording = False
                    break
            else:
                audio_data_int16 = np.zeros(1024, dtype=np.int16)

            # Mix mic if available
            if read_mic:
                try:
                    mic_data  = mic_stream.read(1024, exception_on_overflow=False)
                    mic_int16 = np.frombuffer(mic_data, dtype=np.int16)
                    if mic_channels > 1:
                        mic_int16 = mic_int16.reshape(-1, mic_channels).mean(axis=1).astype(np.int16)

                    if self.mic_volume != 1.0:
                        mic_int16 = np.clip(
                            mic_int16.astype(np.float32) * self.mic_volume,
                            -32768, 32767,
                        ).astype(np.int16)

                    if mic_rate != native_rate:
                        mic_int16 = resample_audio(mic_int16, mic_rate, native_rate)

                    min_len = min(len(audio_data_int16), len(mic_int16))
                    audio_data_int16 = np.maximum(
                        audio_data_int16[:min_len].astype(np.float32),
                        mic_int16[:min_len].astype(np.float32),
                    ).astype(np.int16)
                except Exception:
                    pass

            rms       = np.sqrt(np.mean(audio_data_int16.astype(np.float32) ** 2))
            is_silent = rms < SILENCE_THRESHOLD

            speech_buffer.extend(audio_data_int16.tolist())

            if not is_silent:
                in_speech       = True
                silence_counter = 0
            elif in_speech:
                silence_counter += len(audio_data_int16)

            # Decide whether to flush
            should_flush = False
            buf_len      = len(speech_buffer)

            # 1. Time-based: always flush at max duration (guaranteed captions)
            if buf_len >= max_chunk_frames:
                should_flush = True

            # 2. VAD-based: flush early when silence follows enough speech
            elif (
                in_speech
                and buf_len >= min_speech_frames
                and silence_counter >= silence_frames_needed
            ):
                should_flush = True

            if should_flush:
                chunk     = np.array(speech_buffer, dtype=np.int16)
                chunk_16k = resample_audio(chunk, native_rate, self.sample_rate)
                self.audio_queue.put((chunk_16k, self.sample_rate))
                speech_buffer   = []
                silence_counter = 0
                in_speech       = False

        if speech_buffer and in_speech:
            chunk = np.array(speech_buffer, dtype=np.int16)
            chunk_16k = resample_audio(chunk, native_rate, self.sample_rate)
            self.audio_queue.put((chunk_16k, self.sample_rate))

        stream.stop_stream()
        stream.close()
        if mic_stream:
            mic_stream.stop_stream()
            mic_stream.close()
