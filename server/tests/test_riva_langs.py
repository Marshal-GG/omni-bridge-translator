import sys, os
from dotenv import load_dotenv

sys.path.append(os.path.dirname(__file__))
from models.riva_model import RivaModel

load_dotenv()
key = os.getenv("NVIDIA_API_KEY")

lang_map = {
    "en": "en-US", "es": "es-US", "fr": "fr-FR", "de": "de-DE",
    "zh": "zh-CN", "ja": "ja-JP", "ko": "ko-KR", "ru": "ru-RU",
    "pt": "pt-BR", "it": "it-IT", "ar": "ar-AR", "hi": "hi-IN",
    "nl": "nl-NL", "tr": "tr-TR", "vi": "vi-VN", "pl": "pl-PL",
    "id": "id-ID", "th": "th-TH", "bn": "bn-IN",
}

riva = RivaModel(key)
if not riva.is_ready():
    print("Riva not ready")
    exit()

# create dummy 1 sec white noise audio at 16000Hz, 1 channel, 16 bit
import struct
import random
audio_bytes = struct.pack('<' + 'h' * 16000, *[random.randint(-1000, 1000) for _ in range(16000)])

valid_langs = []
for code, lang in lang_map.items():
    config = riva.make_asr_config(16000, lang)
    try:
        riva.transcribe(audio_bytes, config)
        print(f"{lang} is valid")
        valid_langs.append(lang)
    except Exception as e:
        print(f"{lang} is invalid: {str(e)[:100]}")

print("\nValid languages:", valid_langs)
