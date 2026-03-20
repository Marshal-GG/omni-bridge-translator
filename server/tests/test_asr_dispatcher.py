import pytest
import numpy as np
from unittest.mock import MagicMock, patch
from src.asr.asr_dispatcher import ASRDispatcher

def test_asr_dispatcher_silence_filtering():
    # Mock models
    riva = MagicMock()
    whisper = MagicMock()
    google = MagicMock()
    
    dispatcher = ASRDispatcher(riva, whisper, google, sample_rate=16000)
    
    # Silent audio (zeros)
    silent_chunk = np.zeros(1600, dtype=np.int16)
    
    # Process - should return None due to RMS threshold (120)
    result = dispatcher.process_chunk(silent_chunk, config=None)
    
    assert result is None
    riva.transcribe.assert_not_called()

def test_asr_dispatcher_routing_riva():
    riva = MagicMock()
    whisper = MagicMock()
    google = MagicMock()
    
    dispatcher = ASRDispatcher(riva, whisper, google, sample_rate=16000)
    dispatcher.transcription_model = "riva"
    
    # Mock transcribe result
    riva.transcribe.return_value = ("Hello world", {"model": "riva"})
    
    # Loud audio (sine wave)
    audio = (np.sin(np.linspace(0, 100, 1600)) * 10000).astype(np.int16)
    
    result = dispatcher.process_chunk(audio, config="mock_config")
    
    assert result["text"] == "Hello world"
    assert result["asr_stats"]["model"] == "riva"
    riva.transcribe.assert_called_once_with(audio.tobytes(), "mock_config")

def test_asr_dispatcher_deduplication():
    riva = MagicMock()
    whisper = MagicMock()
    google = MagicMock()
    
    dispatcher = ASRDispatcher(riva, whisper, google, sample_rate=16000)
    dispatcher.transcription_model = "riva"
    
    # Loud audio
    audio = (np.sin(np.linspace(0, 100, 1600)) * 10000).astype(np.int16)
    
    # First time
    riva.transcribe.return_value = ("Test repeat", {"model": "riva"})
    r1 = dispatcher.process_chunk(audio, config=None)
    assert r1["text"] == "Test repeat"
    
    # Second time same content (within window)
    r2 = dispatcher.process_chunk(audio, config=None)
    assert r2 is None
