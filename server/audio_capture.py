import pyaudiowpatch as pyaudio
import numpy as np
import threading
import queue
import time

class AudioCapture:
    def __init__(self, sample_rate=16000, chunk_duration=3, use_mic=False,
                 input_device_index=None, output_device_index=None):
        self.sample_rate = sample_rate
        self.chunk_duration = chunk_duration
        self.frames_per_chunk = self.sample_rate * self.chunk_duration
        self.use_mic = use_mic
        self.input_device_index = input_device_index
        self.output_device_index = output_device_index
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
        """Resolve the actual device_info to use for recording."""
        if self.use_mic:
            if self.input_device_index is not None:
                device_info = p.get_device_info_by_index(self.input_device_index)
                print(f"[AudioCapture] Using mic device: {device_info['name']} (index {self.input_device_index})")
            else:
                device_info = p.get_default_input_device_info()
                print(f"[AudioCapture] Using default mic: {device_info['name']}")
        else:
            # System audio (loopback)
            wasapi_info = p.get_host_api_info_by_type(pyaudio.paWASAPI)

            if self.output_device_index is not None:
                # User selected a specific output device — find its loopback
                target = p.get_device_info_by_index(self.output_device_index)
                device_info = None
                for loopback in p.get_loopback_device_info_generator():
                    if target["name"] in loopback["name"]:
                        device_info = loopback
                        break
                if device_info is None:
                    raise RuntimeError(f"Could not find loopback for device: {target['name']}")
                print(f"[AudioCapture] Using loopback for output: {device_info['name']}")
            else:
                # Auto-detect default output loopback
                device_info = p.get_device_info_by_index(wasapi_info["defaultOutputDevice"])
                if not device_info.get("isLoopbackDevice"):
                    for loopback in p.get_loopback_device_info_generator():
                        if device_info["name"] in loopback["name"]:
                            device_info = loopback
                            break
                print(f"[AudioCapture] Using default loopback: {device_info['name']}")

        return device_info

    def _record_loop(self):
        try:
            with pyaudio.PyAudio() as p:
                device_info = self._get_device_info(p)

                channels = device_info.get("maxInputChannels", 1)
                if channels < 1:
                    channels = 1

                native_rate = int(device_info["defaultSampleRate"])

                stream = p.open(
                    format=pyaudio.paInt16,
                    channels=channels,
                    rate=native_rate,
                    frames_per_buffer=1024,
                    input=True,
                    input_device_index=device_info["index"],
                )

                buffer = []
                actual_frames_per_chunk = int(native_rate * self.chunk_duration)

                while self.is_recording:
                    data = stream.read(1024, exception_on_overflow=False)
                    audio_data_int16 = np.frombuffer(data, dtype=np.int16)

                    # Stereo → mono
                    if channels > 1:
                        audio_data_int16 = (
                            audio_data_int16.reshape(-1, channels).mean(axis=1).astype(np.int16)
                        )

                    buffer.extend(audio_data_int16.tolist())

                    if len(buffer) >= actual_frames_per_chunk:
                        chunk = np.array(buffer[:actual_frames_per_chunk], dtype=np.int16)
                        self.audio_queue.put((chunk, native_rate))
                        buffer = buffer[actual_frames_per_chunk:]

                stream.stop_stream()
                stream.close()

        except Exception as e:
            print(f"[AudioCapture] Error: {e}")
            self.is_recording = False
