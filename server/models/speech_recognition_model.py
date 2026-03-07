"""
Google free online ASR via SpeechRecognition library.
Uses Google's undocumented web speech API — no key needed, requires internet.
"""

import io
import wave
import speech_recognition as sr


class SpeechRecognitionModel:
    """Online ASR using Google's free web speech API."""

    def is_ready(self) -> bool:
        return True

    def transcribe(self, audio_bytes: bytes, sample_rate: int) -> str | None:
        """
        Transcribe raw PCM mono audio (int16) to text.
        Returns transcript string, or None if nothing was recognised.
        """
        try:
            recognizer = sr.Recognizer()

            # Wrap raw PCM in a WAV container so SpeechRecognition can read it
            wav_buf = io.BytesIO()
            with wave.open(wav_buf, "wb") as wf:
                wf.setnchannels(1)
                wf.setsampwidth(2)  # 16-bit
                wf.setframerate(sample_rate)
                wf.writeframes(audio_bytes)
            wav_buf.seek(0)

            with sr.AudioFile(wav_buf) as source:
                audio = recognizer.record(source)

            result = recognizer.recognize_google(audio)
            return result.strip() if result else None

        except sr.UnknownValueError:
            # No speech detected — not an error
            return None
        except sr.RequestError as e:
            print(f"[SpeechRecognition] Google API error: {e}")
            return None
        except Exception as e:
            print(f"[SpeechRecognition] Unexpected error: {e}")
            return None
