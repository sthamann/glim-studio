#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="$(cat VERSION)"
REPO="${GITHUB_REPOSITORY:-sthamann/glim-studio}"
./script/build_and_run.sh --build-only
mkdir -p dist
ARCHIVE="Glim-Studio-${VERSION}-arm64.zip"
ditto -c -k --sequesterRsrc --keepParent 'outputs/Glim Studio.app' "dist/$ARCHIVE"
SPARKLE=.build/artifacts/sparkle/Sparkle/bin
if [[ -n "${SPARKLE_PRIVATE_KEY:-}" ]]; then
  printf '%s' "$SPARKLE_PRIVATE_KEY" | "$SPARKLE/generate_appcast" --ed-key-file - --maximum-deltas 0 --download-url-prefix "https://github.com/$REPO/releases/download/v$VERSION/" dist
else
  "$SPARKLE/generate_appcast" --account glim-studio-updates --maximum-deltas 0 --download-url-prefix "https://github.com/$REPO/releases/download/v$VERSION/" dist
fi
(cd dist && shasum -a 256 "$ARCHIVE" > SHA256SUMS)
