#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/outputs/DockPin.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$ROOT/work/swift-cache"
xcrun swiftc -O -whole-module-optimization -swift-version 5 -target arm64-apple-macos14.0 \
  -module-cache-path "$ROOT/work/swift-cache" \
  "$ROOT"/Sources/*.swift -o "$APP/Contents/MacOS/DockPin" \
  -framework AppKit -framework ApplicationServices -framework ServiceManagement
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>DockPin</string>
<key>CFBundleIdentifier</key><string>local.abu.dockpin</string>
<key>CFBundleName</key><string>DockPin</string>
<key>CFBundleDisplayName</key><string>DockPin</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>NSHumanReadableCopyright</key><string>DockPin contributors. MIT License.</string>
</dict></plist>
PLIST
xcrun swift -module-cache-path "$ROOT/work/swift-cache" \
  "$ROOT/Resources/MakeIcon.swift" "$ROOT/work/AppIcon.iconset"
iconutil -c icns "$ROOT/work/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
cp "$ROOT/README.md" "$APP/Contents/Resources/README.md"
cp "$ROOT/README.zh-CN.md" "$APP/Contents/Resources/README.zh-CN.md"
cp "$ROOT/THIRD_PARTY_NOTICES.md" "$APP/Contents/Resources/THIRD_PARTY_NOTICES.md"
cp "$ROOT/LICENSE" "$APP/Contents/Resources/LICENSE"
# Preserve the default cdhash-based requirement; never weaken it to bypass TCC.
codesign --force --sign - --identifier local.abu.dockpin "$APP"
codesign --verify --strict "$APP"
printf '%s\n' "$APP"
