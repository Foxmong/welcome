#!/bin/bash
# 맥미니 — 블로그 스크립트 설치
# Docs → ~/scripts/blog + ServerData/Projects/blog/config
#
# 사용법 (맥미니):
#   cd /Volumes/ServerData/Docs/scripts/blog
#   chmod +x install-blog-scripts.sh
#   ./install-blog-scripts.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${HOME}/scripts/blog"
BLOG_ROOT="/Volumes/ServerData/Projects/blog"
CONFIG_DIR="${BLOG_ROOT}/config"

echo "==> 블로그 스크립트 설치"
echo "    소스: ${SCRIPT_DIR}"
echo "    대상: ${TARGET}"

mkdir -p "$TARGET" "${BLOG_ROOT}/"{stock,deals}/{raw,drafts,approved,published,logs} "$CONFIG_DIR"

for f in pipeline-common.sh telegram-alert.sh blog-orchestrator.sh; do
  install -m 755 "${SCRIPT_DIR}/${f}" "${TARGET}/${f}"
  echo "    + ${f}"
done

if [[ ! -f "${CONFIG_DIR}/blog.env" ]]; then
  install -m 600 "${SCRIPT_DIR}/config/blog.env.example" "${CONFIG_DIR}/blog.env"
  echo "    + blog.env (example → 편집 필요)"
else
  echo "    = blog.env 유지 (기존 파일)"
fi

# CRLF 방지 (Mac에서 Windows 복사 시)
if sed --version 2>/dev/null | grep -q GNU; then
  sed -i 's/\r$//' "${TARGET}"/*.sh 2>/dev/null || true
else
  sed -i '' 's/\r$//' "${TARGET}"/*.sh 2>/dev/null || true
fi

echo ""
echo "다음 단계:"
echo "  1. vi ${CONFIG_DIR}/blog.env   # Telegram, API 키"
echo "  2. ${TARGET}/telegram-alert.sh --severity info --pipeline system --step install --reason '설치 테스트'"
echo "  3. launchd 등록 (가이드 Phase 7)"
