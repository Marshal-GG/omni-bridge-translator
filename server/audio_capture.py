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
        wasapi_info = p.get_host_api_info_by_type(pyaudio.paWASAPI)

        if self.output_device_index is not None:
            target = p.get_device_info_by_index(self.output_device_index)
            for loopback in p.get_loopback_device_info_generator():
                if target["name"] in loopback["name"]:
                    return loopback
            raise RuntimeError(f"Could not find loopback for device: {target['name']}")
        else:
            # Guard: WASAPI sometimes returns a defaultOutputDevice index that
            # exceeds deviceCount, causing a C-level assertion abort.
            default_idx = wasapi_info.get("defaultOutputDevice", -1)
            device_count = p.get_device_count()
            if not (0 <= default_idx < device_count):
                raise RuntimeError(
                    f"WASAPI defaultOutputDevice index {default_idx} is out of range "
                    f"(device count: {device_count}). Try selecting a device manually."
                )
            device_info = p.get_device_info_by_index(default_idx)
            if not device_info.get("isLoopbackDevice"):
                for loopback in p.get_loopback_device_info_generator():
                    if device_info["name"] in loopback["name"]:
                        device_info = loopback
                        break
            return device_info

    def _get_mic_device_info(self, p):
        """Resolve the microphone input device."""
        if self.input_device_index is not None:
            info = p.get_device_info_by_index(self.input_device_index)
            return info
        info = p.get_default_input_device_info()
        return info

    def _record_loop(self):
        try:
            with pyaudio.PyAudio() as p:
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

    def _stream_device(self, p, device_info, extra_device_info=None):
        """Open stream(s) and apply VAD-based chunking."""
        channels = max(1, device_info.get("maxInputChannels", 1))
        native_rate = int(device_info["defaultSampleRate"])

        stream = p.open(
            format=pyaudio.paInt16,
            channels=channels,
            rate=native_rate,
            frames_per_buffer=1024,
            input=True,
            input_device_index=device_info["index"],
        )

        mic_stream = None
        mic_channels = 1
        mic_rate = native_rate
        if extra_device_info is not None:
            try:
                mic_channels = max(1, extra_device_info.get("maxInputChannels", 1))
                mic_rate = int(extra_device_info["defaultSampleRate"])
                mic_stream = p.open(
                    format=pyaudio.paInt16,
                    channels=mic_channels,
                    rate=mic_rate,
                    frames_per_buffer=1024,
                    input=True,
                    input_device_index=extra_device_info["index"],
                )
            except Exception as e:
                mic_stream = None

        SILENCE_THRESHOLD = 150
        SILENCE_DURATION = 0.33
        MIN_SPEECH_DURATION = 0.4
        MAX_CHUNK_DURATION = 2.5

        silence_frames_needed = int(native_rate * SILENCE_DURATION)
        min_speech_frames = int(native_rate * MIN_SPEECH_DURATION)
        max_chunk_frames = int(native_rate * MAX_CHUNK_DURATION)

        speech_buffer = []
        silence_counter = 0
        in_speech = False

        while self.is_recording:
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

            # If mic stream is open, blend it in
            if mic_stream is not None:
                try:
                    mic_data = mic_stream.read(1024, exception_on_overflow=False)
                    mic_int16 = np.frombuffer(mic_data, dtype=np.int16)
                    if mic_channels > 1:
                        mic_int16 = mic_int16.reshape(-1, mic_channels).mean(axis=1).astype(np.int16)

                    # Apply mic volume
                    if self.mic_volume != 1.0:
                        mic_int16 = np.clip(
                            mic_int16.astype(np.float32) * self.mic_volume,
                            -32768, 32767,
                        ).astype(np.int16)

                    # Resample mic if rate differs
                    if mic_rate != native_rate:
                        mic_int16 = resample_audio(mic_int16, mic_rate, native_rate)

                    # Mix: take the louder signal sample-by-sample
                    min_len = min(len(audio_data_int16), len(mic_int16))
                    mixed = np.maximum(
                        audio_data_int16[:min_len].astype(np.float32),
                        mic_int16[:min_len].astype(np.float32),
                    ).astype(np.int16)
                    audio_data_int16 = mixed
                except Exception:
                    pass  # don't crash if mic read fails

            rms = np.sqrt(np.mean(audio_data_int16.astype(np.float32) ** 2))
            is_silent = rms < SILENCE_THRESHOLD

            speech_buffer.extend(audio_data_int16.tolist())

            if not is_silent:
                in_speech = True
                silence_counter = 0
            elif in_speech:
                silence_counter += len(audio_data_int16)

            should_flush = False

            if (
                in_speech
                and len(speech_buffer) >= min_speech_frames
                and silence_counter >= silence_frames_needed
            ):
                should_flush = True

            if len(speech_buffer) >= max_chunk_frames:
                should_flush = True

            if should_flush:
                chunk = np.array(speech_buffer, dtype=np.int16)
                chunk_16k = resample_audio(chunk, native_rate, self.sample_rate)
                self.audio_queue.put((chunk_16k, self.sample_rate))
                speech_buffer = []
                silence_counter = 0
                in_speech = False

        if speech_buffer and in_speech:
            chunk = np.array(speech_buffer, dtype=np.int16)
            chunk_16k = resample_audio(chunk, native_rate, self.sample_rate)
            self.audio_queue.put((chunk_16k, self.sample_rate))

        stream.stop_stream()
        stream.close()
        if mic_stream:
            mic_stream.stop_stream()
            mic_stream.close()
