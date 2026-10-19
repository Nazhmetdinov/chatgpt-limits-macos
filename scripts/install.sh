#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
SOURCE="$PWD/dist/ChatGPT Limits.app"
TARGET="$HOME/Applications/ChatGPT Limits.app"
if [[ ! -d "$SOURCE" ]]; then bash scripts/build.sh; fi
codesign --verify --strict "$SOURCE"
mkdir -p "$HOME/Applications"
if [[ -e "$TARGET" ]]; then
    BACKUP="$PWD/dist/backups/ChatGPT Limits-$(date +%Y%m%d-%H%M%S).app"
    mkdir -p "$(dirname "$BACKUP")"
    ditto "$TARGET" "$BACKUP"
    codesign --verify --strict "$BACKUP"
    echo "Backup: $BACKUP"
fi
STAGING="$(mktemp -d "$HOME/Applications/.chatgpt-limits-install.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
ditto "$SOURCE" "$STAGING/new.app"
codesign --verify --strict "$STAGING/new.app"
if [[ -e "$TARGET" ]]; then mv "$TARGET" "$STAGING/previous.app"; fi
if ! mv "$STAGING/new.app" "$TARGET"; then
    if [[ -e "$STAGING/previous.app" ]]; then mv "$STAGING/previous.app" "$TARGET"; fi
    exit 1
fi
if ! codesign --verify --strict "$TARGET"; then
    rm -rf "$TARGET"
    if [[ -e "$STAGING/previous.app" ]]; then mv "$STAGING/previous.app" "$TARGET"; fi
    exit 1
fi
if [[ $# -gt 0 ]]; then
    open "$TARGET" --args "$@"
else
    open "$TARGET"
fi
echo "Installed: $TARGET"
