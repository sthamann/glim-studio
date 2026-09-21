"""Launch the private ComfyUI engine with local memory telemetry."""
import json
import os
from pathlib import Path
import runpy
import sys
import threading
import time

root = Path(sys.argv.pop(1)).resolve()
os.chdir(root / "ComfyUI")
sys.path.insert(0, str(root / "ComfyUI"))
sys.argv[0] = "main.py"

def monitor():
    import psutil
    import torch
    process = psutil.Process()
    with (root / "memory.jsonl").open("w", buffering=1) as output:
        while True:
            try:
                parent = os.environ.get("LICHTBILD_PARENT_PID")
                if parent and os.getppid() != int(parent):
                    os._exit(0)
                sample = {"time": time.time(), "rss_bytes": process.memory_info().rss,
                          "mps_allocated_bytes": torch.mps.current_allocated_memory(),
                          "mps_driver_bytes": torch.mps.driver_allocated_memory()}
                output.write(json.dumps(sample) + "\n")
            except Exception:
                pass
            time.sleep(1)

threading.Thread(target=monitor, daemon=True).start()
runpy.run_path("main.py", run_name="__main__")
