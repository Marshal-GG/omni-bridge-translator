"""
Google free online ASR via SpeechRecognition library.
Uses Google's undocumented web speech API — no key needed, requires internet.
"""

import io
import wave
import speech_recognition as sr


# BCP-47 language codes for recognize_google — must match nim_api's lang_map
_LANG_MAP = {
    "en": "en-US", "es": "es-ES", "fr": "fr-FR", "de": "de-DE",
    "zh": "zh-CN", "ja": "ja-JP", "ko": "ko-KR", "ru": "ru-RU",
    "pt": "pt-BR", "it": "it-IT", "ar": "ar-SA", "hi": "hi-IN",
    "nl": "nl-NL", "tr": "tr-TR", "vi": "vi-VN", "pl": "pl-PL",
    "id": "id-ID", "th": "th-TH", "bn": "bn-IN", "uk": "uk-UA",
    "sv": "sv-SE", "da": "da-DK", "fi": "fi-FI", "cs": "cs-CZ",
    "ro": "ro-RO", "el": "el-GR", "he": "iw-IL", "hu": "hu-HU",
}


class SpeechRecognitionModel:
    """Online ASR using Google's free web speech API."""

    def __init__(self):
        # Reuse a single Recognizer — avoid overhead of creating one per chunk
        self._recognizer = sr.Recognizer()
        # Relax energy threshold so silence gaps don't block recognition
        self._recognizer.dynamic_energy_threshold = False
        self._recognizer.energy_threshold = 300

    def is_ready(self) -> bool:
        return True

    def transcribe(
        self,
        audio_bytes: bytes,
        sample_rate: int,
        source_lang: str = "auto",
    ) -> tuple[str | None, dict | None]:
        """
        Transcribe raw PCM mono int16 audio to text.
        source_lang: ISO 639-1 code (e.g. 'en', 'hi') or 'auto' for auto-detect.
        Returns a tuple of (transcript_string, usage_stats_dict), or (None, None) if nothing was recognised.
        """
        if not audio_bytes:
            return None, None
        
        import time
        start = time.monotonic()

        try:
            # Wrap raw PCM in a WAV container
            wav_buf = io.BytesIO()
            with wave.open(wav_buf, "wb") as wf:
                wf.setnchannels(1)
                wf.setsampwidth(2)   # 16-bit PCM
                wf.setframerate(sample_rate)
                wf.writeframes(audio_bytes)
            wav_buf.seek(0)

            with sr.AudioFile(wav_buf) as source:
                audio = self._recognizer.record(source)

            # Google's recognize_google requires a string for language, so default to en-US for "auto"
            lang_tag = "en-US" if source_lang == "auto" else _LANG_MAP.get(source_lang, "en-US")
            result = self._recognizer.recognize_google(audio, language=lang_tag)
            transcript = result.strip() if result else None
            stats = None
            if transcript:
                latency_ms = int((time.monotonic() - start) * 1000)
                stats = {
                    "engine": "google-asr",
                    "model": "speech_recognition",
                    "latency_ms": latency_ms,
                    "input_tokens": len(transcript),
                    "output_tokens": 0,
                }
            return transcript, stats

        except sr.UnknownValueError:
            # No speech detected — not an error
            return None, None
        except sr.RequestError as e:
            print(f"[SpeechRecognition] Google API error: {e}")
            return None, None
        except Exception as e:
            print(f"[SpeechRecognition] Unexpected error: {e}")
            return None, None
