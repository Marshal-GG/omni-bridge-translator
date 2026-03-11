"""
NVIDIA Llama 3.1 8B translation model via NVIDIA NIM.
Used either directly when 'llama' engine is selected or as a
reliable fallback from other engines.
"""

import time
import re
from openai import OpenAI


class LlamaModel:
    """Wraps the Llama 3.1 8B Instruct endpoint served through NVIDIA NIM."""

    MODEL_ID = "meta/llama-3.1-8b-instruct"

    def __init__(self, api_key: str):
        self.api_key = api_key
        self.client = None
        self._setup()

    # ── Setup ────────────────────────────────────────────────────────────────

    def _setup(self):
        try:
            if not self.api_key:
                return
            self.client = OpenAI(
                base_url="https://integrate.api.nvidia.com/v1",
                api_key=self.api_key,
            )
        except Exception as e:
            print(f"Llama setup failed: {e}")

    def reload(self, api_key: str):
        self.api_key = api_key
        self._setup()

    def is_ready(self) -> bool:
        return self.client is not None and bool(self.api_key)

    # ── Translation ──────────────────────────────────────────────────────────

    def translate(self, text: str, target_lang: str) -> tuple[str, dict]:
        """
        Translate *text* to *target_lang* using Llama 3.1 8B.
        Returns (translated_text, usage_stats).
        """
        start = time.monotonic()
        try:
            completion = self.client.chat.completions.create(
                model=self.MODEL_ID,
                messages=[
                    {
                        "role": "system",
                        "content": (
                            f"Translate to {target_lang}. "
                            "Output ONLY the translated text. "
                            "No explanations, no labels, no extra words."
                        ),
                    },
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
            stats = {
                "engine": "llama-translate",
                "model": self.MODEL_ID,
                "latency_ms": latency_ms,
                "api_prompt_tokens": usage.prompt_tokens if usage else 0,
                "api_completion_tokens": usage.completion_tokens if usage else 0,
                "input_tokens": len(text),
                "output_tokens": len(result),
            }
            return result, stats
        except Exception as e:
            print(f"Llama translation error: {e}")
            latency_ms = int((time.monotonic() - start) * 1000)
            return text, {
                "engine": "llama-translate",
                "model": self.MODEL_ID,
                "latency_ms": latency_ms,
                "error": str(e),
                "input_tokens": len(text),
            }
