import pytest
from unittest.mock import MagicMock, patch
from src.pipeline import InferenceOrchestrator

@pytest.fixture
def orchestrator():
    # Patch all model classes in src.network.orchestrator to avoid real init/loads
    with patch("src.pipeline.orchestrator.RivaASRModel"), \
         patch("src.pipeline.orchestrator.RivaNMTModel"), \
         patch("src.pipeline.orchestrator.LlamaModel"), \
         patch("src.pipeline.orchestrator.GoogleModel"), \
         patch("src.pipeline.orchestrator.GoogleCloudTranslationModel"), \
         patch("src.pipeline.orchestrator.MyMemoryModel"), \
         patch("src.pipeline.orchestrator.SpeechRecognitionModel"), \
         patch("src.pipeline.orchestrator.WhisperModel"):
        
        orch = InferenceOrchestrator(nvidia_api_key="mock_nv_key", google_credentials_json="{}")
        return orch

def test_orchestrator_initial_state(orchestrator):
    assert not orchestrator.is_running
    assert orchestrator.asr_dispatcher is not None
    assert orchestrator.translation_dispatcher is not None

def test_orchestrator_start_stop_stream(orchestrator):
    # 1. Start stream
    orchestrator.start_stream(sample_rate=16000, source_lang="en", target_lang="hi", ai_engine="google")
    
    assert orchestrator.is_running
    assert orchestrator.asr_dispatcher.source_lang == "en"
    assert orchestrator.translation_dispatcher.target_lang == "hi"
    
    # 2. Stop stream
    orchestrator.stop_stream()
    assert not orchestrator.is_running

def test_orchestrator_api_key_update(orchestrator):
    # Update API keys
    orchestrator.set_api_keys(nvidia_key="new_nv_key", google_credentials_json="{}")
    
    # Verify reload called on models
    orchestrator.riva_asr.reload.assert_called_with("new_nv_key")
    orchestrator.riva_nmt.reload.assert_called_with("new_nv_key")
    orchestrator.google_api.reload.assert_called_with("{}")
