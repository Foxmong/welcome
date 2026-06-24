#!/bin/bash
# 블로그 자동화 초기 설정 마법사 (수동 입력 최소화)
#
# 사용법:
#   ./setup-blog-wizard.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BLOG_ROOT="/Volumes/ServerData/Projects/blog"
CONFIG="${BLOG_ROOT}/config/blog.env"
EXAMPLE="${SCRIPT_DIR}/config/blog.env.example"

mkdir -p "${BLOG_ROOT}/config"

if [[ -f "$CONFIG" ]]; then
  echo "기존 blog.env 발견 — 덮어쓰지 않습니다."
  echo "새로 만들려면: mv $CONFIG ${CONFIG}.bak"
  exit 0
fi

cp "$EXAMPLE" "$CONFIG"
chmod 600 "$CONFIG"

prompt() {
  local var="$1" label="$2" default="${3:-}"
  local val
  read -r -p "${label}${default:+ [$default]}: " val
  val="${val:-$default}"
  if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' "s|^${var}=.*|${var}=${val}|" "$CONFIG"
  else
    sed -i "s|^${var}=.*|${var}=${val}|" "$CONFIG"
  fi
}

echo "=== 블로그 자동화 설정 마법사 ==="
prompt TELEGRAM_BOT_TOKEN "Telegram Bot Token"
prompt TELEGRAM_CHAT_ID "Telegram Chat ID"
prompt TISTORY_STOCK_HOST "주식 Tistory 호스트 (xxx.tistory.com)"
prompt TISTORY_DEAL_HOST "핫딜 Tistory 호스트 (xxx.tistory.com)"
prompt OPENROUTER_API_KEY "OpenRouter API Key"

# chat_id 자동 조회 시도
TOKEN="$(grep '^TELEGRAM_BOT_TOKEN=' "$CONFIG" | cut -d= -f2-)"
if [[ -n "$TOKEN" ]]; then
  echo ""
  echo "Telegram에 봇에게 /start 를 보낸 뒤 Enter..."
  read -r _
  CID="$(curl -fsS "https://api.telegram.org/bot${TOKEN}/getUpdates" | python3 -c "
import json,sys
d=json.load(sys.stdin)
r=d.get('result',[])
print(r[-1]['message']['chat']['id'] if r else '')
" 2>/dev/null || true)"
  if [[ -n "$CID" ]]; then
    sed -i '' "s|^TELEGRAM_CHAT_ID=.*|TELEGRAM_CHAT_ID=${CID}|" "$CONFIG" 2>/dev/null || \
    sed -i "s|^TELEGRAM_CHAT_ID=.*|TELEGRAM_CHAT_ID=${CID}|" "$CONFIG"
    echo "chat_id 자동 설정: $CID"
  fi
fi

cp "${SCRIPT_DIR}/config/stock-watchlist.json.example" "${BLOG_ROOT}/config/stock-watchlist.json" 2>/dev/null || true
cp "${SCRIPT_DIR}/config/deal-template.html" "${BLOG_ROOT}/config/deal-template.html" 2>/dev/null || true

echo ""
echo "완료: $CONFIG"
echo "다음: ./install-blog-scripts.sh && ~/scripts/blog/blog-orchestrator.sh test-alert"
