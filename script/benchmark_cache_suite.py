"""Paired cache smoke tests using public/generic prompts only; not a quality score."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import urllib.request
import uuid

p = argparse.ArgumentParser()
p.add_argument("--port", type=int, required=True)
p.add_argument("--precision", default="int8_convrot")
p.add_argument("--steps", type=int, default=40)
a = p.parse_args()
base = [sys.executable, "script/benchmark.py", "--port", str(a.port), "--precision", a.precision, "--size", "512"]
cases = {
    "text": ["--prompt", 'A clean graphic poster with the exact large text "HELLO GLIM" centered on a solid navy background. Bold white sans serif letters. A small orange circle below.'],
    "portrait": ["--prompt", "A studio portrait of a fictional elderly woman with short silver hair, round glasses and a green knitted scarf, neutral background, natural skin texture, soft window light."],
    "rgba": ["--transparent"],
}
reference = Path("outputs/performance/cache-baseline-512.png")
boundary = uuid.uuid4().hex
body = (f'--{boundary}\r\nContent-Disposition: form-data; name="image"; filename="glim-cache-reference.png"\r\nContent-Type: image/png\r\n\r\n'.encode() + reference.read_bytes() + f"\r\n--{boundary}--\r\n".encode())
req = urllib.request.Request(f"http://127.0.0.1:{a.port}/upload/image", data=body, headers={"Content-Type": f"multipart/form-data; boundary={boundary}"})
with urllib.request.urlopen(req) as response:
    cases["edit"] = ["--reference", json.load(response)["name"]]
results = []
for name, options in cases.items():
    prefix = f"cache-suite-{a.precision}-{name}"
    subprocess.run(base + options + ["--steps", "1", "--name", prefix + "-warmup"], check=True, stdout=subprocess.DEVNULL)
    for cache in [False, True]:
        run = prefix + ("-fast" if cache else "-normal")
        subprocess.run(base + options + ["--steps", str(a.steps), "--name", run] + (["--easy-cache"] if cache else []), check=True, stdout=subprocess.DEVNULL)
        r = json.loads(Path(f"outputs/performance/{run}.json").read_text())
        results.append({"name": run, "seconds": r["elapsed_seconds"], "success": r["status"]["status_str"] == "success"})
        print(json.dumps(results[-1]), flush=True)
Path("outputs/performance/cache-suite-summary.json").write_text(json.dumps(results, indent=2))
