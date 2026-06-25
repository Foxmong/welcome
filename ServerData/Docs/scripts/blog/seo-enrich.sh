#!/bin/bash
# SEO 메타 보강 — 발행 전 drafts/*.meta.json 업데이트
# LLM 없이 규칙 기반 (비용 0). 메타 설명은 summary에서 추출.
#
# 사용법:
#   seo-enrich.sh --pipeline stock --draft-id 20260614-nvda

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/pipeline-common.sh"

PIPELINE=""
DRAFT_ID=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pipeline) PIPELINE="$2"; shift 2 ;;
    --draft-id) DRAFT_ID="$2"; shift 2 ;;
    *) exit 1 ;;
  esac
done

[[ -n "$PIPELINE" && -n "$DRAFT_ID" ]] || { echo "usage: $0 --pipeline stock|deals --draft-id ID" >&2; exit 1; }

META="${BLOG_ROOT}/${PIPELINE}/drafts/${DRAFT_ID}.meta.json"
[[ -f "$META" ]] || { echo "meta not found" >&2; exit 1; }

SEO_CONFIG="${BLOG_ROOT}/config/seo-keywords.json"
PUBLISHED_DIR="${BLOG_ROOT}/${PIPELINE}/published"

python3 - "$META" "$SEO_CONFIG" "$PUBLISHED_DIR" "$PIPELINE" <<'PY'
import json, re, sys
from pathlib import Path

meta_path, seo_path, pub_dir, pipeline = sys.argv[1:5]
meta = json.loads(Path(meta_path).read_text(encoding="utf-8"))

title = meta.get("title", "")
summary = meta.get("summary", "")

# 메타 설명: summary 120~160자
desc = re.sub(r"\s+", " ", summary).strip()
if len(desc) > 155:
    desc = desc[:152] + "..."
meta["meta_description"] = desc

# 태그: 제목에서 토큰 추출 + 기존
tags = set(meta.get("tags", []))
for tok in re.findall(r"[A-Z]{2,5}|[가-힣]{2,8}", title):
    if len(tok) >= 2:
        tags.add(tok)
meta["tags"] = list(tags)[:5]

# 내부 링크 후보: published 제목과 단어 겹침
suggestions = []
pub = Path(pub_dir)
if pub.exists():
    title_words = set(re.findall(r"\w+", title.lower()))
    for pm in pub.glob("*.meta.json"):
        try:
            p = json.loads(pm.read_text(encoding="utf-8"))
            pt = p.get("title", "")
            pw = set(re.findall(r"\w+", pt.lower()))
            if title_words & pw and pt != title:
                suggestions.append({
                    "title": pt,
                    "url": p.get("published_url", ""),
                })
        except (json.JSONDecodeError, OSError):
            pass
meta["internal_link_suggestions"] = suggestions[:3]

# 롱테일 키워드 힌트
if Path(seo_path).exists():
    seo = json.loads(Path(seo_path).read_text(encoding="utf-8"))
    key = "stock_longtail" if pipeline == "stock" else "deal_longtail"
    meta["seo_keyword_hints"] = seo.get(key, [])[:5]

Path(meta_path).write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps({"meta_description": meta["meta_description"], "tags": meta["tags"]}, ensure_ascii=False))
PY

log_event "info" "$PIPELINE" "seo-enrich" "ok: $DRAFT_ID"
