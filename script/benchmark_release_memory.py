"""Measure idle-cache release on an explicitly selected, idle local engine."""
import argparse
import ctypes
import json
from pathlib import Path
import subprocess
import time
import urllib.request

p = argparse.ArgumentParser()
p.add_argument("--port", required=True, type=int)
a = p.parse_args()
base = f"http://127.0.0.1:{a.port}"
with urllib.request.urlopen(base + "/queue") as response:
    queue = json.load(response)
if queue["queue_running"] or queue["queue_pending"]:
    raise RuntimeError("Engine is busy; do not release another job's cache")
pid = int(subprocess.check_output(["lsof", "-ti", f"tcp:{a.port}", "-sTCP:LISTEN"]).strip())
class Usage(ctypes.Structure):
    _fields_ = [("uuid", ctypes.c_ubyte * 16), ("values", ctypes.c_uint64 * 35)]
lib = ctypes.CDLL("/usr/lib/libproc.dylib")
def footprint():
    u = Usage()
    if lib.proc_pid_rusage(pid, 4, ctypes.byref(u)) != 0:
        raise RuntimeError("Could not measure engine")
    return u.values[7]
before = footprint()
req = urllib.request.Request(base + "/free", data=json.dumps({"unload_models": True, "free_memory": True}).encode(), headers={"Content-Type": "application/json"})
with urllib.request.urlopen(req) as response:
    assert response.status == 200
samples = []
for _ in range(20):
    time.sleep(0.25)
    samples.append(footprint())
record = {"before_bytes": before, "after_bytes": samples[-1], "samples_bytes": samples,
          "note": "Idle cache release only, not a reduction in generation peak. Engine stays alive; next job reloads weights."}
Path("outputs/performance/idle-memory-release.json").write_text(json.dumps(record, indent=2))
print(json.dumps(record, indent=2))
