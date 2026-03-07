import requests, os
from dotenv import load_dotenv

load_dotenv()
key = os.getenv('NVIDIA_API_KEY')
if not key:
    print("No key found")
    exit()

r = requests.get('https://api.nvcf.nvidia.com/v2/nvcf/functions', headers={'Authorization': f'Bearer {key}'})
if r.status_code == 200:
    functions = r.json().get('functions', [])
    with open('riva_functions.txt', 'w') as f:
        for func in functions:
            name = func.get('name', '').lower()
            if 'asr' in name or 'riva' in name or 'parakeet' in name or 'speech' in name:
                f.write(f"{func.get('name')} {func.get('id')} {func.get('description', '')}\n")
else:
    print(r.status_code, r.text)
