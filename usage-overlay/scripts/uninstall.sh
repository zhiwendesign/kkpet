#!/usr/bin/env bash
set -euo pipefail

LABEL="com.local.kaka-usage-overlay"
DEST="$HOME/Applications/KakaUsageOverlay.app"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/$LABEL.plist"
SERVICE_TARGET="gui/$(id -u)/$LABEL"

launchctl bootout "$SERVICE_TARGET" >/dev/null 2>&1 || true
pkill -x KakaUsageOverlay 2>/dev/null || true
rm -f "$LAUNCH_AGENT"
rm -rf "$DEST"

echo "已卸载卡卡用量挂件（Codex 宠物本体未删除）"
