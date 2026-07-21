#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$HOME/Applications/KakaUsageOverlay.app"
PET_DEST="$HOME/.codex/pets/kaka"
PREBUILT="$ROOT/KakaUsageOverlay.app"
LABEL="com.local.kaka-usage-overlay"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
LAUNCH_AGENT="$LAUNCH_AGENTS/$LABEL.plist"
SERVICE_TARGET="gui/$(id -u)/$LABEL"

launchctl bootout "$SERVICE_TARGET" >/dev/null 2>&1 || true

mkdir -p "$HOME/Applications"

RUNNING_PIDS="$(pgrep -x KakaUsageOverlay || true)"
if [ -n "$RUNNING_PIDS" ]; then
  kill -TERM $RUNNING_PIDS
  for _ in {1..20}; do
    pgrep -x KakaUsageOverlay >/dev/null || break
    sleep 0.1
  done
fi

if [ -d "$PREBUILT" ]; then
  rm -rf "$DEST"
  ditto "$PREBUILT" "$DEST"
else
  "$ROOT/scripts/build.sh" "$DEST"
fi

mkdir -p "$PET_DEST"
cp "$ROOT/Resources/pet.json" "$PET_DEST/pet.json"
cp "$ROOT/Resources/kaka-spritesheet.webp" "$PET_DEST/spritesheet.webp"

mkdir -p "$LAUNCH_AGENTS"
cp "$ROOT/Resources/com.local.kaka-usage-overlay.plist" "$LAUNCH_AGENT"
/usr/libexec/PlistBuddy \
  -c "Set :ProgramArguments:0 $DEST/Contents/MacOS/KakaUsageOverlay" \
  "$LAUNCH_AGENT"
chmod 644 "$LAUNCH_AGENT"
plutil -lint "$LAUNCH_AGENT" >/dev/null

launchctl bootstrap "gui/$(id -u)" "$LAUNCH_AGENT"
launchctl enable "$SERVICE_TARGET"
launchctl kickstart -k "$SERVICE_TARGET"

echo "卡卡用量已安装并自动启动：$DEST"
echo "Codex v2 宠物已安装：$PET_DEST"
echo "已跟随 Codex 的“显示宠物 / 隐藏宠物”：$LAUNCH_AGENT"
