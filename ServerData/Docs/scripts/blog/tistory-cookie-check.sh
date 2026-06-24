#!/bin/bash
# Tistory 쿠키 유효성 검사 (발행 전 자동)
#
# 사용법:
#   tistory-cookie-check.sh --blog stock|deal|all

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/pipeline-common.sh"

BLOG="all"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --blog) BLOG="$2"; shift 2 ;;
    *) shift ;;
  esac
done

COOKIE_FILE="${BLOG_ROOT}/config/tistory-cookies.json"
[[ -f "$COOKIE_FILE" ]] || {
  notify_failure "error" "system" "tistory-cookie" "쿠키 파일 없음" "$COOKIE_FILE"
  exit 1
}

_check_host() {
  local host="$1"
  local label="$2"
  local code
  code="$(python3 - "$host" "$COOKIE_FILE" <<'PY'
import json, sys, urllib.request

host, cookie_path = sys.argv[1], sys.argv[2]
with open(cookie_path) as f:
    cookies = json.load(f)

def build_cookie(c):
    if isinstance(c, dict):
        return "; ".join(f"{k}={v}" for k, v in c.items())
    return str(c)

cookie = build_cookie(cookies.get(host, cookies.get("default", "")))
url = f"https://{host}/manage/newpost"
req = urllib.request.Request(url, headers={
    "Cookie": cookie,
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
})
try:
    with urllib.request.urlopen(req, timeout=20) as resp:
        body = resp.read(8000).decode("utf-8", errors="replace")
        if "login" in resp.geturl() or "카카오" in body and "로그인" in body:
            print("401")
        else:
            print("200")
except Exception:
    print("401")
PY
)"
  if [[ "$code" != "200" ]]; then
    notify_failure "error" "$label" "tistory-cookie" "쿠키 만료 또는 로그인 필요" "$host"
    return 1
  fi
  log_event "info" "$label" "tistory-cookie" "ok: $host"
  return 0
}

fail=0
case "$BLOG" in
  stock) _check_host "${TISTORY_STOCK_HOST}" stock || fail=1 ;;
  deal)  _check_host "${TISTORY_DEAL_HOST}" deal || fail=1 ;;
  all)
    _check_host "${TISTORY_STOCK_HOST}" stock || fail=1
    _check_host "${TISTORY_DEAL_HOST}" deal || fail=1
    ;;
  *) echo "usage: $0 --blog stock|deal|all" >&2; exit 1 ;;
esac
exit "$fail"
