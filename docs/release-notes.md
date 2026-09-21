Glim Studio 0.3 adds an optional experimental Fast mode and improves idle memory behaviour on smaller Macs.

- **Fast mode** in Advanced reuses intermediate results. It is off by default: lettering, fine detail and edges can change. Use normal mode for final images.
- **Below 32 GB RAM**, the app requests cache/model release after saving each image. Your library and downloaded models stay intact. The next generation may take longer to start. This reduces idle memory, not the peak needed during generation.
- The library remembers whether an image used Fast mode when you reuse its prompt. Older libraries remain compatible.
- Local diagnostics now include macOS physical footprint, covering more than resident-memory readings alone.
- Settings displays the installed app version correctly.

The repository also includes a separate sequential 4-bit MLX research probe. On an M3 Ultra it completed 512² and 1024² / 20-step jobs with 5.62 and 5.79 GiB process peaks, including loading. **This is not the released app backend, not validation on an 8/16 GB MacBook, and not proof of equivalent quality.** See the performance documentation for methods and limits.

The existing Photos picker, multiple reference selection, clipboard copy, Save as, printing, format presets and local live previews remain available.

**Requirements:** Apple Silicon, macOS 14+, 24 GB RAM recommended. 16 GB remains experimental; 8 GB and Intel Macs are not supported by the released app. First launch downloads 17.3 GB (compact) or 32.4 GB (full precision) of model weights.

**Early access:** Ad-hoc signed with signed Sparkle updates; not yet Apple Developer ID signed or notarized.

Qwen-Image-2.1 is licensed for research and evaluation. Commercial use requires a separate model license. Glim Studio is not affiliated with Qwen or Alibaba.
