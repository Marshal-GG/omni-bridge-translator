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
        
        orch = InferenceOrchestrator(nvidia_api_key="mock_nv_key", google_credentials={})
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
    # Mock Thread to run synchronously for testing
    with patch("threading.Thread") as mock_thread:
        # Capture the target function and call it immediately
        def mock_start(target, *args, **kwargs):
            target()
        
        mock_instance = MagicMock()
        mock_instance.start.side_effect = lambda: orchestrator._reloader_lock.acquire() or (
            orchestrator.riva_asr.reload("new_nv_key", parakeet_fid="", canary_fid=""),
            orchestrator.riva_nmt.reload("new_nv_key", function_id=""),
            orchestrator.google_api.reload({}),
            orchestrator._reloader_lock.release()
        )
        # Actually, simpler to just mock the thread class to run to completion
        
        def run_sync(target, **kwargs):
            target()
            return MagicMock() # return a mock thread object
            
        mock_thread.side_effect = run_sync

        # Update API keys
        orchestrator.set_api_keys(nvidia_key="new_nv_key", google_credentials={})
        
        # Verify reload called on models with correct arguments
        orchestrator.riva_asr.reload.assert_called_with("new_nv_key", parakeet_fid="", canary_fid="")
        orchestrator.riva_nmt.reload.assert_called_with("new_nv_key", function_id="")
        orchestrator.google_api.reload.assert_called_with({})
