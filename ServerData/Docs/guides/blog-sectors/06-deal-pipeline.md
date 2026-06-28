# 06 — 핫딜 파이프라인

[← 05 주식](./05-stock-pipeline.md) · [다음: LLM 비용 →](./07-llm-cost.md)

## 목표

에펨 크롤 → 중복·가격 검증 → 템플릿+flash → 승인. **LLM 최소화.**

---

## 파이프라인 전체

```text
launchd 3h 간격
  → tistory-cookie-check (deal)
  → crawl-fmkorea-deals.sh
  → content-dedup.sh (7일)
  → verify-coupang-price.sh (파트너스 API)
  → 가격 불일치 → warn + skip (LLM 없음)
  → deal-template-render.sh (HTML + flash 2문장)
  → seo-enrich.sh
  → tistory-draft.sh
  → telegram-approval.sh
```

---

## Step 1 — 쿠팡 파트너스 API

1. [partners.coupang.com](https://partners.coupang.com) 가입
2. Access Key / Secret Key → `blog.env`

```bash
COUPANG_ACCESS_KEY=...
COUPANG_SECRET_KEY=...
```

**원칙:** 에펨 링크 **재사용 금지** — 상품명으로 파트너스 API 재검색·재링크

---

## Step 2 — 에펨 크롤 (완전 자동)

`crawl-fmkorea-deals.sh` (구현):

```bash
# blog.env
FMKOREA_HOTDEAL_URL=https://www.fmkorea.com/index.php?mid=hotdeal
CRAWL_DELAY_SEC=2
```

**규칙:**

- 요청 간격 2초+
- User-Agent 명시
- **제목·조회수·키워드만** — 본문·이미지 재게시 금지
- 화제순/추천순 상위 N → `deals/raw/{timestamp}.json`

**출력 예:**

```json
{
  "title": "삼성 SSD 1TB 특가",
  "keywords": ["삼성", "SSD", "1TB"],
  "fmkorea_url": "https://...",
  "rank": 3
}
```

---

## Step 3 — 중복 필터 (LLM 0원)

```bash
~/scripts/blog/content-dedup.sh \
  --pipeline deals \
  --title "삼성 SSD 1TB 특가"
# exit 1 = 중복 skip
```

---

## Step 4 — 가격 검증

`verify-coupang-price.sh` (구현):

1. 키워드로 쿠팡 파트너스 상품 검색
2. 에펨 가격 vs API 가격 비교
3. 불일치·품절 → `notify_failure warn` + **파이프라인 skip**

---

## Step 5 — 템플릿 렌더 (비용 절약)

```bash
~/scripts/blog/deal-template-render.sh \
  --input deals/raw/20260615-001.json \
  --output deals/drafts/20260615-001.html \
  --draft-id 20260615-001
```

- HTML 골격: `config/deal-template.html`
- LLM: **소개 2~3문장만** (flash, max 200 토큰)
- 제휴 링크·고지 문구 자동

---

## Step 6 — SEO·승인

```bash
~/scripts/blog/seo-enrich.sh --pipeline deals --draft-id 20260615-001
~/scripts/blog/telegram-approval.sh --pipeline deals --draft-id 20260615-001
```

**제목 예:** `삼성 EVO 1TB 89,900원 (28%) — 쿠팡 로켓와우`

---

## Step 7 — 발행 상한

| 설정 | 기본값 |
|---|---|
| `DEAL_LLM_DAILY_MAX` | 8 |
| `DEAL_PUBLISH_DAILY_MAX` | 6 |
| `CONTENT_DEDUP_DAYS` | 7 |

---

## Step 8 — 수동 E2E

```bash
~/scripts/blog/blog-orchestrator.sh deal
```

---

## 완료 기준

- [ ] 쿠팡 API 연동·가격 검증
- [ ] 에펨 크롤 raw 1건
- [ ] dedup·템플릿 HTML
- [ ] 승인 발행 1건
- [ ] 일 6건 이하 운영

## 문제 해결

| 증상 | 해결 |
|---|---|
| 에펨 차단 | delay 증가, pause-deal.flag |
| 가격 자주 불일치 | 정규화 로직 개선 |
| 템플릿 단조로움 | 소개 문단만 LLM, 제목 다양화 |

**다음:** [07-llm-cost.md](./07-llm-cost.md)
