#!/bin/bash
# launchd 에이전트 설치 (맥미니)
#
# 사용법:
#   ./install-blog-launchd.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS="${HOME}/Library/LaunchAgents"
mkdir -p "$AGENTS" /Volumes/ServerData/Projects/blog/logs

for plist in com.kimi.blog-stock com.kimi.blog-deal com.kimi.blog-telegram-poller \
             com.kimi.blog-cookie-check com.kimi.blog-llm-report; do
  src="${SCRIPT_DIR}/launchd/${plist}.plist"
  dst="${AGENTS}/${plist}.plist"
  cp "$src" "$dst"
  launchctl bootout "gui/$(id -u)/${plist}" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$dst"
  launchctl enable "gui/$(id -u)/${plist}"
  echo "    + ${plist}"
done

echo ""
echo "확인: launchctl list | grep com.kimi.blog"
