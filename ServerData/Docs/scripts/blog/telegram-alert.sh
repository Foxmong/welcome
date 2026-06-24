#!/bin/bash
# Telegram 실패·에스컬레이션 알림
#   telegram-alert.sh --severity error --pipeline stock --step draft-writer \
#     --reason "OpenRouter 429" --context "NVDA Q1 draft"
#
# severity: info | warn | error | critical

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BLOG_ROOT="${BLOG_ROOT:-/Volumes/ServerData/Projects/blog}"
ENV_FILE="${BLOG_ENV:-${BLOG_ROOT}/config/blog.env}"

if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

SEVERITY="error"
PIPELINE="system"
STEP="unknown"
REASON=""
CONTEXT=""

usage() {
  sed -n '2,8p' "$0"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --severity) SEVERITY="$2"; shift 2 ;;
    --pipeline) PIPELINE="$2"; shift 2 ;;
    --step)     STEP="$2"; shift 2 ;;
    --reason)   REASON="$2"; shift 2 ;;
    --context)  CONTEXT="$2"; shift 2 ;;
    -h|--help)  usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

if [[ -z "$REASON" ]]; then
  echo "오류: --reason 필수" >&2
  exit 1
fi

if [[ -z "${TELEGRAM_BOT_TOKEN:-}" || -z "${TELEGRAM_CHAT_ID:-}" ]]; then
  echo "[telegram-alert] TELEGRAM_BOT_TOKEN 또는 TELEGRAM_CHAT_ID 없음 — 콘솔만 출력" >&2
  echo "[$SEVERITY] $PIPELINE/$STEP: $REASON ${CONTEXT:+( $CONTEXT )}" >&2
  exit 0
fi

icon() {
  case "$SEVERITY" in
    info)     echo "ℹ️" ;;
    warn)     echo "⚠️" ;;
    error)    echo "❌" ;;
    critical) echo "🚨" ;;
    *)        echo "❓" ;;
  esac
}

HOSTNAME_SHORT="$(hostname -s 2>/dev/null || hostname)"
TS="$(date '+%Y-%m-%d %H:%M:%S %Z')"

TEXT="$(icon) *블로그 자동화 알림*
*심각도:* ${SEVERITY}
*파이프라인:* ${PIPELINE}
*단계:* ${STEP}
*호스트:* ${HOSTNAME_SHORT}
*시각:* ${TS}

*원인:* ${REASON}"

if [[ -n "$CONTEXT" ]]; then
  TEXT="${TEXT}

*상세:* ${CONTEXT}"
fi

if [[ "$SEVERITY" == "error" || "$SEVERITY" == "critical" ]]; then
  TEXT="${TEXT}

조치: 맥미니에서 로그 확인
tail -50 ${BLOG_ROOT}/logs/pipeline.log"
fi

curl -fsS -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  -d "chat_id=${TELEGRAM_CHAT_ID}" \
  --data-urlencode "text=${TEXT}" >/dev/null || {
  echo "[telegram-alert] API 실패" >&2
  exit 1
}

echo "[telegram-alert] sent: $SEVERITY $PIPELINE/$STEP"
