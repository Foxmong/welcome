#!/bin/bash
# 블로그 파이프라인 오케스트레이터 (골격)
# 실패 시 telegram-alert.sh 자동 호출 + 재시도
#
# 사용법:
#   blog-orchestrator.sh stock
#   blog-orchestrator.sh deal
#   blog-orchestrator.sh test-alert

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/pipeline-common.sh"

MODE="${1:-}"

run_stock_pipeline() {
  log_event "info" "stock" "orchestrator" "start"

  retry_command stock crawl "Finnhub/DART 수집" -- \
    bash -c 'echo ok' || { pause_pipeline stock; return 1; }

  retry_command stock draft-writer "OpenClaw stock-writer 초안" -- \
    bash -c 'echo ok' || { pause_pipeline stock; return 1; }

  retry_command stock validate "숫자 검증 (JSON vs 본문)" -- \
    bash -c 'echo ok' || {
      notify_failure "error" "stock" "validate" "숫자 불일치 — 초안 폐기" "수동 검토 필요"
      return 1
    }

  retry_command stock tistory-draft "Tistory 임시저장" -- \
    bash -c 'echo ok' || return 1

  # 성공 시 승인 알림 (별도 스크립트)
  if [[ -x "${SCRIPT_DIR}/telegram-approval.sh" ]]; then
    "${SCRIPT_DIR}/telegram-approval.sh" --pipeline stock --draft-id "latest"
  else
    notify_failure "info" "stock" "approval" "초안 준비 — 승인 대기" "telegram-approval.sh 미설치"
  fi

  log_event "info" "stock" "orchestrator" "done"
}

run_deal_pipeline() {
  log_event "info" "deal" "orchestrator" "start"

  if ! retry_command deal crawl "에펨 핫딜 크롤" -- bash -c 'echo ok'; then
    pause_pipeline deal
    return 1
  fi

  if ! retry_command deal verify-price "쿠팡 가격 검증" -- bash -c 'echo ok'; then
    notify_failure "warn" "deal" "verify-price" "가격 불일치/품절 — 건너뜀" "알림만, 파이프라인 계속"
    return 0
  fi

  retry_command deal draft-writer "OpenClaw deal-writer 초안" -- \
    bash -c 'echo ok' || { pause_pipeline deal; return 1; }

  retry_command deal tistory-draft "Tistory 임시저장" -- \
    bash -c 'echo ok' || return 1

  if [[ -x "${SCRIPT_DIR}/telegram-approval.sh" ]]; then
    "${SCRIPT_DIR}/telegram-approval.sh" --pipeline deal --draft-id "latest"
  else
    notify_failure "info" "deal" "approval" "초안 준비 — 승인 대기"
  fi

  log_event "info" "deal" "orchestrator" "done"
}

case "$MODE" in
  stock)
    run_stock_pipeline
    ;;
  deal)
    run_deal_pipeline
    ;;
  test-alert)
    notify_failure "info" "system" "test" "알림 테스트 성공"
    notify_failure "warn" "deal" "verify-price" "가격 불일치 예시" "테스트 메시지"
    notify_failure "error" "stock" "draft-writer" "OpenRouter 429 예시" "테스트 메시지"
    echo "test-alert 완료 — Telegram 확인"
    ;;
  *)
    echo "사용법: $0 {stock|deal|test-alert}" >&2
    exit 1
    ;;
esac
