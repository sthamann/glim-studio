# Small-Mac engineering probes

These experiments were run on 21 September 2026 on an **M3 Ultra, 80 GPU cores, 512 GiB RAM**. They investigate the memory working set. They do **not** emulate a MacBook's GPU, bandwidth, thermals, swap behaviour or other applications.

## What made the difference

The production backend is ComfyUI/PyTorch MPS. Its earlier compact INT8 process reached a lifetime physical-footprint peak of 13.76 GiB across 512² and 1024² runs. That leaves very little room on a 16 GB Mac.

The experimental MFLUX/MLX pipeline now has three changes:

1. Quantize both the image transformer **and the text encoder** to 4-bit. Upstream deliberately keeps the text encoder unquantized because of semantic degradation. This experiment overrides that policy; quality equivalence is not established.
2. Load one component at a time: text encoder → image transformer → image decoder. Evaluate dependent arrays before releasing their weights.
3. Decode overlapping tiles rather than the whole image at once. Tiling can change detail or introduce seams and requires visual checks.

The saved checkpoint occupies **9.60 GB on disk**. Disk size is not RAM use. Conversion happens separately; a small-Mac installation would need an already converted download, not on-device BF16 conversion.

## Measured memory budget probes

All cases below use the same ceramic-cup prompt, seed 42 and 20 steps. Each starts a fresh process, including model loading. The process is monitored every 100 ms using macOS `proc_pid_rusage`, including the kernel's lifetime peak physical footprint. MLX's allocator limit is only a guideline; a separate watchdog ends the probe when the process crosses its stated budget. Overshoot between samples is possible.

| Loading / decoding policy | Output | Peak physical footprint | Generation | Whole process | Outcome |
|---|---:|---:|---:|---:|---|
| All q4 components resident, full decode | 512² | >12 GiB | — | — | Watchdog stopped decode |
| Load all, release between phases, full decode | 512² | 9.96 GiB | 15.60 s | 18.78 s | Passed 12 GiB budget |
| Load all, release between phases, tiled decode | 1024² | 9.96 GiB | 66.89 s | 70.12 s | Passed 12 GiB budget |
| **Sequential component load + tiled decode** | **512²** | **5.62 GiB** | **16.06 s** | **19.01 s** | **Passed 6 GiB budget** |
| **Sequential component load + tiled decode** | **1024²** | **5.79 GiB** | **66.87 s** | **69.89 s** | **Passed 6 GiB budget** |

These times are for the M3 Ultra, not estimated MacBook timings. Individual engineering runs do not establish typical performance. Existing MLX-vs-MPS speed measurements used different precision; do not attribute this entire difference to MLX.

The 1024² output from sequential loading was **pixel-identical** to the all-components-loaded q4 run with the same tiled decoder. This isolates the loading-policy change: 9.96 → 5.79 GiB, about 42% lower peak, without changing that image. It does **not** establish equivalence between q4 and BF16 or between tiled and full decoding.

Additional 512² / 40-step probes passed the same 6 GiB watchdog: a poster with `HELLO GLIM` (39.37 s generation, 5.68 GiB peak) and a fictional elderly woman with glasses and a green scarf (33.98 s, 5.66 GiB). The poster text was legible and the portrait contained the requested main elements. These are visual smoke tests, not proof of general prompt fidelity or portrait identity preservation.

A fresh INT8/MPS process with `--cache-none --disable-smart-memory` completed a 512² / 20-step probe in 39.30 s at an 11.18 GiB lifetime peak. This remains well above the sequential q4 working set. It was not a paired same-resolution memory comparison against the previous 13.76 GiB lifetime peak, and these flags are not enabled in the app. The pinned ComfyUI code also forces MPS to its shared-memory state, so CUDA-style `--lowvram` flags alone do not provide a tested small-Mac solution.

## What is and is not shipped

The 4-bit pipeline is a **reproducible research probe**, not Glim's production backend. It currently covers RGB text-to-image. Reference instruction editing, ten-image composition, alpha output, live previews, cancellation, durable downloads and warm-process lifecycle still need integration and validation. The app continues to use the tested INT8/BF16 MPS engine. Its 8 GB restriction remains in place.

The memory result makes a 16 GB integration worth pursuing. It does not certify 8 GB support: macOS, the app, the display and other software still need memory. A real 16/24 GB Mac is the next hardware acceptance gate.

## Reproduce

Use a separate Python environment with MFLUX pinned to `8c00dab2505a96019df9d30bc9c223bf20d733c4`, the same revision as the existing MLX comparison. Put that checkout at `work/mflux`. The scripts assume execution from the Glim repository root and an existing official Qwen BF16 Hugging Face cache at `work/hf-cache`; no weights are bundled or downloaded by this test. The model's separate research license still applies.

Measured environment: Python 3.12.12, MLX/MLX-Metal 0.32.2, NumPy 2.5.3, Transformers 5.17.0 and Safetensors 0.8.0. The tested MFLUX revision must be installed in that environment. The text encoder modification is scoped to the benchmark process; the upstream checkout and production app are not modified by it.

```sh
# On a large Mac, once. This stage is NOT subject to the probe budget.
work/mlx-venv/bin/python script/benchmark_small_macs.py \
  --convert --name mlx-q4-conversion

# Fresh process, including loading. Exit 42 means the budget was exceeded.
work/mlx-venv/bin/python script/benchmark_small_macs.py \
  --name mlx-q4-sequential-512-20-budget6 --budget-gib 6 \
  --release-between-phases --sequential-load --tiled-decode

# Higher-resolution probe; keep the same settings and seed.
work/mlx-venv/bin/python script/benchmark_small_macs.py \
  --name mlx-q4-sequential-1024-20-budget6 --size 1024 --budget-gib 6 \
  --release-between-phases --sequential-load --tiled-decode
```

JSON reports, memory samples and actual images are written to `outputs/performance/`. A failed or interrupted run is not a pass. Outputs are deliberately not committed automatically: never publish personal prompts or references in benchmark evidence.

For a real MacBook acceptance run, record chip/core count, RAM, OS, cold start, time to first preview, end-to-end time, process peak, system memory pressure/swap delta, cancellation/retry and a second image. Test text, people, editing and transparency separately. Compare with a normal-quality control; a lower footprint cannot compensate for a broken prompt or missing functionality.
