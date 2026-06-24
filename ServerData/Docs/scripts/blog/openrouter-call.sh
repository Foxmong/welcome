#!/bin/bash
# OpenRouter 호출 래퍼 — 예산·캐시·모델 라우팅
#
# 사용법:
#   openrouter-call.sh --task filter|outline|stock|deal|publish \
#     --pipeline stock|deal \
#     --cache-key nvda-2026-06-14 \
#     --system "..." --user "..."
#
# stdout: LLM 응답 텍스트

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/pipeline-common.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/llm-budget.sh"

TASK=""
PIPELINE="system"
CACHE_KEY=""
SYSTEM_PROMPT=""
USER_PROMPT=""
MAX_TOKENS="${LLM_MAX_TOKENS:-2048}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --task)       TASK="$2"; shift 2 ;;
    --pipeline)   PIPELINE="$2"; shift 2 ;;
    --cache-key)  CACHE_KEY="$2"; shift 2 ;;
    --system)     SYSTEM_PROMPT="$2"; shift 2 ;;
    --user)       USER_PROMPT="$2"; shift 2 ;;
    --max-tokens) MAX_TOKENS="$2"; shift 2 ;;
    *) echo "unknown: $1" >&2; exit 1 ;;
  esac
done

[[ -n "$TASK" && -n "$USER_PROMPT" ]] || { echo "need --task and --user" >&2; exit 1; }

_get_model() {
  case "$1" in
    filter)  echo "${BLOG_MODEL_FILTER:-google/gemini-2.0-flash-001}" ;;
    outline) echo "${BLOG_MODEL_OUTLINE:-anthropic/claude-3-haiku}" ;;
    stock)   echo "${BLOG_MODEL_STOCK:-anthropic/claude-sonnet-4}" ;;
    deal)    echo "${BLOG_MODEL_DEAL:-google/gemini-2.0-flash-001}" ;;
    publish) echo "${BLOG_MODEL_PUBLISH:-anthropic/claude-3-haiku}" ;;
    *)       echo "${BLOG_MODEL_DEAL:-google/gemini-2.0-flash-001}" ;;
  esac
}

MODEL="$(_get_model "$TASK")"
CACHE_DIR="${LOG_DIR}/llm-cache"
mkdir -p "$CACHE_DIR"
TTL_HOURS="${LLM_CACHE_TTL_HOURS:-24}"

if [[ -n "$CACHE_KEY" ]]; then
  CACHE_FILE="${CACHE_DIR}/${PIPELINE}-${CACHE_KEY}.txt"
  if [[ -f "$CACHE_FILE" ]]; then
  cache_age=$(( ($(date +%s) - $(stat -f %m "$CACHE_FILE" 2>/dev/null || stat -c %Y "$CACHE_FILE")) / 3600 ))
    if (( cache_age < TTL_HOURS )); then
      log_event "info" "$PIPELINE" "llm-cache" "hit: $CACHE_KEY"
      cat "$CACHE_FILE"
      exit 0
    fi
  fi
fi

# stock/deep task uses weekly deep budget
BUDGET_KEY="$PIPELINE"
[[ "$TASK" == "stock" && "${STOCK_DEEP:-0}" == "1" ]] && BUDGET_KEY="stock_deep"

if ! check_budget "$BUDGET_KEY"; then
  notify_failure "warn" "$PIPELINE" "llm-budget" "일일 LLM 상한 도달 — 건너뜀" "task=$TASK"
  exit 2
fi

[[ -n "${OPENROUTER_API_KEY:-}" ]] || {
  notify_failure "error" "$PIPELINE" "openrouter" "OPENROUTER_API_KEY 없음"
  exit 1
}

RESP="$(python3 - "$MODEL" "$MAX_TOKENS" "$SYSTEM_PROMPT" "$USER_PROMPT" <<'PY'
import json, os, sys, urllib.request

model, max_tokens, system, user = sys.argv[1:5]
api_key = os.environ.get("OPENROUTER_API_KEY", "")
base = os.environ.get("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1")

messages = []
if system:
    messages.append({"role": "system", "content": system})
messages.append({"role": "user", "content": user})

body = json.dumps({
    "model": model,
    "max_tokens": int(max_tokens),
    "messages": messages,
    "temperature": 0.3,
}).encode()

req = urllib.request.Request(
    f"{base}/chat/completions",
    data=body,
    headers={
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
        "HTTP-Referer": "https://foxmong.cc",
        "X-Title": "blog-automation",
    },
    method="POST",
)
with urllib.request.urlopen(req, timeout=120) as resp:
    data = json.load(resp)

text = data["choices"][0]["message"]["content"]
print(text)
PY
)" || {
  notify_failure "error" "$PIPELINE" "openrouter" "API 호출 실패" "task=$TASK model=$MODEL"
  exit 1
}

_record "$BUDGET_KEY" >/dev/null
log_event "info" "$PIPELINE" "openrouter" "ok task=$TASK model=$MODEL"

if [[ -n "$CACHE_KEY" ]]; then
  printf '%s' "$RESP" >"$CACHE_FILE"
fi

printf '%s' "$RESP"
