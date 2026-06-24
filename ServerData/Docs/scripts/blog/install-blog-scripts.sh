#!/bin/bash
# 맥미니 — 블로그 스크립트 설치
#
# 사용법:
#   ./setup-blog-wizard.sh      # 최초 1회 (blog.env)
#   ./install-blog-scripts.sh   # 스크립트 배포
#   ./install-blog-launchd.sh   # 스케줄 등록

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${HOME}/scripts/blog"
BLOG_ROOT="/Volumes/ServerData/Projects/blog"
CONFIG_DIR="${BLOG_ROOT}/config"

echo "==> 블로그 스크립트 설치"
mkdir -p "$TARGET" "${BLOG_ROOT}/"{stock,deals}/{raw,drafts,approved,published,logs} "$CONFIG_DIR"

SCRIPTS=(
  pipeline-common.sh telegram-alert.sh blog-orchestrator.sh
  llm-budget.sh openrouter-call.sh content-dedup.sh
  tistory-cookie-check.sh telegram-approval.sh telegram-callback-poller.sh
  deal-template-render.sh tistory-publish.sh
  setup-blog-wizard.sh install-blog-launchd.sh
)

for f in "${SCRIPTS[@]}"; do
  install -m 755 "${SCRIPT_DIR}/${f}" "${TARGET}/${f}"
  echo "    + ${f}"
done

if [[ ! -f "${CONFIG_DIR}/blog.env" ]]; then
  install -m 600 "${SCRIPT_DIR}/config/blog.env.example" "${CONFIG_DIR}/blog.env"
  echo "    + blog.env (→ setup-blog-wizard.sh 권장)"
fi

for cf in deal-template.html stock-watchlist.json.example; do
  dest="${cf%.example}"
  [[ -f "${CONFIG_DIR}/${dest}" ]] && continue
  install -m 644 "${SCRIPT_DIR}/config/${cf}" "${CONFIG_DIR}/${dest}" 2>/dev/null || \
    install -m 644 "${SCRIPT_DIR}/config/${cf}" "${CONFIG_DIR}/${cf}"
  echo "    + config/${dest}"
done

if sed --version 2>/dev/null | grep -q GNU; then
  sed -i 's/\r$//' "${TARGET}"/*.sh 2>/dev/null || true
else
  sed -i '' 's/\r$//' "${TARGET}"/*.sh 2>/dev/null || true
fi

echo ""
echo "다음:"
echo "  1. ${TARGET}/setup-blog-wizard.sh  또는 vi ${CONFIG_DIR}/blog.env"
echo "  2. ${TARGET}/blog-orchestrator.sh test-alert"
echo "  3. ${TARGET}/install-blog-launchd.sh"
