#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p work
swiftc Sources/QwenStudio/Models/Creation.swift Sources/QwenStudio/Services/Workflow.swift Sources/QwenStudio/Services/PreviewFrame.swift script/checks.swift -o work/contract-checks
work/contract-checks
