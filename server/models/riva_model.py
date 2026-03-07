"""
NVIDIA Riva ASR + Translation model.
Handles speech recognition via Riva and translation via the
Riva Translate or Llama fallback (both served through NVIDIA NIM).
"""

import re
import time
import riva.client
from openai import OpenAI

# Languages natively supported by the Riva Translate model.
RIVA_SUPPORTED_LANGS = {"en", "de", "es", "fr", "pt", "ru", "zh", "ja", "ko", "ar"}


class RivaModel:
    """Wraps NVIDIA Riva ASR and the Riva/Llama translation endpoint."""

    def __init__(self, api_key: str):
        self.api_key = api_key
        self.asr_service = None
        self.translate_client = None
        self._setup()

    # ── Setup ────────────────────────────────────────────────────────────────

    def _setup(self):
        try:
            if not self.api_key:
                return
            
            # Parakeet Multilingual (supports en-US, hi-IN, bn-IN, and 'multi' / 'auto')
            auth_parakeet = riva.client.Auth(
                None,
                use_ssl=True,
                uri="grpc.nvcf.nvidia.com:443",
                metadata_args=[
                    ("authorization", f"Bearer {self.api_key}"),
                    ("function-id", "71203149-d3b7-4460-8231-1be2543a1fca"),
                ],
            )
            self.asr_parakeet = riva.client.ASRService(auth_parakeet)

            # Canary (supports everything else: es, fr, de, zh, ja, ko, ru, pt, it, ar, nl, tr, vi, pl, id, th)
            auth_canary = riva.client.Auth(
                None,
                use_ssl=True,
                uri="grpc.nvcf.nvidia.com:443",
                metadata_args=[
                    ("authorization", f"Bearer {self.api_key}"),
                    ("function-id", "b0e8b4a5-217c-40b7-9b96-17d84e666317"),
                ],
            )
            self.asr_canary = riva.client.ASRService(auth_canary)

            self.translate_client = OpenAI(
                base_url="https://integrate.api.nvidia.com/v1",
                api_key=self.api_key,
            )
        except Exception as e:
            print(f"Riva setup failed: {e}")

    def reload(self, api_key: str):
        self.api_key = api_key
        self._setup()

    def is_ready(self) -> bool:
        return getattr(self, "asr_parakeet", None) is not None and bool(self.api_key)

    # ── ASR ──────────────────────────────────────────────────────────────────

    def transcribe(self, audio_bytes: bytes, config) -> tuple[str | None, dict | None]:
        """Run offline ASR and return the transcript, or None if empty."""
        import time
        start = time.monotonic()
        
        # Route to the appropriate model function ID
        lang = config.language_code
        if lang in ("multi", "bn-IN", "hi-IN", "en-US"):
            service = getattr(self, "asr_parakeet", None)
            model_name = "riva-parakeet"
        else:
            service = getattr(self, "asr_canary", None)
            model_name = "riva-canary"

        if not service:
            return None, None

        response = service.offline_recognize(audio_bytes, config)
        transcript = None
        if response and response.results and response.results[0].alternatives:
            transcript = response.results[0].alternatives[0].transcript.strip() or None
            
        stats = None
        if transcript:
            stats = {
                "engine": "riva-asr",
                "model": model_name,
                "latency_ms": int((time.monotonic() - start) * 1000),
                "input_chars": len(transcript),
                "output_chars": 0,
            }
        return transcript, stats

    def make_asr_config(self, sample_rate: int, lang: str):
        return riva.client.RecognitionConfig(
            encoding=riva.client.AudioEncoding.LINEAR_PCM,
            sample_rate_hertz=sample_rate,
            language_code=lang,
            max_alternatives=1,
            enable_automatic_punctuation=True,
            audio_channel_count=1,
        )

    # ── Translation ──────────────────────────────────────────────────────────

    def translate(self, text: str, source_lang: str, target_lang: str) -> tuple[str, dict]:
        """Translate using Riva Translate model, or Llama if unsupported langs.
        Returns (translated_text, usage_stats).
        """
        if (
            source_lang == "auto"
            or source_lang not in RIVA_SUPPORTED_LANGS
            or target_lang not in RIVA_SUPPORTED_LANGS
        ):
            model_name = "meta/llama-3.1-8b-instruct"
            system_prompt = (
                f"Translate to {target_lang}. "
                "Output ONLY the translated sentence. "
                "Do NOT add any explanation, commentary, punctuation changes, or prefix. "
                "Never say 'Here is', 'Translation:', or anything similar. "
                "Respond with the translated text and nothing else."
            )
        else:
            model_name = "nvidia/riva-translate-4b-instruct-v1.1"
            system_prompt = (
                f"Translate from {source_lang} to {target_lang}. "
                "Output only the translated text with no labels, no explanations, no extra words."
            )

        start = time.monotonic()
        completion = self.translate_client.chat.completions.create(
            model=model_name,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": text},
            ],
            temperature=0,
            max_tokens=512,
        )
        latency_ms = int((time.monotonic() - start) * 1000)
        usage = completion.usage
        result = completion.choices[0].message.content.strip()
        # Strip common model preamble artifacts
        result = re.sub(
            r'^(translation[:\s]+|translated text[:\s]+|here is.*?:|output[:\s]+|prompt[:\s]+|notes[:\s]+|p[:\s]+|in [a-z]+[:\s]+|sure[!,\s]+)',
            "",
            result,
            flags=re.IGNORECASE,
        ).strip()
        if result.startswith('"') and result.endswith('"'):
            result = result[1:-1].strip()

        stats = {
            "engine": "riva-translate",
            "model": model_name,
            "latency_ms": latency_ms,
            "prompt_tokens": usage.prompt_tokens if usage else 0,
            "completion_tokens": usage.completion_tokens if usage else 0,
            "total_tokens": usage.total_tokens if usage else 0,
            "input_chars": len(text),
            "output_chars": len(result),
        }
        return result, stats
