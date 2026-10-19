#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/scripts/build.sh"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/outputs/DockPin.app/Contents/Info.plist")"
ARCHIVE="DockPin-${VERSION}-macos-arm64.zip"
ditto -c -k --sequesterRsrc --keepParent "$ROOT/outputs/DockPin.app" "$ROOT/outputs/$ARCHIVE"
cd "$ROOT/outputs"
shasum -a 256 "$ARCHIVE" > SHA256SUMS
printf '%s\n' "$ROOT/outputs/$ARCHIVE" "$ROOT/outputs/SHA256SUMS"
