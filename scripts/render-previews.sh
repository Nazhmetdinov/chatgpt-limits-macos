#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
BIN="$PWD/dist/ChatGPT Limits.app/Contents/MacOS/ChatGPTLimits"
[[ -x "$BIN" ]] || { echo "Run bash scripts/build.sh first." >&2; exit 1; }
mkdir -p docs/images
for PLAN in plus pro; do
    TZ=UTC "$BIN" --render-fixture "Tests/Fixtures/$PLAN.json" "docs/images/$PLAN.png"
done
ICONSET="$(mktemp -d "$PWD/dist/icon-preview.XXXXXX")"
trap 'rm -rf "$ICONSET"' EXIT
"$BIN" --render-app-icons "$ICONSET" docs/images/app-icon.png
