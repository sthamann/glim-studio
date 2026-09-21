"""Experimental MLX q4 probe, NOT the production engine or a MacBook simulator.

Run conversion on a large Mac first; then probe the saved checkpoint in a fresh
process. A sampled physical-footprint watchdog is independent of MLX's SOFT
allocator guideline. Neither emulates bandwidth, thermals, nor OS contention.
Requires the pinned MFLUX environment documented in docs/performance.md.
"""
import argparse
import ctypes
import json
import os
from pathlib import Path
import subprocess
import threading
import time

p = argparse.ArgumentParser()
p.add_argument("--convert", action="store_true")
p.add_argument("--checkpoint", default="work/qwen21-mlx-q4")
p.add_argument("--name", required=True)
p.add_argument("--size", type=int, default=512)
p.add_argument("--steps", type=int, default=20)
p.add_argument("--release-between-phases", action="store_true")
p.add_argument("--tiled-decode", action="store_true")
p.add_argument("--sequential-load", action="store_true")
p.add_argument("--budget-gib", type=float, default=12)
p.add_argument("--prompt", default="A handmade ivory ceramic cup on a sandstone pedestal, soft morning light, elegant product photography, warm cream background, detailed ceramic texture.")
a = p.parse_args()
dest = Path("outputs/performance")
dest.mkdir(parents=True, exist_ok=True)
result_file = dest / (a.name + ".json")
record = dict(vars(a), status="running", phase="imports", started_at=time.time(),
              mflux_commit=subprocess.check_output(["git", "-C", "work/mflux", "rev-parse", "HEAD"], text=True).strip(),
              hardware=subprocess.check_output(["sysctl", "-n", "machdep.cpu.brand_string"], text=True).strip(),
              physical_memory_bytes=int(subprocess.check_output(["sysctl", "-n", "hw.memsize"])),
              limitation="Budget probe on this hardware, NOT validation on a small Mac. Text encoder q4 is experimental; upstream disables its quantization due to semantic degradation.")
class Usage(ctypes.Structure):
    _fields_ = [("uuid", ctypes.c_ubyte * 16), ("values", ctypes.c_uint64 * 35)]
libproc = ctypes.CDLL("/usr/lib/libproc.dylib")
stop = threading.Event()
def sample():
    usage = Usage()
    if libproc.proc_pid_rusage(os.getpid(), 4, ctypes.byref(usage)) != 0:
        raise RuntimeError("Physical-footprint measurement unavailable")
    return {"time": time.time(), "phase": record["phase"], "physical_footprint_bytes": usage.values[7],
            "lifetime_peak_physical_footprint_bytes": usage.values[28]}
def monitor():
    with (dest / (a.name + "-memory.jsonl")).open("w", buffering=1) as log:
        while not stop.is_set():
            s = sample()
            log.write(json.dumps(s) + "\n")
            # Conversion is deliberately excluded: an end-user download must
            # already be quantized. Fresh load/generation obey this watchdog.
            if not a.convert and s["lifetime_peak_physical_footprint_bytes"] > a.budget_gib * 2**30:
                record.update(status="budget_exceeded", memory=s, elapsed_seconds=time.time() - record["started_at"])
                result_file.write_text(json.dumps(record, indent=2))
                os._exit(42)
            stop.wait(0.1)
threading.Thread(target=monitor, daemon=True).start()
try:
    os.environ["HF_HOME"] = str(Path("work/hf-cache").resolve())
    os.environ["HF_HUB_OFFLINE"] = "1"
    import mlx.core as mx
    from mflux.models.qwen21.variants.txt2img.qwen_image_21 import QwenImage21
    from mflux.models.qwen21.weights.qwen21_weight_definition import Qwen21WeightDefinition
    original_components = Qwen21WeightDefinition.get_components
    def components():
        items = original_components()
        for item in items:
            if item.name == "text_encoder":
                item.skip_quantization = False
        return items
    Qwen21WeightDefinition.get_components = staticmethod(components)
    if a.sequential_load:
        if a.convert or not a.release_between_phases:
            raise ValueError("Sequential loading requires a saved checkpoint and phase release")
        from mflux.models.qwen21.qwen21_initializer import Qwen21Initializer
        from mflux.models.common.weights.loading.weight_applier import WeightApplier
        from mflux.models.qwen21.model.qwen21_text_encoder.qwen21_text_encoder import Qwen21TextEncoder
        from mflux.models.qwen21.model.qwen21_transformer.qwen21_transformer import Qwen21Transformer
        from mflux.models.qwen21.model.qwen21_vae.qwen21_vae import Qwen21VAE
        def load_component(name):
            classes = {"text_encoder": Qwen21TextEncoder, "transformer": Qwen21Transformer, "vae": Qwen21VAE}
            Qwen21WeightDefinition.get_components = staticmethod(lambda: [c for c in components() if c.name == name])
            try:
                weights = Qwen21Initializer._load_weights(a.checkpoint)
                part = classes[name]()
                WeightApplier.apply_and_quantize(weights=weights, models={name: part}, quantize_arg=4, weight_definition=Qwen21WeightDefinition)
                mx.eval(part.parameters())
                return part
            finally:
                Qwen21WeightDefinition.get_components = staticmethod(components)
        def init_sequential(model, quantize, model_path, model_config):
            Qwen21Initializer._init_config(model, model_config)
            Qwen21Initializer._init_tokenizers(model, model_path)
            model.vae = None
            model.transformer = None
            model.text_encoder = load_component("text_encoder")
            model.bits = 4
        Qwen21Initializer.init = staticmethod(init_sequential)
    mx.set_cache_limit(128 * 2**20)
    mx.set_memory_limit(int(a.budget_gib * 2**30))  # guideline, NOT a hard cap
    record["phase"] = "convert" if a.convert else "load"
    start = time.monotonic()
    model = QwenImage21(quantize=4, model_path=None if a.convert else a.checkpoint)
    mx.eval(model.parameters())
    mx.clear_cache()
    record["load_seconds"] = time.monotonic() - start
    record["loaded_memory"] = sample()
    print(json.dumps(record), flush=True)
    if a.tiled_decode:
        from mflux.models.common.vae.tiling_config import TilingConfig
        model.tiling_config = TilingConfig(vae_decode_tiles_per_dim=2, vae_decode_tile_size=256, vae_decode_overlap=4)
    if a.release_between_phases and not a.convert:
        # One image per fresh process for this probe. Release weights only after
        # evaluating the arrays which depend on them; this is not a warm server.
        import gc
        from mflux.models.qwen21.model.qwen21_text_encoder.qwen21_prompt_encoder import Qwen21PromptEncoder
        from mflux.models.common.vae.vae_util import VAEUtil
        original_encode = Qwen21PromptEncoder.encode_prompt
        def encode(**kwargs):
            record["phase"] = "encode_prompt"
            encoded = original_encode(**kwargs)
            mx.eval(encoded)
            model.text_encoder = None
            kwargs.clear()
            gc.collect()
            mx.clear_cache()
            record["phase"] = "denoise"
            if a.sequential_load:
                model.transformer = load_component("transformer")
            return encoded
        Qwen21PromptEncoder.encode_prompt = staticmethod(encode)
        original_decode = VAEUtil.decode
        def decode(**kwargs):
            mx.eval(kwargs["latent"])
            model.transformer = None
            gc.collect()
            mx.clear_cache()
            record["phase"] = "decode"
            if a.sequential_load:
                model.vae = load_component("vae")
                kwargs["vae"] = model.vae
            return original_decode(**kwargs)
        VAEUtil.decode = staticmethod(decode)
    if a.convert:
        model.save_model(a.checkpoint)
        record["checkpoint_bytes"] = sum(f.stat().st_size for f in Path(a.checkpoint).rglob("*") if f.is_file())
    else:
        record["phase"] = "generate"
        start = time.monotonic()
        image = model.generate_image(seed=42, prompt=a.prompt, num_inference_steps=a.steps, width=a.size, height=a.size)
        image.save(str(dest / (a.name + ".png")))
        record["generation_seconds"] = time.monotonic() - start
    record.update(status="success", mlx_peak_bytes=mx.get_peak_memory(), memory=sample())
except Exception as error:
    record.update(status="error", error=repr(error), memory=sample())
    raise
finally:
    stop.set()
    record["elapsed_seconds"] = time.time() - record["started_at"]
    result_file.write_text(json.dumps(record, indent=2))
    print(json.dumps(record, indent=2), flush=True)
