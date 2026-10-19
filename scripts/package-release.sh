#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="$(cat VERSION)"
APP="$PWD/dist/ChatGPT Limits.app"
[[ -d "$APP" ]] || { echo "Run bash scripts/build.sh first." >&2; exit 1; }
ACTUAL_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
[[ "$ACTUAL_VERSION" == "$VERSION" ]] || { echo "Rebuild the app for VERSION=$VERSION." >&2; exit 1; }
codesign --verify --strict "$APP"
python3 scripts/audit-release.py --binary "$APP/Contents/MacOS/ChatGPTLimits"
ARCH="$(lipo -archs "$APP/Contents/MacOS/ChatGPTLimits" | tr ' ' '-')"
if lipo -verify_arch arm64 "$APP/Contents/MacOS/ChatGPTLimits" 2>/dev/null \
    && lipo -verify_arch x86_64 "$APP/Contents/MacOS/ChatGPTLimits" 2>/dev/null; then ARCH=universal; fi
NAME="ChatGPT-Limits-v${VERSION}-macOS-${ARCH}"
STAGING="$(mktemp -d "$PWD/dist/package.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
mkdir -p "$STAGING/$NAME" dist/release
ditto --norsrc "$APP" "$STAGING/$NAME/ChatGPT Limits.app"
cp LICENSE README.md README.ru.md CHANGELOG.md CONTRIBUTING.md SECURITY.md "$STAGING/$NAME/"
ditto --norsrc docs "$STAGING/$NAME/docs"
ditto -c -k --norsrc --keepParent "$STAGING/$NAME" "$PWD/dist/release/$NAME.zip"
(cd dist/release && shasum -a 256 "$NAME.zip" > "$NAME.zip.sha256")
echo "Packaged: $PWD/dist/release/$NAME.zip"

# A user-facing installer image contains just the app, its drop target, and help.
mkdir -p "$STAGING/dmg"
ditto --norsrc "$APP" "$STAGING/dmg/ChatGPT Limits.app"
ln -s /Applications "$STAGING/dmg/Applications"
cp docs/Install.html "$STAGING/dmg/Install.html"
hdiutil create -volname "ChatGPT Limits" -srcfolder "$STAGING/dmg" \
    -fs HFS+ -format UDZO -noanyowners "$STAGING/$NAME.dmg"
hdiutil verify -quiet "$STAGING/$NAME.dmg"
mv -f "$STAGING/$NAME.dmg" "$PWD/dist/release/$NAME.dmg"
(cd dist/release && shasum -a 256 "$NAME.dmg" > "$NAME.dmg.sha256")
echo "Installer: $PWD/dist/release/$NAME.dmg"
