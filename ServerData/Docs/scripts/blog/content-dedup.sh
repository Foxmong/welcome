#!/bin/bash
# 중복 콘텐츠 필터 (LLM 호출 전 — 비용 0)
#
# 사용법:
#   content-dedup.sh --pipeline deal --title "삼성 SSD 1TB 특가"
#   exit 0 = 신규, exit 1 = 중복(건너뜀)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/pipeline-common.sh"

PIPELINE=""
TITLE=""
WINDOW_DAYS="${CONTENT_DEDUP_DAYS:-7}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pipeline) PIPELINE="$2"; shift 2 ;;
    --title)    TITLE="$2"; shift 2 ;;
    --days)     WINDOW_DAYS="$2"; shift 2 ;;
    *) exit 1 ;;
  esac
done

[[ -n "$PIPELINE" && -n "$TITLE" ]] || { echo "need --pipeline --title" >&2; exit 1; }

NORM="$(python3 -c 'import re,sys; t=sys.argv[1].lower(); t=re.sub(r"[^a-z0-9가-힣]+","",t); print(t)' "$TITLE")"
[[ -n "$NORM" ]] || exit 0

FOUND="$(python3 - "$BLOG_ROOT" "$PIPELINE" "$NORM" "$WINDOW_DAYS" <<'PY'
import json, os, re, sys, time
from pathlib import Path

root, pipeline, norm, days = sys.argv[1:5]
days = int(days)
cutoff = time.time() - days * 86400
base = Path(root) / pipeline

def norm_title(s):
    return re.sub(r"[^a-z0-9가-힣]+", "", s.lower())

for sub in ("drafts", "published", "approved"):
    d = base / sub
    if not d.exists():
        continue
    for p in d.glob("*.meta.json"):
        try:
            if p.stat().st_mtime < cutoff:
                continue
            meta = json.loads(p.read_text())
            t = norm_title(meta.get("title", ""))
            if not t:
                continue
            # 유사도: 포함 관계 또는 80% 이상 겹침
            if norm in t or t in norm:
                print(p)
                raise SystemExit
            overlap = len(set(norm) & set(t)) / max(len(set(norm)), 1)
            if overlap >= 0.8:
                print(p)
                raise SystemExit
        except (json.JSONDecodeError, OSError):
            pass
PY
)" || true

if [[ -n "$FOUND" ]]; then
  log_event "info" "$PIPELINE" "dedup" "skip duplicate: $TITLE"
  exit 1
fi

exit 0
