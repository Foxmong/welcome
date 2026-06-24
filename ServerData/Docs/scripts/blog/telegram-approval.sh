#!/bin/bash
# Telegram 승인 요청 전송 (인라인 키보드)
#
# 사용법:
#   telegram-approval.sh --pipeline stock --draft-id 20260614-nvda

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/pipeline-common.sh"

PIPELINE=""
DRAFT_ID=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pipeline) PIPELINE="$2"; shift 2 ;;
    --draft-id) DRAFT_ID="$2"; shift 2 ;;
    *) exit 1 ;;
  esac
done

[[ -n "$PIPELINE" && -n "$DRAFT_ID" ]] || { echo "need --pipeline --draft-id" >&2; exit 1; }
[[ -n "${TELEGRAM_BOT_TOKEN:-}" && -n "${TELEGRAM_CHAT_ID:-}" ]] || {
  notify_failure "error" "$PIPELINE" "approval" "Telegram 미설정"
  exit 1
}

META="${BLOG_ROOT}/${PIPELINE}/drafts/${DRAFT_ID}.meta.json"
[[ -f "$META" ]] || META="${BLOG_ROOT}/${PIPELINE}/drafts/${DRAFT_ID}.json"
[[ -f "$META" ]] || { notify_failure "error" "$PIPELINE" "approval" "draft meta 없음" "$DRAFT_ID"; exit 1; }

read -r TITLE SUMMARY PREVIEW <<<"$(python3 - "$META" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    m = json.load(f)
print(m.get("title","").replace("\n"," ")[:80])
print(m.get("summary","").replace("\n"," ")[:120])
print(m.get("preview_url",""))
PY
)"

TEXT="[${PIPELINE} 초안]
제목: ${TITLE}
요약: ${SUMMARY}
${PREVIEW:+미리보기: ${PREVIEW}}

승인하시겠습니까?"

KEYBOARD="$(python3 - "$DRAFT_ID" "$PIPELINE" <<'PY'
import json, sys
draft_id, pipeline = sys.argv[1], sys.argv[2]
kb = {"inline_keyboard": [[
    {"text": "✅ 승인", "callback_data": f"approve:{pipeline}:{draft_id}"},
    {"text": "❌ 거절", "callback_data": f"reject:{pipeline}:{draft_id}"},
]]}
print(json.dumps(kb))
PY
)"

curl -fsS -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  -H "Content-Type: application/json" \
  -d "$(python3 -c 'import json,sys; print(json.dumps({"chat_id":sys.argv[1],"text":sys.argv[2],"reply_markup":json.loads(sys.argv[3])}))' \
    "$TELEGRAM_CHAT_ID" "$TEXT" "$KEYBOARD")" >/dev/null

log_event "info" "$PIPELINE" "approval" "sent: $DRAFT_ID"
echo "approval sent: $DRAFT_ID"
