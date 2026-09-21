Glim Studio 0.3.1 fixes sluggish typing when large reference photos or generated images are visible.

- Reference thumbnails, library tiles and the result canvas load display-sized images asynchronously, away from the UI thread.
- Display images are reused across typing and progress updates, with a bounded memory cache.
- Full-resolution originals remain untouched for generation, saving, copying and printing. Photo orientation and transparency are preserved.

Checks cover camera-sized images, thumbnail bounds, cache reuse, main-actor responsiveness, EXIF orientation, missing files and unchanged originals. Existing generation and multi-reference workflow checks also pass.

**Requirements:** Apple Silicon, macOS 14+, 24 GB RAM recommended. 16 GB remains experimental; 8 GB and Intel Macs are not supported by the released app.

**Early access:** Ad-hoc signed with signed Sparkle updates; not yet Apple Developer ID signed or notarized. Qwen’s separate research model license applies.
