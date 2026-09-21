# Glim Studio 0.3.1 — responsive image display

Measured 21 September 2026 on M3 Ultra / 512 GiB / macOS 26.4.1.

## Cause

The prompt is published through StudioStore. ComposerView previously created a new NSImage from each reference URL every time its body was recomputed. CanvasView and LibraryView had the same synchronous file-loading pattern. Large PNGs were decoded again on the main thread for drawing, even when only text or progress had changed.

A three-second sample of the running 0.3.0 app with a large reference image showed 1,456 samples under one PNG decode branch on the main thread, out of 2,328 main-thread samples, with another 201 samples under a second PNG decode branch. This was captured during generation updates, not a controlled keystroke latency benchmark.

## Change

DisplayImageCache serializes display-image decoding on a separate actor. ImageIO creates orientation-correct, immediately decoded thumbnails. LocalImageView keeps its image in state and starts a load only when URL or pixel limit changes. The shared cache uses a 64 MiB cost target and 80-entry limit; NSCache limits are eviction hints, not hard process-memory limits.

Reference thumbnails: 256 pixels maximum edge. Library tiles: 640. Result canvas: 2,560. The original files retain full resolution and remain the inputs for inference, copy, save and print. Internal image filenames are immutable UUIDs, making URL-and-size cache keys safe.

## Verification

The reproducible check uses a synthetic 4,032 × 3,024 PNG with texture and transparency. First measured run:

- Legacy synchronous full-image load plus thumbnail drawing: 241, 162, 160, 161, 161 ms over five iterations.
- First background thumbnail decode: 167 ms, with 28 main-actor heartbeats serviced during the operation.
- Average warm cache request: 0.0153 ms across 100 requests; identical CGImage objects reused.
- 256 × 192 thumbnail bitmap: 192 KiB.
- EXIF rotation, alpha presence, separate size entries, missing-file error and unchanged source bytes checked.

These are image-loading measurements, not end-to-end keyboard latency or image-generation speedups.

Installed 0.3.1 was exercised through the native UI using the same large reference file. Text input and the restored prompt were visible. A ten-second sampling capture during this interaction showed no PNG decode entries. The result canvas and reference thumbnail were visually checked. A fully controlled before/after keystroke timing could not be collected because the original app was closed during the baseline attempt; no numerical keystroke improvement is claimed.

Reproduce the fixture check with `./script/check.sh`. The normal release build and packaged-app signature/identity checks pass.

The library filter and result navigation also passed native UI checks. A fresh local BF16 512² / 10-step generation completed successfully in 28.16 seconds using the installed app’s engine; the resulting generic cup image was visually inspected. This smoke test does not modify the user-facing library.
