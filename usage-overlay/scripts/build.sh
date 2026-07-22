#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${1:-$ROOT/dist/KakaUsageOverlay.app}"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES"

xcrun swiftc \
  "$ROOT/Sources/KakaUsageOverlay/main.swift" \
  -o "$MACOS/KakaUsageOverlay" \
  -framework Cocoa \
  -framework WebKit \
  -O

cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"
cp "$ROOT/Resources/index.html" "$RESOURCES/index.html"

codesign --force --deep --sign - "$APP" >/dev/null
echo "$APP"
