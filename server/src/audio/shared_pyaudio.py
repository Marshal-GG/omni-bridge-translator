import pyaudiowpatch as pyaudio
import threading

_pa_instance = None
_pa_lock = threading.Lock()

def get_pyaudio():
    global _pa_instance
    with _pa_lock:
        if _pa_instance is None:
            _pa_instance = pyaudio.PyAudio()
    return _pa_instance
