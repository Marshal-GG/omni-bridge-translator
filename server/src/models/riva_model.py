"""
NVIDIA Riva ASR + Translation model.
Handles speech recognition via Riva and translation via the
Riva Translate or Llama fallback (both served through NVIDIA NIM).
"""

import re
import time
import logging
import riva.client
from openai import OpenAI

# Languages natively supported by the Riva Translate model.
RIVA_SUPPORTED_LANGS = {"en", "de", "es", "fr", "pt", "ru", "zh", "ja", "ko", "ar"}


class RivaModel:
    """Wraps NVIDIA Riva ASR and the Riva/Llama translation endpoint."""

    def __init__(self, api_key: str):
        self.api_key = api_key
        self.asr_parakeet = None
        self.asr_canary = None
        self.nmt_client = None
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

            # Neural Machine Translation (NMT) via gRPC
            auth_nmt = riva.client.Auth(
                None,
                use_ssl=True,
                uri="grpc.nvcf.nvidia.com:443",
                metadata_args=[
                    ("authorization", f"Bearer {self.api_key}"),
                    ("function-id", "10f92bba-1512-429a-9e5c-7d3129486c12"),
                ],
            )
            self.nmt_client = riva.client.NeuralMachineTranslationService(auth_nmt)

            self.translate_client = OpenAI(
                base_url="https://integrate.api.nvidia.com/v1",
                api_key=self.api_key,
            )
        except Exception as e:
            import logging
            logging.error(f"Riva setup failed: {e}")

    def reload(self, api_key: str):
        self.api_key = api_key
        self._setup()

    def is_ready(self) -> bool:
        return getattr(self, "asr_parakeet", None) is not None and bool(self.api_key)

    def get_status(self) -> dict:
        """Return status for Riva models."""
        ready = self.is_ready()
        status = "ready" if ready else ("no_api_key" if not self.api_key else "error")
        message = "Riva is ready." if ready else ("Riva requires an API key." if not self.api_key else "Riva setup failed.")
        
        return {
            "name": "riva",
            "status": status,
            "ready": ready,
            "message": message,
            "progress": 100.0 if ready else 0.0,
            "details": {"has_key": bool(self.api_key)}
        }

    # ── ASR ──────────────────────────────────────────────────────────────────

    def transcribe(self, audio_bytes: bytes, config) -> tuple[str | None, dict | None]:
        """Run offline ASR and return the transcript, or None if empty."""
        import time
        start = time.monotonic()
        
        # Route to the appropriate model function ID
        parakeet_langs = {
            "en-US", "en-GB", "es-US", "es-ES", "de-DE", "fr-FR", "fr-CA", "it-IT", 
            "ar-AR", "ko-KR", "pt-BR", "pt-PT", "ru-RU", "hi-IN", "nl-NL", 
            "da-DK", "nn-NO", "nb-NO", "cs-CZ", "pl-PL", "sv-SE", "th-TH", "tr-TR", 
            "he-IL", "bn-IN", "multi"
        }
        
        lang = config.language_code
        if lang in parakeet_langs:
            service = getattr(self, "asr_parakeet", None)
            model_name = "riva-parakeet"
        else:
            service = getattr(self, "asr_canary", None)
            model_name = "riva-canary"

        if not service:
            return None, None

        try:
            response = service.offline_recognize(audio_bytes, config)
        except Exception as e:
            logging.warning(f"[RivaASR] offline_recognize failed ({model_name}, lang={lang}): {type(e).__name__}: {e}")
            return None, None

        transcript = None
        detected_lang = None
        if response and response.results:
            result = response.results[0]
            if result.alternatives:
                raw_transcript = result.alternatives[0].transcript.strip()
                # Extract detected language if available (usually in result.language_code for multi/canary)
                detected_lang = getattr(result, "language_code", None)
                
                # Filter out single-character hallucinations (like "P")
                if len(raw_transcript) > 1:
                    transcript = raw_transcript
                else:
                    return None, None
                
        stats = None
        if transcript:
            # Safely handle detected_lang which might be a gRPC object or lang-region code
            safe_lang = ""
            if detected_lang:
                safe_lang = str(detected_lang).split("-")[0].lower() # "ja-JP" -> "ja"

            stats = {
                "engine": "riva-asr",
                "model": model_name,
                "latency_ms": int((time.monotonic() - start) * 1000),
                "input_tokens": len(transcript),
                "output_tokens": 0,
                "detected_lang": safe_lang
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
        """Translate using Riva gRPC MT, or Llama fallback if unsupported.
        Returns (translated_text, usage_stats).
        """
        # 1. Decide on Source Language (handle auto)
        src = source_lang if source_lang != "auto" else "auto"
        # Riva Translate supports: en, de, es, fr, pt, ru, zh, ja, ko, ar
        is_riva_supported = (
            src in RIVA_SUPPORTED_LANGS
            and target_lang in RIVA_SUPPORTED_LANGS
        )

        start = time.monotonic()
        
        # 2. Try Riva gRPC (Preferred)
        if is_riva_supported and getattr(self, "nmt_client", None):
            try:
                response = self.nmt_client.translate(
                    [text],
                    target_language=target_lang,
                    source_language=src
                )
                result = response.translations[0].text.strip()
                latency_ms = int((time.monotonic() - start) * 1000)
                return result, {
                    "engine": "riva-grpc-mt",
                    "model": "nvidia/riva-translate-4b",
                    "latency_ms": latency_ms,
                    "input_tokens": len(text),
                    "output_tokens": len(result),
                }
            except Exception as e:
                logging.warning(f"[RivaMT] gRPC translate failed: {e}. Falling back to Llama...")

        # 3. Fallback to Llama (NIM REST)
        model_name = "meta/llama-3.1-8b-instruct"
        system_prompt = (
            f"You are a professional translator. Translate the following text into clear, natural {target_lang}. "
            "Output ONLY the translated text. Do NOT include any explanations, labels, notes, or original text. "
            "If you cannot translate it, return the original text as-is."
        )

        if not self.translate_client:
            return text, {"error": "Translate client not initialized"}
            
        try:
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
            if result.startswith('"') and result.endswith('"') and len(result) >= 2:
                result = str(result[1:-1]).strip()

            return result, {
                "engine": "llama-fallback",
                "model": model_name,
                "latency_ms": latency_ms,
                "api_prompt_tokens": usage.prompt_tokens if usage else 0,
                "api_completion_tokens": usage.completion_tokens if usage else 0,
                "input_tokens": len(text),
                "output_tokens": len(result),
            }
        except Exception as e:
            logging.error(f"[RivaMT] Llama fallback failed: {e}")
            return text, {"error": str(e)}
