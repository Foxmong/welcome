#!/bin/bash
# 블로그 파이프라인 오케스트레이터
# 비용 절약: dedup → budget → template/2단계 LLM

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/pipeline-common.sh"

MODE="${1:-}"

run_stock_pipeline() {
  local dow
  dow="$(date +%u)"
  if (( dow > 5 )); then
    log_event "info" "stock" "orchestrator" "weekend skip"
    exit 0
  fi

  log_event "info" "stock" "orchestrator" "start"
  "${SCRIPT_DIR}/tistory-cookie-check.sh" --blog stock || return 1

  retry_command stock crawl "Finnhub/DART 수집" -- bash -c 'echo ok' || {
    pause_pipeline stock; return 1
  }

  # LLM 1: flash 필터 (후보 선별만, 일 상한 내)
  if "${SCRIPT_DIR}/llm-budget.sh" check stock; then
    retry_command stock filter "flash 후보 선별" -- \
      "${SCRIPT_DIR}/openrouter-call.sh" --task filter --pipeline stock \
        --cache-key "stock-filter-$(date +%Y%m%d)" \
        --system "JSON만. 투자권유 금지." \
        --user "watchlist에서 오늘 글감 1개만 ticker,reason JSON" \
        --max-tokens 150 2>/dev/null || true
  fi

  # LLM 2: sonnet 본문 (일 상한 내)
  retry_command stock draft-writer "분석형 초안" -- bash -c 'echo ok' || {
    pause_pipeline stock; return 1
  }

  retry_command stock validate "숫자 검증" -- bash -c 'echo ok' || {
    notify_failure "error" "stock" "validate" "숫자 불일치 — 초안 폐기"
    return 1
  }

  local draft_id="stock-$(date +%Y%m%d)"
  [[ -x "${SCRIPT_DIR}/seo-enrich.sh" ]] && \
    "${SCRIPT_DIR}/seo-enrich.sh" --pipeline stock --draft-id "$draft_id" 2>/dev/null || true

  retry_command stock tistory-draft "Tistory 임시저장" -- bash -c 'echo ok' || return 1

  "${SCRIPT_DIR}/telegram-approval.sh" --pipeline stock --draft-id "$draft_id" 2>/dev/null || \
    notify_failure "info" "stock" "approval" "초안 준비" "$draft_id"

  log_event "info" "stock" "orchestrator" "done"
}

run_deal_pipeline() {
  log_event "info" "deal" "orchestrator" "start"
  "${SCRIPT_DIR}/tistory-cookie-check.sh" --blog deal || return 1

  retry_command deal crawl "에펨 핫딜 크롤" -- bash -c 'echo ok' || {
    pause_pipeline deal; return 1
  }

  # 규칙 필터 (LLM 0원): 중복·후보 상한
  if ! "${SCRIPT_DIR}/content-dedup.sh" --pipeline deals --title "샘플 핫딜"; then
    log_event "info" "deal" "dedup" "skip sample"
  fi

  retry_command deal verify-price "쿠팡 가격 검증" -- bash -c 'echo ok' || {
    notify_failure "warn" "deal" "verify-price" "가격 불일치/품절 — 건너뜀"
    return 0
  }

  # 템플릿 + flash 1회 (전체 LLM 대신)
  retry_command deal template "템플릿 렌더" -- bash -c 'echo ok' || {
    pause_pipeline deal; return 1
  }

  retry_command deal tistory-draft "Tistory 임시저장" -- bash -c 'echo ok' || return 1

  local draft_id="deal-$(date +%Y%m%d-%H%M)"
  "${SCRIPT_DIR}/telegram-approval.sh" --pipeline deals --draft-id "$draft_id" 2>/dev/null || \
    notify_failure "info" "deal" "approval" "초안 준비" "$draft_id"

  log_event "info" "deal" "orchestrator" "done"
}

case "$MODE" in
  stock) run_stock_pipeline ;;
  deal)  run_deal_pipeline ;;
  test-alert)
    notify_failure "info" "system" "test" "알림 테스트"
    notify_failure "warn" "deal" "verify-price" "가격 불일치 예시"
    notify_failure "error" "stock" "draft-writer" "OpenRouter 429 예시"
    echo "test-alert 완료"
    ;;
  *)
    echo "usage: $0 {stock|deal|test-alert}" >&2
    exit 1
    ;;
esac
