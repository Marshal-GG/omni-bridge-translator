import pytest
from unittest.mock import MagicMock, patch
from src.translation.translation_dispatcher import TranslationDispatcher

@pytest.fixture
def dispatcher():
    # Setup mocks for all models
    riva_nmt = MagicMock()
    llama = MagicMock()
    google_api = MagicMock()
    google_free = MagicMock()
    mymemory = MagicMock()
    
    td = TranslationDispatcher(riva_nmt, llama, google_api, google_free, mymemory)
    td.target_lang = "en"
    return td

def test_translation_dispatcher_script_detection(dispatcher):
    # 1. Hindi (Devanagari)
    hindi_text = "नमस्ते दुनिया"
    lang = dispatcher._detect_lang_from_script(hindi_text)
    assert lang == "hi"
    
    # 2. Tamil
    tamil_text = "வணக்கம் உலகம்"
    lang = dispatcher._detect_lang_from_script(tamil_text)
    assert lang == "ta"
    
    # 3. Bengali
    bengali_text = "হ্যালো ওয়ার্ল্ড"
    lang = dispatcher._detect_lang_from_script(bengali_text)
    assert lang == "bn"
    
    # 4. English (should return None)
    english_text = "Hello world"
    lang = dispatcher._detect_lang_from_script(english_text)
    assert lang is None

def test_translation_dispatcher_riva_to_llama_fallback(dispatcher):
    # Setup Riva failure
    dispatcher.translation_model = "riva"
    dispatcher.source_lang = "hi"
    dispatcher.target_lang = "en"
    
    # Riva supports it but fails with exception
    dispatcher.riva_nmt.supports_translation_pair.return_value = True
    dispatcher.riva_nmt.translate.side_effect = Exception("Connection error")
    
    # Llama succeeds
    dispatcher.llama.translate.return_value = ("Llama fallback result", {"engine": "llama", "fallback_from": "riva"})
    
    result, stats = dispatcher.translate("नमस्ते")
    
    assert result == "Llama fallback result"
    assert stats["fallback_from"] == "riva"
    dispatcher.llama.translate.assert_called_once()

def test_translation_dispatcher_unsupported_pair_fallback(dispatcher):
    # Riva doesn't support hi -> fr (hypothetically)
    dispatcher.translation_model = "riva"
    dispatcher.source_lang = "hi"
    dispatcher.target_lang = "fr"
    
    dispatcher.riva_nmt.supports_translation_pair.return_value = False
    dispatcher.llama.translate.return_value = ("Llama result", {"engine": "llama"})
    
    result, stats = dispatcher.translate("नमस्ते")
    
    assert result == "Llama result"
    dispatcher.riva_nmt.translate.assert_not_called()
    dispatcher.llama.translate.assert_called_once()
