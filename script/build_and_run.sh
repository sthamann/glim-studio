#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-run}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
APP_NAME="GlimStudio"
OUTPUT_BUNDLE="$ROOT_DIR/outputs/Glim Studio.app"
STAGE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/glim-package.XXXXXX")"
trap 'rm -rf "$STAGE_DIR"' EXIT
APP_BUNDLE="$STAGE_DIR/Glim Studio.app"
pkill -x "$APP_NAME" >/dev/null 2>&1 || true
CONFIGURATION="${CONFIGURATION:-release}"
VERSION="${VERSION_OVERRIDE:-$(cat VERSION)}"
swift build -c "$CONFIGURATION"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources/backend"
cp "$(swift build -c "$CONFIGURATION" --show-bin-path)/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp backend/*.py backend/requirements-lock.txt "$APP_BUNDLE/Contents/Resources/backend/"
cp backend/Qwen-LICENSE.txt "$APP_BUNDLE/Contents/Resources/Qwen-LICENSE.txt"
cp backend/NOTICE.txt backend/uv-LICENSE-* "$APP_BUNDLE/Contents/Resources/"
cp -f "$(command -v uv)" "$APP_BUNDLE/Contents/Resources/uv"
if [[ ! -f "$APP_BUNDLE/Contents/Resources/AppIcon.icns" ]]; then
  mkdir -p work/AppIcon.iconset
  swift script/make_icon.swift work/AppIcon-1024.png
  for SIZE in 16 32 128 256 512; do
    sips -z "$SIZE" "$SIZE" work/AppIcon-1024.png --out "work/AppIcon.iconset/icon_${SIZE}x${SIZE}.png" >/dev/null
    DOUBLE=$((SIZE * 2))
    sips -z "$DOUBLE" "$DOUBLE" work/AppIcon-1024.png --out "work/AppIcon.iconset/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
  done
  iconutil -c icns work/AppIcon.iconset -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi
mkdir -p "$APP_BUNDLE/Contents/Frameworks"
ditto .build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework "$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"
cp .build/artifacts/sparkle/Sparkle/LICENSE "$APP_BUNDLE/Contents/Resources/Sparkle-LICENSE.txt"
cat > "$APP_BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>GlimStudio</string>
<key>CFBundleIdentifier</key><string>studio.glim.mac</string>
<key>CFBundleName</key><string>Glim Studio</string>
<key>CFBundleDisplayName</key><string>Glim Studio</string>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleLocalizations</key><array><string>en</string></array>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>0.1.0</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>SUFeedURL</key><string>https://github.com/sthamann/glim-studio/releases/latest/download/appcast.xml</string>
<key>SUPublicEDKey</key><string>5jks8wUqM/Ht3BQPdgEcozo69tAQfOTERxlo4ZyDKM4=</string>
<key>SUEnableAutomaticChecks</key><true/>
<key>SUAllowsAutomaticUpdates</key><true/>
<key>SURequireSignedFeed</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSAppTransportSecurity</key><dict><key>NSAllowsLocalNetworking</key><true/></dict>
</dict></plist>
PLIST
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$APP_BUNDLE/Contents/Info.plist"
# Finder may attach this metadata after the app is opened in Documents.
# Remove only signing-incompatible Finder metadata from our own bundle.
xattr -r -d com.apple.FinderInfo "$APP_BUNDLE" 2>/dev/null || true
xattr -r -d com.apple.ResourceFork "$APP_BUNDLE" 2>/dev/null || true
codesign --force --deep --sign - "$APP_BUNDLE"
codesign --verify --deep --strict "$APP_BUNDLE"
ditto "$APP_BUNDLE" "$OUTPUT_BUNDLE"
APP_BUNDLE="$OUTPUT_BUNDLE"
case "$MODE" in
  run) open -n "$APP_BUNDLE" ;;
  --verify) open -n "$APP_BUNDLE"; sleep 1; pgrep -x "$APP_NAME" >/dev/null ;;
  --build-only) ;;
  --debug) lldb -- "$APP_BUNDLE/Contents/MacOS/$APP_NAME" ;;
  --logs|--telemetry) open -n "$APP_BUNDLE"; /usr/bin/log stream --info --predicate 'process == "GlimStudio"' ;;
  *) exit 2 ;;
esac
