# Performance, with boundaries

Measured 21 September 2026 on a **Mac Studio M3 Ultra, 80 GPU cores, 512 GiB RAM**, macOS 26.4.1. These are individual engineering runs, not a benchmark of consumer MacBooks. No claim is made for untested 16/24 GB devices or 2K output.

| Backend and model | Resolution / steps | Wall time | Context |
|---|---:|---:|---|
| ComfyUI / PyTorch MPS, BF16 | 1024² / 40 | 124.55 s | Warm process |
| MFLUX / MLX, BF16 | 1024² / 40 | 122.74 s | Model loading excluded |
| ComfyUI / MPS, INT8 | 512² / 20 | 36.45 s | Fresh process, model loading included |
| ComfyUI / MPS, INT8 | 1024² / 20 | 80.39 s | Warm after the 512² run |
| ComfyUI / MPS, INT8 edit | 512² / 20 | 38.18 s | One reference image |
| ComfyUI / MPS, INT8 transparent sticker | 512² / 20 | 33.17 s | Actual RGBA output checked |

The BF16 backend comparison uses the same prompt, resolution and step count, but does not establish identical random-number or scheduler behavior, output equivalence, or statistical significance. The 1.5% timing difference is too small to justify a port on its own.

Compact-process lifetime peak physical footprint after the 512² and 1024² runs: **13.76 GiB**. MLX BF16 allocated roughly 43 GiB of arrays at peak; one in-flight process footprint observation was about 49.3 GiB. These are different measurements and precisions, not an apples-to-apples memory comparison. RSS alone can undercount mapped or compressed memory.

## Experimental step reuse (EasyCache)

A new paired engineering probe used the same ceramic-cup prompt, seed 42, BF16 weights, Euler/simple sampler and 40 steps. Each resolution had a separate warm-up; prompt encoding and weights were cached for both variants. Wall times include one-second result polling.

| Resolution | Normal | EasyCache | Ratio |
|---|---:|---:|---:|
| 512² | 29.14 s | 12.06 s | 2.42× |
| 1024² | 125.60 s | 47.24 s | 2.66× |

Settings: reuse threshold 0.2, start 0.15, end 0.95. The 512² run skipped 25 of 40 model evaluations. The cup composition remained similar, but shape, edges and surface details changed. These are single examples, **not evidence of equivalent quality**. Version 0.3 exposes an explicitly experimental Fast mode, **off by default**, separate from Qwen's already-active prefix cache. See the compact-model comparison below for additional checks.

## Smaller-Mac memory work

### Compact model Fast-mode checks

Paired INT8/MPS runs at 512², 40 steps, seed 42, Euler/simple. Each prompt had a separate one-step warm-up before the normal/fast pair. Both cases therefore reuse prompt encoding/model loading. One-second polling is included; these are individual engineering examples, not a statistical quality benchmark.

| Case | Normal | Fast | Speed ratio | Visual check |
|---|---:|---:|---:|---|
| Poster text | 54.28 s | 20.12 s | 2.70× | HELLO GLIM legible in both; softer edges in Fast |
| Fictional portrait | 54.33 s | 22.12 s | 2.46× | Requested face/glasses/scarf present; fine features change |
| Transparent fox sticker | 54.41 s | 21.23 s | 2.56× | RGBA with alpha 0…255 in both; Fast introduces more edge artifacts |
| Cup recolouring edit | 56.40 s | 25.14 s | 2.24× | Blue recolouring succeeds in both; detail differs |

Fast is useful for exploration but is not a quality-preserving optimization. Keep normal mode for final typography, clean cutout edges or identity-sensitive edits. Reproduce with `script/benchmark_cache_suite.py --port <private-engine-port>`; the test uses only generic prompts and an explicitly provided generic cup fixture. It does not modify the app's user-facing library.

[Actual comparison images](benchmarks/README.md) · [Machine-readable measurements](benchmarks/2026-09-21.json)

### Idle cache release

After this suite, the normal engine's physical footprint fell from **9.39 GiB to 0.57 GiB** within five seconds of requesting `unload_models` and `free_memory`. The engine remained alive. Below 32 GB, version 0.3 requests this release after downloading and saving each finished image. This reduces memory held **between jobs**, not generation peak, and makes the next job reload its models. The separate JSON observation records transient release behaviour as well as the final value.

### Sequential q4 experiment

Sequentially loading a prequantized 4-bit text encoder, transformer and VAE, then decoding overlapping tiles, completed 512² and 1024² / 20-step text-to-image probes at **5.62 and 5.79 GiB lifetime peak physical footprint**, including startup. Both passed a 6 GiB process-footprint watchdog on the M3 Ultra. Whole-process times were 19.01 and 69.89 seconds on this hardware. This is not a small-Mac simulation or proof of equivalent image quality.

The q4 encoder intentionally overrides an upstream quality precaution; the probe lacks the production editing/alpha/preview lifecycle. It therefore remains outside the released app backend. [Full experiment and reproduction](small-macs.md).

## Optimization priorities

1. **Fewer steps.** 20 rather than 40 roughly halves the iterative part, not total time. Texture, text and difficult edits need quality comparisons. The app exposes the step setting; Draft uses 20, Standard 40.
2. **Smaller drafts before final renders.** 512² carries a quarter of the pixels of 1024² and can be much faster. Final high-resolution regeneration can change composition; it is not lossless enlargement.
3. **Fit within physical memory.** Compact weights, releasing inactive components and controlled caching matter most on small MacBooks. Swapping can dominate latency. INT8 is already selected automatically below 48 GB.
4. **Avoid redundant work.** Prompt results and model weights are retained by the engine. Qwen's prefix cache is already enabled automatically by the pinned ComfyUI implementation; merely adding a cache node is not a new optimization.
5. **Targeted MLX work.** Quantize/offload the text encoder and optimize kernels, then benchmark the full editing pipeline. The currently tested MFLUX port lacks production parity for editing and RGBA. No speed multiplier is promised.
6. **Distillation and step caching.** Potentially larger gains, but need a Qwen-2.1-compatible implementation and image-quality regression tests. CUDA-specific acceleration cannot simply be enabled on a Mac.

The live preview uses a small latent-to-RGB projection, not a full VAE decode every step. It is intentionally coarse and does not alter the sampler or final output. The UI makes the wait more informative; this alone does not make generation faster.

## References and reproduction

- `script/benchmark.py`: production-engine inference and memory observations.
- `script/benchmark_mlx.py`: experimental MLX timing.
- Pinned ComfyUI: `c194dd00cd42aa18d9dbf27d977bf6b85d9ea565`.
- Tested MFLUX: `8c00dab2505a96019df9d30bc9c223bf20d733c4`.
- [Official Qwen documentation](https://github.com/QwenLM/Qwen-Image-2.1) recommends 40 steps.
- [MFLUX Qwen 2.1 implementation](https://github.com/mflux-community/mflux/tree/main/src/mflux/models/qwen21).

The next meaningful acceptance test is real hardware with 16 and 24 GB: time to first preview, total time, physical footprint, swap pressure and quality across text generation, editing and transparent output.
