import pytest
from unittest.mock import MagicMock, patch
import os
import sys

# Ensure src is in the python path for imports
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

@pytest.fixture
def mock_riva_auth():
    with patch("riva.client.Auth") as mock:
        yield mock

@pytest.fixture
def mock_riva_asr(mock_riva_auth):
    with patch("riva.client.ASRService") as mock:
        service = mock.return_value
        # Mock reasonable default response
        mock_response = MagicMock()
        mock_result = MagicMock()
        mock_alt = MagicMock()
        mock_alt.transcript = "Test transcript"
        mock_alt.confidence = 0.99
        mock_result.alternatives = [mock_alt]
        mock_result.language_code = "en-US"
        mock_response.results = [mock_result]
        service.offline_recognize.return_value = mock_response
        yield service

@pytest.fixture
def mock_riva_nmt(mock_riva_auth):
    with patch("riva.client.NeuralMachineTranslationClient") as mock:
        client = mock.return_value
        # Mock reasonable default response
        mock_response = MagicMock()
        mock_trans = MagicMock()
        mock_trans.text = "Translated text"
        mock_response.translations = [mock_trans]
        client.translate.return_value = mock_response
        yield client

@pytest.fixture
def mock_llama():
    with patch("src.models.translation.llama_translation.LlamaModel") as mock:
        instance = mock.return_value
        instance.translate.return_value = ("Llama translation", {"engine": "llama"})
        yield instance

@pytest.fixture
def mock_whisper():
    with patch("src.models.asr.whisper_asr.WhisperASRModel") as mock:
        instance = mock.return_value
        instance.transcribe.return_value = ("Whisper transcript", {"engine": "whisper"})
        yield instance

@pytest.fixture
def mock_google_free():
    with patch("src.models.translation.google_translation.GoogleModel") as mock:
        instance = mock.return_value
        instance.translate.return_value = ("Google translation", {"engine": "google"})
        yield instance
