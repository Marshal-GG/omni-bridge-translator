import os
import threading
import queue
import riva.client

class NimApiClient:
    def __init__(self, api_key):
        self.api_key = api_key
        self.uri = "grpc.nvcf.nvidia.com:443"
        self.is_running = False
        self.audio_queue = queue.Queue()
        self._setup_riva()

    def _setup_riva(self):
        try:
            if not self.api_key:
                return
            
            auth_asr = riva.client.Auth(
                None,
                use_ssl=True,
                uri=self.uri,
                metadata_args=[
                    ("authorization", f"Bearer {self.api_key}"),
                    ("function-id", "71203149-d3b7-4460-8231-1be2543a1fca")
                ]
            )
            self.asr_service = riva.client.ASRService(auth_asr)
            
            from openai import OpenAI
            self.translate_client = OpenAI(
                base_url="https://integrate.api.nvidia.com/v1",
                api_key=self.api_key
            )
        except Exception as e:
            print(f"Riva setup failed: {e}")

    def set_api_key(self, api_key):
        self.api_key = api_key
        self._setup_riva()

    def _clean_stutters(self, text):
        """Remove words repeated 3+ times consecutively (stutter removal)."""
        words = text.split()
        cleaned = []
        for w in words:
            if len(cleaned) >= 2 and cleaned[-1] == w and cleaned[-2] == w:
                continue
            cleaned.append(w)
        return " ".join(cleaned)

    def _translate_text(self, text, source_lang, target_lang):
        try:
            riva_supported = {"en", "de", "es", "fr", "pt", "ru", "zh", "ja", "ko", "ar"}

            if source_lang == "auto" or source_lang not in riva_supported or target_lang not in riva_supported:
                model_name = "meta/llama-3.1-8b-instruct"
                system_prompt = (
                    f"You are a live caption translator. Translate speech to {target_lang}. "
                    "Rules: output ONLY the translated text, no explanations, no labels, "
                    "no introductory text, no quotes. Just the translation itself."
                )
            else:
                model_name = "nvidia/riva-translate-4b-instruct-v1.1"
                system_prompt = (
                    f"Translate from {source_lang} to {target_lang}. "
                    "Output only the translated text. No labels or explanations."
                )

            completion = self.translate_client.chat.completions.create(
                model=model_name,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": text}
                ],
                temperature=0.1,
                max_tokens=512,
            )
            result = completion.choices[0].message.content.strip()
            import re
            result = re.sub(r'^(translation|translated text|here is.*?|output)[:\s]+', '', result, flags=re.IGNORECASE).strip()
            return result
        except Exception as e:
            print(f"Translation error ({e}), falling back to Llama...")
            try:
                completion = self.translate_client.chat.completions.create(
                    model="meta/llama-3.1-8b-instruct",
                    messages=[
                        {"role": "system", "content": f"You are a professional interpreter. Translate to {target_lang}. Output ONLY the translation."},
                        {"role": "user", "content": text}
                    ],
                    temperature=0.1,
                    max_tokens=512,
                )
                return completion.choices[0].message.content
            except Exception as e2:
                print(f"Fallback translation error: {e2}")
        return text

    def start_stream(self, sample_rate, source_lang="en", target_lang=None, callback=None):
        if not hasattr(self, 'asr_service') or not self.api_key:
            if callback:
                callback("Error: API Key or Riva setup is missing.", True, is_final=True)
            return

        if self.is_running:
            return

        self.is_running = True
        self._source_lang = source_lang
        self._target_lang = target_lang
        self._callback = callback
        self._sample_rate = sample_rate
        
        while not self.audio_queue.empty():
            try: self.audio_queue.get_nowait()
            except: break
        
        for _ in range(2):
            t = threading.Thread(target=self._worker, daemon=True)
            t.start()

    def stop_stream(self):
        self.is_running = False
        self.audio_queue.put(None)
        self.audio_queue.put(None)

    def append_audio(self, audio_data):
        if self.is_running:
            self.audio_queue.put(audio_data)

    def _worker(self):
        lang_map = {
            "en": "en-US", "es": "es-US", "fr": "fr-FR", "de": "de-DE",
            "zh": "zh-CN", "ja": "ja-JP", "ko": "ko-KR", "ru": "ru-RU",
            "pt": "pt-BR", "it": "it-IT", "ar": "ar-AR", "hi": "hi-IN",
            "nl": "nl-NL", "tr": "tr-TR", "vi": "vi-VN", "pl": "pl-PL",
            "id": "id-ID", "th": "th-TH", "bn": "bn-IN"
        }
        # "multi" is the correct Parakeet code for auto language detection
        asr_lang = lang_map.get(self._source_lang, "en-US") if self._source_lang != "auto" else "multi"
        config = riva.client.RecognitionConfig(
            encoding=riva.client.AudioEncoding.LINEAR_PCM,
            sample_rate_hertz=self._sample_rate,
            language_code=asr_lang,
            max_alternatives=1,
            enable_automatic_punctuation=True,
            audio_channel_count=1
        )

        while self.is_running:
            try:
                chunk = self.audio_queue.get(timeout=1.0)
                if chunk is None:
                    break

                response = self.asr_service.offline_recognize(chunk.tobytes(), config)

                if response and response.results and response.results[0].alternatives:
                    transcript = response.results[0].alternatives[0].transcript.strip()
                    if not transcript:
                        continue
                    
                    clean = self._clean_stutters(transcript)

                    if self._target_lang and self._target_lang != self._source_lang and self._target_lang != 'none':
                        translated = self._translate_text(clean, self._source_lang, self._target_lang)
                        if self._callback:
                            self._callback(translated, False, is_final=True, original_text=clean)
                    else:
                        if self._callback:
                            self._callback(clean, False, is_final=True)

            except queue.Empty:
                continue
            except Exception as e:
                if self._callback:
                    self._callback(f"ASR Error: {e}", True, is_final=True)
