import re
with open("asr_error.log", "r") as f:
    text = f.read()
matches = re.findall(r"\[ASR ERROR\].*?StatusCode\.INVALID_ARGUMENT.*?(?=\[ASR ERROR\]|\Z)", text, re.DOTALL)
if matches:
    with open("extracted_err.txt", "w") as out:
        out.write(matches[-1])
