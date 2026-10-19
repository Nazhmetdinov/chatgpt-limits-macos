#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
BIN="$PWD/dist/ChatGPT Limits.app/Contents/MacOS/ChatGPTLimits"
[[ -x "$BIN" ]] || { echo "Run bash scripts/build.sh first." >&2; exit 1; }
mkdir -p docs/images
for PLAN in plus pro; do
    TZ=UTC "$BIN" --render-fixture "Tests/Fixtures/$PLAN.json" "docs/images/$PLAN.png"
done
