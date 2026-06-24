#!/bin/bash
# Telegram 승인/거절 콜백 폴링 (launchd 60초마다)
# 사용자가 버튼만 누르면 발행·거절 자동 처리
#
# 사용법:
#   telegram-callback-poller.sh once    # 1회 폴링
#   telegram-callback-poller.sh loop    # 데몬 (테스트용)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/pipeline-common.sh"

OFFSET_FILE="${BLOG_ROOT}/config/telegram-offset.txt"
mkdir -p "$(dirname "$OFFSET_FILE")"
OFFSET="$(cat "$OFFSET_FILE" 2>/dev/null || echo 0)"

[[ -n "${TELEGRAM_BOT_TOKEN:-}" ]] || exit 0

poll_once() {
  local updates
  updates="$(curl -fsS "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getUpdates?offset=${OFFSET}&timeout=10" 2>/dev/null)" || return 0

  python3 - "$updates" "$SCRIPT_DIR" "$BLOG_ROOT" <<'PY' | while IFS= read -r line; do
import json, subprocess, sys

data = json.loads(sys.argv[1])
script_dir, blog_root = sys.argv[2], sys.argv[3]
max_id = 0

for u in data.get("result", []):
    max_id = max(max_id, u["update_id"] + 1)
    cb = u.get("callback_query")
    if not cb:
        continue
    raw = cb.get("data", "")
    if ":" not in raw:
        continue
    action, pipeline, draft_id = raw.split(":", 2)
    if action == "approve":
        pub = f"{script_dir}/tistory-publish.sh"
        if os.path.exists(pub):
            subprocess.run([pub, "--approve", draft_id, "--pipeline", pipeline], check=False)
        print(f"ACTION:approve:{pipeline}:{draft_id}")
    elif action == "reject":
        import shutil
        from pathlib import Path
        for sub in ("drafts",):
            base = Path(blog_root) / pipeline / sub
            for p in base.glob(f"{draft_id}.*"):
                dest = Path(blog_root) / pipeline / "logs" / "rejected"
                dest.mkdir(parents=True, exist_ok=True)
                shutil.move(str(p), str(dest / p.name))
        print(f"ACTION:reject:{pipeline}:{draft_id}")

if max_id:
    print(f"OFFSET:{max_id}", flush=True)
PY
    if [[ "$line" == OFFSET:* ]]; then
      echo "${line#OFFSET:}" >"$OFFSET_FILE"
    elif [[ "$line" == ACTION:* ]]; then
      log_event "info" "system" "telegram-callback" "$line"
    fi
  done
}

MODE="${1:-once}"
case "$MODE" in
  once) poll_once ;;
  loop) while true; do poll_once; sleep 5; done ;;
  *) echo "usage: $0 {once|loop}" >&2; exit 1 ;;
esac
