#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p work
swiftc Sources/QwenStudio/Models/Creation.swift Sources/QwenStudio/Models/FormatPreset.swift Sources/QwenStudio/Services/Workflow.swift Sources/QwenStudio/Services/PreviewFrame.swift Sources/QwenStudio/Services/ImageOutput.swift script/checks.swift -o work/contract-checks
work/contract-checks
swiftc -O Sources/QwenStudio/Services/DisplayImageCache.swift script/check_display_images.swift -o work/display-image-checks
work/display-image-checks
