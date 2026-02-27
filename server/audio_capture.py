import pyaudiowpatch as pyaudio
import numpy as np
import threading
import queue
import time

class AudioCapture:
    def __init__(self, sample_rate=16000, chunk_duration=3):
        self.sample_rate = sample_rate
        self.chunk_duration = chunk_duration # in seconds
        self.frames_per_chunk = self.sample_rate * self.chunk_duration
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

    def _record_loop(self):
        try:
            with pyaudio.PyAudio() as p:
                wasapi_info = p.get_host_api_info_by_type(pyaudio.paWASAPI)
                default_speakers = p.get_device_info_by_index(wasapi_info["defaultOutputDevice"])
                
                if not default_speakers["isLoopbackDevice"]:
                    for loopback in p.get_loopback_device_info_generator():
                        if default_speakers["name"] in loopback["name"]:
                            default_speakers = loopback
                            break
                            
                stream = p.open(format=pyaudio.paInt16,
                                channels=default_speakers["maxInputChannels"],
                                rate=int(default_speakers["defaultSampleRate"]),
                                frames_per_buffer=1024,
                                input=True,
                                input_device_index=default_speakers["index"])
                
                buffer = []
                while self.is_recording:
                    # Read raw bytes
                    data = stream.read(1024, exception_on_overflow=False)
                    
                    # Convert to numpy array
                    audio_data_int16 = np.frombuffer(data, dtype=np.int16)
                    
                    # Convert stereo to mono if necessary
                    if default_speakers["maxInputChannels"] > 1:
                        # numpy reshape down to channels, then average
                        audio_data_int16 = audio_data_int16.reshape(-1, default_speakers["maxInputChannels"]).mean(axis=1).astype(np.int16)
                    
                    # We might need to resample if defaultSampleRate != self.sample_rate, 
                    # but for now we append. The APIs typically accept the native rate 
                    # as long as we tell them what it is. Or we can just pretend it's 16k 
                    # for testing, but let's record the *actual* rate.
                    
                    buffer.extend(audio_data_int16.tolist())
                    
                    # We will output chunks based on the device's actual sample rate
                    actual_frames_per_chunk = int(default_speakers["defaultSampleRate"] * self.chunk_duration)
                    
                    if len(buffer) >= actual_frames_per_chunk:
                        chunk_to_process = np.array(buffer[:actual_frames_per_chunk], dtype=np.int16)
                        # send a tuple so app.py knows the actual sample rate
                        self.audio_queue.put((chunk_to_process, int(default_speakers["defaultSampleRate"])))
                        buffer = buffer[actual_frames_per_chunk:]
                        
                stream.stop_stream()
                stream.close()
                
        except Exception as e:
            print(f"Error recording audio: {e}")
            self.is_recording = False

