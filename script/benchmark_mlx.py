"""MFLUX comparison. This does not replace the app's working edit/RGBA backend."""
import json
import os
from pathlib import Path
import time
os.environ["HF_HOME"] = str(Path("work/hf-cache").resolve())
import mlx.core as mx
from mflux.models.qwen21.variants.txt2img.qwen_image_21 import QwenImage21

prompt = "A handmade ivory ceramic cup on a sandstone pedestal, soft morning light, elegant product photography, warm cream background, detailed ceramic texture."
print("Loading official Qwen-Image-2.1 weights for MLX", flush=True)
load_start = time.time()
model = QwenImage21(quantize=None)
mx.eval(model.parameters())
print("Model ready", time.time() - load_start, flush=True)
dest = Path("outputs/performance")
dest.mkdir(parents=True, exist_ok=True)
for size, steps in [(512,10),(1024,40)]:
    mx.reset_peak_memory()
    start = time.time()
    result = model.generate_image(seed=42, prompt=prompt, num_inference_steps=steps, width=size, height=size)
    elapsed = time.time() - start
    name = f"mlx-bf16-{size}-{steps}"
    result.save(str(dest / (name + ".png")))
    record = {"name":name, "runtime":"MFLUX MLX", "mflux_commit":"8c00dab2505a96019df9d30bc9c223bf20d733c4",
              "size":size, "steps":steps, "seed":42,"elapsed_seconds":elapsed,"mlx_peak_bytes":mx.get_peak_memory(),
              "hardware":"Mac Studio M3 Ultra 80 GPU cores 512 GiB", "prompt":prompt,
              "limits":"RGB text-to-image only; different PRNG/scheduler implementation. No image-quality equivalence claim."}
    (dest / (name + ".json")).write_text(json.dumps(record, indent=2))
    print(json.dumps(record), flush=True)
