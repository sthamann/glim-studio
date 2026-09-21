"""Run real local inference; store measurements, never infer another Mac's speed."""
import argparse
import ctypes
import json
from pathlib import Path
import time
import subprocess
import urllib.request
import uuid

parser = argparse.ArgumentParser()
parser.add_argument("--port", default=18921, type=int)
parser.add_argument("--size", default=512, type=int)
parser.add_argument("--steps", default=10, type=int)
parser.add_argument("--precision", default="bf16", choices=["bf16", "int8_convrot"])
parser.add_argument("--name", required=True)
parser.add_argument("--reference")
parser.add_argument("--transparent", action="store_true")
parser.add_argument("--seed", type=int, default=42)
parser.add_argument("--prompt")
parser.add_argument("--easy-cache", action="store_true")
parser.add_argument("--memory-log", type=Path, default=Path.home() / "Library/Application Support/Lichtbild Studio/runtime/memory.jsonl")
args = parser.parse_args()
base = f"http://127.0.0.1:{args.port}"
def call(path, body=None):
    request = urllib.request.Request(base + path, data=json.dumps(body).encode() if body is not None else None,
                                     headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.load(response)

prompt = "A handmade ivory ceramic cup on a sandstone pedestal, soft morning light, elegant product photography, warm cream background, detailed ceramic texture."
if args.transparent:
    prompt = "This is an RGBA image with transparency. A charming little orange fox reading a book, hand-drawn sticker illustration. The image has alpha channel and the background is transparent."
if args.reference:
    prompt = "Change the ceramic cup to deep cobalt blue. Keep the shape, pedestal, lighting and composition unchanged."
if args.prompt:
    prompt = args.prompt
graph = {
 "1": {"class_type": "UNETLoader", "inputs": {"unet_name": f"qwen_image_2.1_{args.precision}.safetensors", "weight_dtype": "default"}},
 "2": {"class_type": "CLIPLoader", "inputs": {"clip_name": f"qwen3vl_8b_{args.precision}.safetensors", "type": "qwen_image", "device": "default"}},
 "3": {"class_type": "VAELoader", "inputs": {"vae_name": "qwen_image_2.1_vae_bf16.safetensors"}},
 "4": {"class_type": "TextEncodeQwenImage21", "inputs": {"clip": ["2",0], "prompt": prompt, "negative_prompt": "", "resolution": args.size}},
 "5": {"class_type": "EmptyLatentImage", "inputs": {"width": args.size, "height": args.size, "batch_size": 1}},
 "6": {"class_type": "KSampler", "inputs": {"model": ["1",0], "positive": ["4",0], "negative": ["4",1], "latent_image": ["5",0], "seed": args.seed, "steps": args.steps, "cfg": 1, "sampler_name": "euler", "scheduler": "simple", "denoise": 1}},
 "7": {"class_type": "VAEDecode", "inputs": {"samples": ["6",0], "vae": ["3",0]}},
 "8": {"class_type": "SaveImage", "inputs": {"images": ["7",0], "filename_prefix": "benchmark_" + args.name}},
}
if args.reference:
    graph["20"] = {"class_type": "LoadImage", "inputs": {"image": args.reference}}
    graph["4"]["inputs"].update({"images.image_1": ["20",0], "vae": ["3",0]})
    graph["6"]["inputs"]["latent_image"] = ["4",2]
if args.easy_cache:
    graph["30"] = {"class_type": "EasyCache", "inputs": {"model": ["1",0], "reuse_threshold": 0.2, "start_percent": 0.15, "end_percent": 0.95, "verbose": False}}
    graph["6"]["inputs"]["model"] = ["30",0]
start = time.time()
job = call("/prompt", {"prompt": graph, "client_id": str(uuid.uuid4())})
print("Submitted", job, flush=True)
job_id = job["prompt_id"]
while time.time() - start < 1800:
    history = call("/history/" + job_id)
    if job_id in history:
        record = history[job_id]
        elapsed = time.time() - start
        memory = args.memory_log
        samples = [json.loads(line) for line in memory.read_text().splitlines()] if memory.exists() else []
        samples = [s for s in samples if start <= s["time"] <= time.time()]
        result = {"name": args.name, "started_at": start, "elapsed_seconds": elapsed, "size": args.size,
                  "steps": args.steps, "precision": args.precision,
                  "hardware": subprocess.check_output(["sysctl", "-n", "machdep.cpu.brand_string"], text=True).strip(),
                  "physical_memory_bytes": int(subprocess.check_output(["sysctl", "-n", "hw.memsize"])),
                  "status": record.get("status"), "outputs": record.get("outputs"), "prompt": prompt,
                  "peak": {key: max((s[key] for s in samples), default=None) for key in ["rss_bytes", "mps_allocated_bytes", "mps_driver_bytes"]}}
        # Kernel physical footprint includes compressed private pages, unlike RSS.
        # Lifetime peak is labeled explicitly: on warm runs it includes earlier runs.
        pid = int(subprocess.check_output(["lsof", "-ti", f"tcp:{args.port}", "-sTCP:LISTEN"]).strip())
        class Usage(ctypes.Structure):
            _fields_ = [("uuid", ctypes.c_ubyte * 16), ("values", ctypes.c_uint64 * 35)]
        usage = Usage()
        if ctypes.CDLL("/usr/lib/libproc.dylib").proc_pid_rusage(pid, 4, ctypes.byref(usage)) == 0:
            result["physical_footprint_bytes_at_finish"] = usage.values[7]
            result["process_lifetime_peak_physical_footprint_bytes"] = usage.values[28]
        result["seed"] = args.seed
        result["easy_cache"] = args.easy_cache
        result["graph"] = graph
        dest = Path("outputs/performance")
        dest.mkdir(parents=True, exist_ok=True)
        (dest / (args.name + ".json")).write_text(json.dumps(result, indent=2))
        if record.get("status", {}).get("status_str") != "success":
            raise RuntimeError("Generation failed; see recorded status")
        from urllib.parse import urlencode
        output = record["outputs"]["8"]["images"][0]
        with urllib.request.urlopen(base + "/view?" + urlencode(output), timeout=60) as image:
            (dest / (args.name + ".png")).write_bytes(image.read())
        print(json.dumps(result, indent=2), flush=True)
        break
    time.sleep(1)
else:
    call("/interrupt", {})
    raise TimeoutError("Benchmark exceeded 30 minutes")
