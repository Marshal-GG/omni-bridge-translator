import os
from dotenv import load_dotenv
import riva.client

load_dotenv()
key = os.getenv("NVIDIA_API_KEY")

auth = riva.client.Auth(
    None, use_ssl=True, uri="grpc.nvcf.nvidia.com:443",
    metadata_args=[
        ("authorization", f"Bearer {key}"),
        # Use the Parakeet Multilingual function ID
        ("function-id", "71203149-d3b7-4460-8231-1be2543a1fca"), 
    ],
)
asr_service = riva.client.ASRService(auth)

import struct, random
audio_bytes = struct.pack('<' + 'h' * 16000, *[random.randint(-1000, 1000) for _ in range(16000)])

test_langs = [
    "en-US", "ja-JP", "es-US", "fr-FR", "de-DE", "zh-CN", "ru-RU", "ko-KR", "multi"
]

with open("parakeet_results.txt", "w", encoding="utf-8") as f:
    f.write("Testing pure Parakeet Multilingual endpoint:\n")
    for lang in test_langs:
        config = riva.client.RecognitionConfig(
            encoding=riva.client.AudioEncoding.LINEAR_PCM,
            sample_rate_hertz=16000,
            language_code=lang,
            max_alternatives=1,
            enable_automatic_punctuation=True,
            audio_channel_count=1,
        )
        try:
            asr_service.offline_recognize(audio_bytes, config)
            f.write(f"PASS: {lang} is supported\n")
        except Exception as e:
            err = str(e).split('details = "')[1].split('"')[0] if 'details = "' in str(e) else str(e)
            f.write(f"FAIL: {lang} failed: {err.strip()}\n")
