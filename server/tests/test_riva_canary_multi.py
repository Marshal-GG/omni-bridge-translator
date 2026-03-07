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
                    ("function-id", "b0e8b4a5-217c-40b7-9b96-17d84e666317"), # canary
                ],
            )
            self.asr_service = riva.client.ASRService(auth)
        except Exception as e:
            pass

riva_canary = TestRiva(key)

import struct, random
audio_bytes = struct.pack('<' + 'h' * 16000, *[random.randint(-1000, 1000) for _ in range(16000)])

try:
    config = riva_canary.make_asr_config(16000, "multi")
    riva_canary.transcribe(audio_bytes, config)
    print("Canary supports 'multi'")
except Exception as e:
    print("Canary does NOT support 'multi':", str(e)[:100])
