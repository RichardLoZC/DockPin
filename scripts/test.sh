#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/work/swift-cache"
xcrun swiftc -swift-version 5 -module-cache-path "$ROOT/work/swift-cache" \
  "$ROOT/Sources/Geometry.swift" "$ROOT/Sources/PointerTakeover.swift" \
  "$ROOT/Tests/main.swift" \
  -o "$ROOT/work/geometry-tests"
"$ROOT/work/geometry-tests"
xcrun swiftc -swift-version 5 -module-cache-path "$ROOT/work/swift-cache" \
  "$ROOT/Sources/Geometry.swift" "$ROOT/Sources/PointerTakeover.swift" \
  "$ROOT/Sources/DisplayCatalog.swift" "$ROOT/Sources/LockEngine.swift" \
  "$ROOT/Tests/RuntimeChecks.swift" -o "$ROOT/work/runtime-checks" \
  -framework AppKit -framework ApplicationServices
"$ROOT/work/runtime-checks"
"$ROOT/scripts/build.sh"
"$ROOT/outputs/DockPin.app/Contents/MacOS/DockPin" --diagnose
