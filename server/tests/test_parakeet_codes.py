import sys, os
from dotenv import load_dotenv
import riva.client

sys.path.append(os.path.dirname(__file__))
from models.riva_model import RivaModel

load_dotenv()
key = os.getenv("NVIDIA_API_KEY")

class TestRiva(RivaModel):
    def _setup(self):
        try:
            if not self.api_key: return
            auth = riva.client.Auth(
                None, use_ssl=True, uri="grpc.nvcf.nvidia.com:443",
                metadata_args=[
                    ("authorization", f"Bearer {self.api_key}"),
                    ("function-id", "71203149-d3b7-4460-8231-1be2543a1fca"), # parakeet multilingual
                ],
            )
            self.asr_service = riva.client.ASRService(auth)
        except Exception as e:
            pass

riva_parakeet = TestRiva(key)

import struct, random
audio_bytes = struct.pack('<' + 'h' * 16000, *[random.randint(-1000, 1000) for _ in range(16000)])

test_langs = [
    "en-US", "en-GB", "en",
    "ja-JP", "ja",
    "es-US", "es-ES", "es",
    "fr-FR", "fr",
    "ko-KR", "ko"
]

print("Testing Parakeet RNNT Multilingual (71203149-d3b7-4460-8231-1be2543a1fca)...")
for lang in test_langs:
    config = riva_parakeet.make_asr_config(16000, lang)
    try:
        riva_parakeet.transcribe(audio_bytes, config)
        print(f"✅ {lang} is valid")
    except Exception as e:
        err = str(e).split('details = "')[1].split('"')[0] if 'details = "' in str(e) else str(e)
        print(f"❌ {lang} is invalid: {err.strip()}")
