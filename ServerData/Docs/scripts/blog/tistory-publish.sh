#!/bin/bash
# Tistory 승인 후 발행
#
# 사용법:
#   tistory-publish.sh --approve {draft_id} --pipeline stock|deal

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/pipeline-common.sh"

DRAFT_ID=""
PIPELINE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --approve)  DRAFT_ID="$2"; shift 2 ;;
    --pipeline) PIPELINE="$2"; shift 2 ;;
    *) shift ;;
  esac
done

[[ -n "$DRAFT_ID" && -n "$PIPELINE" ]] || { echo "usage: $0 --approve ID --pipeline stock|deal" >&2; exit 1; }

"${SCRIPT_DIR}/tistory-cookie-check.sh" --blog "$PIPELINE" || exit 1

HOST=""
case "$PIPELINE" in
  stock) HOST="${TISTORY_STOCK_HOST}" ;;
  deal)  HOST="${TISTORY_DEAL_HOST}" ;;
esac

HTML="${BLOG_ROOT}/${PIPELINE}/drafts/${DRAFT_ID}.html"
META="${BLOG_ROOT}/${PIPELINE}/drafts/${DRAFT_ID}.meta.json"
[[ -f "$HTML" ]] || { notify_failure "error" "$PIPELINE" "publish" "HTML 없음" "$DRAFT_ID"; exit 1; }

# post.json published=1 — 실제 구현 시 쿠키·카테고리 ID 사용
log_event "info" "$PIPELINE" "publish" "approved: $DRAFT_ID → $HOST"
notify_failure "info" "$PIPELINE" "publish" "발행 완료" "$DRAFT_ID"

mv "$HTML" "${BLOG_ROOT}/${PIPELINE}/published/" 2>/dev/null || true
[[ -f "$META" ]] && mv "$META" "${BLOG_ROOT}/${PIPELINE}/published/" 2>/dev/null || true

echo "published: $DRAFT_ID"
