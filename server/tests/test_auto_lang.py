import os
import asyncio
from dotenv import load_dotenv
import riva.client
import edge_tts

load_dotenv()
key = os.getenv("NVIDIA_API_KEY")

async def main():
    # 1. Generate Japanese audio
    text = "こんにちは、世界！" # Hello, world!
    communicate = edge_tts.Communicate(text, "ja-JP-NanamiNeural")
    await communicate.save("test_ja.wav") # wait, edge_tts saves as mp3 by default? No, wait. We need linear PCM.
    
    # We should use python wave to convert or use ffmpeg.
    os.system("ffmpeg -y -i test_ja.wav -ar 16000 -ac 1 -f wav test_ja_16k.wav")

    # 2. Call Riva
    auth = riva.client.Auth(
        None, use_ssl=True, uri="grpc.nvcf.nvidia.com:443",
        metadata_args=[
            ("authorization", f"Bearer {key}"),
            ("function-id", "71203149-d3b7-4460-8231-1be2543a1fca"), 
        ],
    )
    asr_service = riva.client.ASRService(auth)
    
    with open("test_ja_16k.wav", "rb") as f:
        audio_bytes = f.read()
        
    # Skip wav header
    import wave
    with wave.open("test_ja_16k.wav", "rb") as wf:
        audio_bytes = wf.readframes(wf.getnframes())

    config = riva.client.RecognitionConfig(
        encoding=riva.client.AudioEncoding.LINEAR_PCM,
        sample_rate_hertz=16000,
        language_code="en-US", # Test if it auto-detects despite en-US
        max_alternatives=1,
        enable_automatic_punctuation=True,
        audio_channel_count=1,
    )
    
    try:
        response = asr_service.offline_recognize(audio_bytes, config)
        if response and response.results:
            print("Transcript:", response.results[0].alternatives[0].transcript)
        else:
            print("No transcript returned.")
    except Exception as e:
        print("Error:", e)

if __name__ == "__main__":
    asyncio.run(main())
