# 05 — 주식 파이프라인

[← 04 Telegram](./04-telegram-approval.md) · [다음: 핫딜 →](./06-deal-pipeline.md)

## 목표

Finnhub/DART/RSS 수집 → 분석형 초안 → 검증 → SEO → 임시저장 → 승인.

---

## 파이프라인 전체

```text
launchd 06:00 (평일)
  → tistory-cookie-check (stock)
  → crawl-stock.sh → raw/{date}-{ticker}.json
  → llm-budget check → openrouter-call (flash 필터)
  → openrouter-call (sonnet 본문) — 일 3회 상한
  → validate-numbers.sh (JSON vs 본문)
  → seo-enrich.sh
  → tistory-draft.sh (published=0)
  → telegram-approval.sh
```

실패: `retry_command` 3회 → `telegram-alert.sh` → `pause-stock.flag`

---

## Step 1 — API 키

| API | 용도 | 발급 |
|---|---|---|
| Finnhub | 시세·실적 캘린더 | finnhub.io |
| DART | 국내 공시 | opendart.fss.or.kr |
| Yahoo RSS | 해외 뉴스 | URL 고정 |
| SEC EDGAR | 미국 공시 | RSS |

`blog.env`:

```bash
FINNHUB_API_KEY=...
DART_API_KEY=...
```

---

## Step 2 — watchlist

`config/stock-watchlist.json` (example에서 복사):

```json
{
  "us": ["NVDA", "TSLA", "AAPL"],
  "kr": ["005930", "000660"],
  "etf": ["VOO", "QQQ", "069500"],
  "earnings_priority": ["NVDA", "TSLA", "005930"]
}
```

비율: 미국 70% / 국내 30% / ETF 10%

---

## Step 3 — crawl-stock.sh (구현)

**출력:** `stock/raw/20260615-NVDA.json`

```json
{
  "ticker": "NVDA",
  "price": 120.5,
  "eps": 5.16,
  "revenue":  ...,
  "sources": ["https://finnhub.io/...", "https://dart..."]
}
```

**트리거:**

- 평일 06:00 launchd
- `earnings_priority` 종목 — 실적일 ±1일 우선
- 주말: `blog-orchestrator.sh stock` 내부 skip

---

## Step 4 — LLM 2단계

### 4-1. flash 필터 (후보 1개)

```bash
~/scripts/blog/openrouter-call.sh \
  --task filter --pipeline stock \
  --cache-key "filter-$(date +%Y%m%d)" \
  --system "오늘 글감 1개만 JSON: ticker, reason, type" \
  --user "$(cat raw/latest-summary.txt)" \
  --max-tokens 150
```

### 4-2. sonnet 본문 (분석형)

```bash
~/scripts/blog/openrouter-call.sh \
  --task stock --pipeline stock \
  --cache-key "nvda-20260615" \
  --system "분석형 보고서. 숫자는 user JSON만. 투자권유 금지. 표 1개+. 면책." \
  --user "$(cat stock/raw/20260615-NVDA.json)" \
  --max-tokens 4096
```

**프롬프트 구조:**

```text
요약 → 기업개요 → 재무표 → 모멘텀 → 리스크 → 시나리오 → 면책
금지: 사세요/팔세요, AI 상투구(결론적으로, 요약하면)
```

심층(`STOCK_DEEP=1`): 실적일만, 주 2회 상한

---

## Step 5 — 숫자 검증

`validate-numbers.sh` (구현): raw JSON의 EPS·매출 등이 HTML 본문과 일치하는지 regex/파싱.

불일치 → `notify_failure error` → 초안 폐기, 발행 안 함.

---

## Step 6 — SEO·발행

```bash
DRAFT_ID="stock-$(date +%Y%m%d)-nvda"
~/scripts/blog/seo-enrich.sh --pipeline stock --draft-id "$DRAFT_ID"
~/scripts/blog/tistory-draft.sh --draft-id "$DRAFT_ID"   # 구현
~/scripts/blog/telegram-approval.sh --pipeline stock --draft-id "$DRAFT_ID"
```

**제목 롱테일 예:** `엔비디아 2026 Q1 실적 — EPS·가이던스 정리`

---

## Step 7 — 수동 E2E (MVP)

```bash
~/scripts/blog/blog-orchestrator.sh stock
```

---

## 콘텐츠 비율

| 유형 | 비율 | 글자수 |
|---|---|---|
| 종목 분석 | 40% | 1,800~5,000 |
| 실적·일정 | 30% | 800~2,000 |
| ETF·배당 | 20% | 1,800~3,000 |
| 심층 | 10% | 3,000~5,000 |

**발행 상한:** 일 2~3건 (품질·SEO)

---

## 완료 기준

- [ ] Finnhub/DART 키 동작
- [ ] `crawl-stock.sh` raw JSON 1건
- [ ] sonnet 초안 HTML 1건
- [ ] 숫자 검증 통과
- [ ] Telegram 승인 → 발행 1회

## 문제 해결

| 증상 | 해결 |
|---|---|
| LLM 상한 | `llm-budget.sh status`, 다음날 재개 |
| pause-stock.flag | `rm config/pause-stock.flag` |
| 분석 품질 낮음 | raw JSON 풍부화, sonnet만 본문에 사용 |

**다음:** [06-deal-pipeline.md](./06-deal-pipeline.md)
