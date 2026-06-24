#!/bin/bash
# 블로그 파이프라인 공통 함수 — 로그, 재시도, 실패 알림
# 사용: source "$(dirname "$0")/pipeline-common.sh"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BLOG_ROOT="${BLOG_ROOT:-/Volumes/ServerData/Projects/blog}"
ENV_FILE="${BLOG_ENV:-${BLOG_ROOT}/config/blog.env}"

if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

ALERT_ENABLED="${ALERT_ENABLED:-1}"
ALERT_COOLDOWN_SEC="${ALERT_COOLDOWN_SEC:-3600}"
ALERT_MAX_RETRIES="${ALERT_MAX_RETRIES:-3}"
ALERT_RETRY_DELAY_SEC="${ALERT_RETRY_DELAY_SEC:-30}"

LOG_DIR="${BLOG_ROOT}/logs"
ALERT_STATE_DIR="${BLOG_ROOT}/logs/alert-state"
PIPELINE_LOG="${LOG_DIR}/pipeline.log"

mkdir -p "$LOG_DIR" "$ALERT_STATE_DIR"

log_event() {
  local level="$1"
  local pipeline="$2"
  local step="$3"
  local message="$4"
  local ts
  ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  printf '{"ts":"%s","level":"%s","pipeline":"%s","step":"%s","message":%s}\n' \
    "$ts" "$level" "$pipeline" "$step" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$message")" \
    >>"$PIPELINE_LOG"
}

is_pipeline_paused() {
  local pipeline="$1"
  if [[ -f "${BLOG_ROOT}/config/pause-${pipeline}.flag" ]]; then
    return 0
  fi
  case "$pipeline" in
    stock) [[ "${PIPELINE_STOCK_PAUSED:-0}" == "1" ]] ;;
    deal)  [[ "${PIPELINE_DEAL_PAUSED:-0}" == "1" ]] ;;
    *)     return 1 ;;
  esac
}

_alert_fingerprint() {
  local pipeline="$1"
  local step="$2"
  local reason="$3"
  echo "${pipeline}:${step}:${reason}" | shasum -a 256 | awk '{print $1}'
}

should_suppress_alert() {
  local pipeline="$1"
  local step="$2"
  local reason="$3"
  local fp
  fp="$(_alert_fingerprint "$pipeline" "$step" "$reason")"
  local state_file="${ALERT_STATE_DIR}/${fp}"
  if [[ -f "$state_file" ]]; then
    local last_ts now
    last_ts="$(cat "$state_file")"
    now="$(date +%s)"
    if (( now - last_ts < ALERT_COOLDOWN_SEC )); then
      return 0
    fi
  fi
  return 1
}

mark_alert_sent() {
  local pipeline="$1"
  local step="$2"
  local reason="$3"
  local fp
  fp="$(_alert_fingerprint "$pipeline" "$step" "$reason")"
  date +%s >"${ALERT_STATE_DIR}/${fp}"
}

notify_failure() {
  local severity="${1:-error}"
  local pipeline="${2:-system}"
  local step="${3:-unknown}"
  local reason="${4:-unknown error}"
  local context="${5:-}"

  log_event "$severity" "$pipeline" "$step" "${reason}${context:+ | $context}"

  if [[ "$ALERT_ENABLED" != "1" ]]; then
    return 0
  fi

  if should_suppress_alert "$pipeline" "$step" "$reason"; then
    log_event "info" "$pipeline" "$step" "alert suppressed (cooldown): $reason"
    return 0
  fi

  local alert_script="${SCRIPT_DIR}/telegram-alert.sh"
  if [[ -x "$alert_script" ]]; then
    "$alert_script" \
      --severity "$severity" \
      --pipeline "$pipeline" \
      --step "$step" \
      --reason "$reason" \
      ${context:+--context "$context"}
    mark_alert_sent "$pipeline" "$step" "$reason"
  else
    echo "[WARN] telegram-alert.sh not found — $pipeline/$step: $reason" >&2
  fi
}

# retry_command <pipeline> <step> <description> -- command args...
retry_command() {
  local pipeline="$1"
  local step="$2"
  local description="$3"
  shift 3

  if [[ "${1:-}" == "--" ]]; then
    shift
  fi

  if is_pipeline_paused "$pipeline"; then
    notify_failure "warn" "$pipeline" "$step" "pipeline paused — skipped: $description"
    return 2
  fi

  local attempt=1
  local max="${ALERT_MAX_RETRIES}"
  local delay="${ALERT_RETRY_DELAY_SEC}"
  local output=""
  local exit_code=0

  while (( attempt <= max )); do
    set +e
    output="$("$@" 2>&1)"
    exit_code=$?
    set -e

    if [[ $exit_code -eq 0 ]]; then
      log_event "info" "$pipeline" "$step" "ok: $description (attempt $attempt)"
      return 0
    fi

    log_event "warn" "$pipeline" "$step" "retry $attempt/$max failed ($exit_code): $description — ${output:0:200}"
    if (( attempt < max )); then
      sleep "$delay"
    fi
    ((attempt++))
  done

  notify_failure "error" "$pipeline" "$step" "$description failed after ${max} attempts" "${output:0:500}"
  return "$exit_code"
}

pause_pipeline() {
  local pipeline="$1"
  local flag_file="${BLOG_ROOT}/config/pause-${pipeline}.flag"
  touch "$flag_file"
  notify_failure "critical" "$pipeline" "orchestrator" "pipeline auto-paused after repeated failures" "remove $flag_file to resume"
}

is_paused_by_flag() {
  local pipeline="$1"
  [[ -f "${BLOG_ROOT}/config/pause-${pipeline}.flag" ]]
}
