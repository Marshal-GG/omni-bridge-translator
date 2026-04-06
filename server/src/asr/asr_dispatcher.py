import logging
import time
import numpy as np
import pysbd
from typing import Any, Dict, Optional, Tuple

from src.models.asr.riva_asr import RivaASRModel
from src.models.asr.whisper_asr import WhisperModel
from src.models.asr.local_asr import SpeechRecognitionModel

class ASRDispatcher:
    """
    Handles ASR model selection and audio chunk processing.
    """
    def __init__(
        self,
        riva: RivaASRModel,
        whisper: WhisperModel,
        google_free: SpeechRecognitionModel,
        sample_rate: int = 16000
    ):
        self.riva = riva
        self.whisper = whisper
        self.google_free = google_free
        self.sample_rate = sample_rate
        
        self.transcription_model = "online"
        self.source_lang = "auto"
        
        self.seg = pysbd.Segmenter(language="en", clean=False)
        self._last_transcript: Optional[str] = None
        self._last_transcript_time: float = 0.0
        self._DEDUP_WINDOW_S = 6.0
        self._ASR_RMS_THRESHOLD = 120

    def process_chunk(self, chunk: Any, config: Any) -> Optional[Dict[str, Any]]:
        """
        Process a single audio chunk and return transcription data if successful.
        chunk can be bytes or np.ndarray.
        """
        # Convert bytes to numpy if needed
        if isinstance(chunk, bytes):
            audio_array = np.frombuffer(chunk, dtype=np.int16)
        else:
            audio_array = chunk

        if audio_array.size == 0:
            return None

        chunk_rms = int(np.sqrt(np.mean(audio_array.astype(np.float32) ** 2)))
        if chunk_rms < self._ASR_RMS_THRESHOLD:
            return None

        transcript, asr_stats = self._perform_asr(audio_array, config)

        if transcript:
            cleaned = self._clean_stutters(transcript)
            now = time.monotonic()

            if cleaned == self._last_transcript and (now - self._last_transcript_time) < self._DEDUP_WINDOW_S:
                logging.debug(f"[ASRDispatcher] Duplicate suppressed: {cleaned!r}")
                return None
            
            self._last_transcript = cleaned
            self._last_transcript_time = now

            return {
                "text": cleaned,
                "asr_stats": asr_stats,
                "created_at": time.time()
            }
        return None

    def _perform_asr(self, chunk: np.ndarray, config: Any) -> Tuple[Optional[str], Optional[Dict]]:
        """Dispatcher for different ASR models."""
        model = self.transcription_model
        audio_bytes = chunk.tobytes()
        try:
            if model == "riva-asr":
                return self.riva.transcribe(audio_bytes, config)
            
            if model.startswith("whisper"):
                return self.whisper.transcribe(audio_bytes, self.sample_rate, self.source_lang)

            # Default: Local/Google Online via SpeechRecognition
            return self.google_free.transcribe(audio_bytes, self.sample_rate, self.source_lang)
        except Exception as e:
            logging.error(f"[ASRDispatcher] ASR Error ({model}): {e}")
            return None, None

    def _clean_stutters(self, text: str) -> str:
        """Simple word-level and sentence-level deduplication."""
        if not text: return ""
        
        # Word deduplication
        words = text.split()
        cleaned_words = []
        for w in words:
            if len(cleaned_words) >= 2 and cleaned_words[-1] == w and cleaned_words[-2] == w:
                continue
            cleaned_words.append(w)
        
        deduped_text = " ".join(cleaned_words)
        
        # Sentence segmentation and simple cleaning
        try:
            sentences = self.seg.segment(deduped_text)
            return " ".join(sentences)
        except:
            return deduped_text

