"""Private local runtime installer for Lichtbild Studio. No inference cloud calls."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import time
import urllib.request

ROOT = Path(sys.argv[1]).resolve()
COMMIT = "c194dd00cd42aa18d9dbf27d977bf6b85d9ea565"
FILES = [
    ("diffusion_models/qwen_image_2.1_bf16.safetensors", 14230280616, "89f4158d066cc33906a199fca85634f766892dd78f49b6698dabf187ac86c4bc"),
    ("text_encoders/qwen3vl_8b_bf16.safetensors", 17534334616, "68bdc82bc1b66851162ae656225e7e2068166b603db19bd5d5a3b90eb12669a9"),
    ("vae/qwen_image_2.1_vae_bf16.safetensors", 675509688, "bb21f7473051e1ac368515dd3f2e15cd44d7a11748ee8823e1ddca3e4876b7c9"),
]
if "--compact" in sys.argv:
    FILES[:2] = [
        ("diffusion_models/qwen_image_2.1_int8_convrot.safetensors", 7256783064, "cb74113cb03faecd79611b01fd7fd642f0aa60d6f0b95086abee214d75eaa57d"),
        ("text_encoders/qwen3vl_8b_int8_convrot.safetensors", 9350798360, "8bfd0f6e12abf2d2d697ecc888e5e90b0d6741d6708f05799f53afa560452e8f"),
    ]

def emit(message, progress=None):
    print(json.dumps({"message": message, "progress": progress}), flush=True)

def install_engine():
    if (ROOT / "ComfyUI" / "main.py").exists():
        return
    emit("Setting up the local image engine …")
    archive = ROOT / "engine.tar.gz"
    urllib.request.urlretrieve(f"https://codeload.github.com/Comfy-Org/ComfyUI/tar.gz/{COMMIT}", archive)
    with tarfile.open(archive) as tf:
        tf.extractall(ROOT, filter="data")
    (ROOT / f"ComfyUI-{COMMIT}").rename(ROOT / "ComfyUI")
    archive.unlink()

def download_models():
    total = sum(size for _, size, _ in FILES)
    completed = 0
    for name, size, digest in FILES:
        dest = ROOT / "ComfyUI" / "models" / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        marker = dest.with_suffix(".verified")
        if dest.exists() and dest.stat().st_size == size and marker.exists() and marker.read_text() == digest:
            completed += size
            continue
        partial = dest.with_suffix(".partial")
        if dest.exists() and dest.stat().st_size == size:
            dest.rename(partial)
        for attempt in range(5):
            offset = partial.stat().st_size if partial.exists() else 0
            if offset == size:
                break
            try:
                req = urllib.request.Request(
                    "https://huggingface.co/Comfy-Org/Qwen-Image-2.1/resolve/main/" + name + "?download=true",
                    headers={"Range": f"bytes={offset}-"} if offset else {},
                )
                with urllib.request.urlopen(req, timeout=120) as response:
                    if offset and response.status != 206:
                        offset = 0
                    with partial.open("ab" if offset else "wb") as out:
                        last = 0
                        while chunk := response.read(8 * 1024 * 1024):
                            out.write(chunk)
                            offset += len(chunk)
                            if time.monotonic() - last > 1:
                                emit(f"Downloading model · {(completed + offset) / 1e9:.1f} of {total / 1e9:.1f} GB", (completed + offset) / total)
                                last = time.monotonic()
                if offset == size:
                    break
            except Exception:
                if attempt == 4:
                    raise
                time.sleep(2 ** attempt)
        emit("Verifying the model download …", completed / total)
        actual = hashlib.file_digest(partial.open("rb"), "sha256").hexdigest()
        if actual != digest:
            partial.unlink(missing_ok=True)
            raise RuntimeError("The model download is incomplete. Please run setup again.")
        partial.replace(dest)
        marker.write_text(digest)
        completed += size

if __name__ == "__main__":
    ROOT.mkdir(parents=True, exist_ok=True)
    install_engine()
    if "--models-only" not in sys.argv:
        emit("Installing Python libraries …")
        uv = sys.argv[2]
        subprocess.run([uv, "pip", "install", "--python", sys.executable, "-r", str(Path(__file__).with_name("requirements-lock.txt"))], check=True)
    download_models()
    (ROOT / "ready.json").write_text(json.dumps({"engine": COMMIT, "model": "Qwen-Image-2.1", "precision": "int8_convrot" if "--compact" in sys.argv else "bf16"}))
    emit("All set. Your image studio is ready.", 1)
