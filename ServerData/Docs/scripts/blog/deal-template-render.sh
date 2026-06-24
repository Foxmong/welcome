#!/bin/bash
# 핫딜 템플릿 렌더 (LLM 최소화 — flash 1회만)
# 상품명·가격·링크는 API/크롤 데이터로 채움, 소개 문단만 LLM
#
# 사용법:
#   deal-template-render.sh --input raw/deal-xxx.json --output drafts/xxx.html

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/pipeline-common.sh"

INPUT=""
OUTPUT=""
DRAFT_ID=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input)  INPUT="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --draft-id) DRAFT_ID="$2"; shift 2 ;;
    *) exit 1 ;;
  esac
done

[[ -f "$INPUT" ]] || { echo "input not found" >&2; exit 1; }
TEMPLATE="${BLOG_ROOT}/config/deal-template.html"
[[ -f "$TEMPLATE" ]] || TEMPLATE="${SCRIPT_DIR}/config/deal-template.html"

read -r PRODUCT PRICE ORIGIN LINK TITLE <<<"$(python3 - "$INPUT" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    d = json.load(f)
print(d.get("product",""))
print(d.get("price",""))
print(d.get("original_price",""))
print(d.get("affiliate_link",""))
print(d.get("title", d.get("product","")))
PY
)"

# LLM: 소개 2~3문장만 (flash, 짧은 프롬프트)
INTRO=""
if [[ -x "${SCRIPT_DIR}/openrouter-call.sh" ]]; then
  INTRO="$( "${SCRIPT_DIR}/openrouter-call.sh" \
    --task deal --pipeline deal \
    --cache-key "deal-intro-$(echo "$PRODUCT" | shasum | awk '{print $1}')" \
    --system "핫딜 블로그 소개 문단만 2~3문장. 과장 금지. 가격은 제공값만." \
    --user "상품: ${PRODUCT}, 가격: ${PRICE}원, 정가: ${ORIGIN}원" \
    --max-tokens 200 2>/dev/null)" || INTRO="가격 대비 괜찮은 상품으로 보입니다. 구매 전 최종 가격을 확인하세요."
else
  INTRO="가격 대비 괜찮은 상품으로 보입니다. 구매 전 최종 가격을 확인하세요."
fi

python3 - "$TEMPLATE" "$OUTPUT" "$TITLE" "$PRODUCT" "$PRICE" "$ORIGIN" "$LINK" "$INTRO" <<'PY'
import sys
from pathlib import Path

tpl, out, title, product, price, origin, link, intro = sys.argv[1:9]
html = Path(tpl).read_text()
html = html.replace("{{TITLE}}", title)
html = html.replace("{{PRODUCT}}", product)
html = html.replace("{{PRICE}}", price)
html = html.replace("{{ORIGIN}}", origin)
html = html.replace("{{LINK}}", link)
html = html.replace("{{INTRO}}", intro)
Path(out).parent.mkdir(parents=True, exist_ok=True)
Path(out).write_text(html)
PY

META="${OUTPUT%.html}.meta.json"
python3 - "$META" "$TITLE" "$INTRO" "$DRAFT_ID" <<'PY'
import json, sys
path, title, summary, draft_id = sys.argv[1:5]
json.dump({"title": title, "summary": summary[:120], "draft_id": draft_id}, open(path,"w"), ensure_ascii=False, indent=2)
PY

log_event "info" "deal" "template-render" "ok: $TITLE"
