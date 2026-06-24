#!/bin/bash
# OpenRouter 일일 호출 예산 추적 (품질 유지 + 비용 절약)
#
# 사용법:
#   llm-budget.sh check stock     # 0=가능, 1=상한 초과
#   llm-budget.sh record stock    # 1회 차감
#   llm-budget.sh status          # 오늘 사용량 출력
#   llm-budget.sh report          # Telegram 일일 리포트

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/pipeline-common.sh"

BUDGET_FILE="${LOG_DIR}/llm-budget-$(date +%Y%m%d).json"

_get_max() {
  case "$1" in
    stock) echo "${STOCK_LLM_DAILY_MAX:-3}" ;;
    deal)  echo "${DEAL_LLM_DAILY_MAX:-8}" ;;
    stock_deep) echo "${STOCK_LLM_DEEP_WEEKLY_MAX:-2}" ;;
    *) echo "999" ;;
  esac
}

_read_count() {
  local key="$1"
  python3 - "$BUDGET_FILE" "$key" <<'PY'
import json, sys, os
path, key = sys.argv[1], sys.argv[2]
if not os.path.exists(path):
    print(0)
    raise SystemExit
with open(path) as f:
    data = json.load(f)
print(int(data.get(key, 0)))
PY
}

_record() {
  local key="$1"
  python3 - "$BUDGET_FILE" "$key" <<'PY'
import json, sys, os
path, key = sys.argv[1], sys.argv[2]
data = {}
if os.path.exists(path):
    with open(path) as f:
        data = json.load(f)
data[key] = int(data.get(key, 0)) + 1
with open(path, "w") as f:
    json.dump(data, f)
print(data[key])
PY
}

check_budget() {
  local pipeline="$1"
  local count max
  count="$(_read_count "$pipeline")"
  max="$(_get_max "$pipeline")"
  if (( count >= max )); then
    log_event "info" "$pipeline" "llm-budget" "daily limit reached ($count/$max)"
    return 1
  fi
  return 0
}

# 직접 실행 시에만 CLI 처리 (source 시 함수만 제공)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
cmd="${1:-status}"
case "$cmd" in
  check)
    check_budget "${2:?pipeline required}"
    ;;
  record)
    _record "${2:?pipeline required}" >/dev/null
    log_event "info" "${2}" "llm-budget" "recorded ($(_read_count "$2")/$(_get_max "$2"))"
    ;;
  status)
    echo "LLM budget $(date +%Y-%m-%d)"
    for p in stock deal stock_deep; do
      echo "  $p: $(_read_count "$p") / $(_get_max "$p")"
    done
    ;;
  report)
    msg="LLM 사용 $(date +%Y-%m-%d)
stock: $(_read_count stock)/$(_get_max stock)
deal: $(_read_count deal)/$(_get_max deal)
deep: $(_read_count stock_deep)/$(_get_max stock_deep)"
    if [[ -x "${SCRIPT_DIR}/telegram-alert.sh" ]]; then
      "${SCRIPT_DIR}/telegram-alert.sh" \
        --severity info --pipeline system --step llm-budget \
        --reason "일일 LLM 사용 리포트" --context "$msg"
    else
      echo "$msg"
    fi
    ;;
  *)
    echo "usage: $0 {check|record|status|report} [pipeline]" >&2
    exit 1
    ;;
esac
fi
