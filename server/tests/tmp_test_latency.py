import time
from deep_translator import GoogleTranslator, MyMemoryTranslator

def benchmark(name, translator_func, text):
    print(f"Testing {name} latency...")
    latencies = []
    for i in range(3):
        start = time.monotonic()
        result = translator_func(text)
        latency = (time.monotonic() - start) * 1000
        latencies.append(latency)
        print(f"  Run {i+1}: {latency:.2f}ms")
    avg = sum(latencies) / len(latencies)
    print(f"Average {name} Latency: {avg:.2f}ms\n")
    return avg

if __name__ == "__main__":
    text = "Hello, how are you today?"
    benchmark("Google", lambda t: GoogleTranslator(source='en', target='es').translate(t), text)
    benchmark("MyMemory", lambda t: MyMemoryTranslator(source='en', target='es').translate(t), text)
