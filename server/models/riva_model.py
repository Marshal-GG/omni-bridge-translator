"""
NVIDIA Riva ASR + Translation model.
Handles speech recognition via Riva and translation via the
Riva Translate or Llama fallback (both served through NVIDIA NIM).
"""

import re
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
            auth = riva.client.Auth(
                None,
                use_ssl=True,
                uri="grpc.nvcf.nvidia.com:443",
                metadata_args=[
                    ("authorization", f"Bearer {self.api_key}"),
                    ("function-id", "71203149-d3b7-4460-8231-1be2543a1fca"),
                ],
            )
            self.asr_service = riva.client.ASRService(auth)
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
        return self.asr_service is not None and bool(self.api_key)

    # ── ASR ──────────────────────────────────────────────────────────────────

    def transcribe(self, audio_bytes: bytes, config) -> str | None:
        """Run offline ASR and return the transcript, or None if empty."""
        response = self.asr_service.offline_recognize(audio_bytes, config)
        if response and response.results and response.results[0].alternatives:
            return response.results[0].alternatives[0].transcript.strip() or None
        return None

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

    def translate(self, text: str, source_lang: str, target_lang: str) -> str:
        """Translate using Riva Translate model, or Llama if unsupported langs."""
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

        completion = self.translate_client.chat.completions.create(
            model=model_name,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": text},
            ],
            temperature=0,
            max_tokens=512,
        )
        result = completion.choices[0].message.content.strip()
        # Strip common model preamble artifacts
        result = re.sub(
            r'^(translation[:\s]+|translated text[:\s]+|here is.*?:|output[:\s]+|in [a-z]+[:\s]+|sure[!,\s]+)',
            "",
            result,
            flags=re.IGNORECASE,
        ).strip()
        if result.startswith('"') and result.endswith('"'):
            result = result[1:-1].strip()
        return result
