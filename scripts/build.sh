#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
VERSION="$(cat VERSION)"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Invalid VERSION" >&2; exit 1; }
BUILD_ARGS=(-c release --disable-sandbox -debug-info-format none)
OUTPUT_APP="$PWD/dist/ChatGPT Limits.app"
mkdir -p "$PWD/dist"
STAGING="$(mktemp -d "$PWD/dist/build.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
APP="$STAGING/ChatGPT Limits.app"
mkdir -p "$APP/Contents/MacOS"
if [[ "${1:-}" == "--universal" && $# -eq 1 ]]; then
    [[ -z "${TARGET_TRIPLE:-}" ]] || { echo "Do not combine TARGET_TRIPLE and --universal." >&2; exit 1; }
    BINARIES=()
    for ARCH in arm64 x86_64; do
        TRIPLE="$ARCH-apple-macosx13.0"
        # Newer SwiftPM engines reuse the product path across --triple values.
        # Separate scratch directories prevent one slice overwriting the other.
        ARCH_ARGS=(--scratch-path "$PWD/.build/universal/$ARCH" --triple "$TRIPLE")
        swift build "${BUILD_ARGS[@]}" "${ARCH_ARGS[@]}" --product ChatGPTLimits
        BIN_DIR="$(swift build "${BUILD_ARGS[@]}" "${ARCH_ARGS[@]}" --show-bin-path)"
        lipo -verify_arch "$ARCH" "$BIN_DIR/ChatGPTLimits"
        BINARIES+=("$BIN_DIR/ChatGPTLimits")
    done
    lipo -create "${BINARIES[@]}" -output "$APP/Contents/MacOS/ChatGPTLimits"
    for ARCH in arm64 x86_64; do lipo -verify_arch "$ARCH" "$APP/Contents/MacOS/ChatGPTLimits"; done
elif [[ $# -eq 0 ]]; then
    if [[ -n "${TARGET_TRIPLE:-}" ]]; then BUILD_ARGS+=(--triple "$TARGET_TRIPLE"); fi
    swift build "${BUILD_ARGS[@]}" --product ChatGPTLimits
    BIN_DIR="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)"
    cp "$BIN_DIR/ChatGPTLimits" "$APP/Contents/MacOS/ChatGPTLimits"
else
    echo "Usage: bash scripts/build.sh [--universal]" >&2
    exit 1
fi
strip -S -x "$APP/Contents/MacOS/ChatGPTLimits"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>ChatGPTLimits</string>
<key>CFBundleIdentifier</key><string>local.chatgpt-limits</string>
<key>CFBundleName</key><string>ChatGPT Limits</string>
<key>CFBundleDisplayName</key><string>ChatGPT Limits</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$VERSION</string>
<key>CFBundleVersion</key><string>$VERSION</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
codesign --verify --strict "$APP"
# Replace the generated bundle only after the new one has passed verification.
rm -rf "$OUTPUT_APP"
mv "$APP" "$OUTPUT_APP"
echo "Built: $OUTPUT_APP"
