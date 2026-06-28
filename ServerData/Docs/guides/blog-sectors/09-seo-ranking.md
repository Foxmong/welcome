# 09 — SEO·상위 노출

[← 08 실패 알림](./08-failure-alerts.md) · [다음: 운영 →](./10-operations.md)

## 목표

AI 콘텐츠 검열 리스크를 **차별화·롱테일·승인 품질**로 완화하고 검색 유입 기반 마련.

---

## 리스크 인식

| 플랫폼 | 이슈 |
|---|---|
| Google | Helpful Content, thin/spam 감점 |
| 네이버 | 중복·얇은 글 저순위 |
| 애드센스 | low-value 콘텐츠 |

**핵심:** “AI 사용”보다 **가치 없는 반복 글**이 문제.  
**차별화:** DART/Finnhub 숫자, 쿠팡 가격 검증, 사람 승인.

---

## 블로그별 전략

### 주식 (검색형)

| 전략 | 내용 |
|---|---|
| 롱테일 제목 | `삼성전자 주가` ❌ → `삼성전자 2026 Q1 실적 EPS 비교` ✅ |
| 실적 타이밍 | 발표 당일~48h |
| 데이터 | 크롤 JSON 숫자만, 출처 URL |
| 발행량 | **일 2건** 이하 |
| 내부 링크 | `seo-enrich.sh` 제안 |

### 핫딜 (속도형)

| 전략 | 내용 |
|---|---|
| 속도 | 3h 주기 |
| 정확도 | 쿠팡 API 2차 검증 |
| dedup | 7일 |
| 발행량 | **일 6건** 이하 |

---

## 기술 SEO (1회 설정)

### Google Search Console

1. [search.google.com/search-console](https://search.google.com/search-console)
2. 주식·핫딜 URL 각각 등록
3. Sitemap 제출 (티스토리 RSS/sitemap URL)

### 네이버 서치어드바이저

1. [searchadvisor.naver.com](https://searchadvisor.naver.com)
2. 사이트 등록·소유 확인
3. RSS 수집 요청

### 티스토리

- 카테고리·블로그 설명·대표 이미지
- 글마다 **대표 이미지 1장** (승인 전 10초)

---

## seo-enrich.sh (자동, LLM 0원)

```bash
~/scripts/blog/seo-enrich.sh --pipeline stock --draft-id 20260615-nvda
```

생성/갱신:

- `meta_description` (120~160자)
- `tags` (3~5개)
- `internal_link_suggestions`

---

## seo-keywords.json

`config/seo-keywords.json` (example에서 복사):

```json
{
  "stock_longtail": ["엔비디아 실적 분석 2026", "..."],
  "deal_longtail": ["쿠팡 로켓와우 특가", "..."],
  "rules": {
    "stock_posts_per_day_max": 2,
    "deal_posts_per_day_max": 6
  }
}
```

---

## 제목 공식

**주식:** `{종목} {연도} {이벤트} — {지표} 분석`  
**핫딜:** `{브랜드} {상품} {가격}원 ({할인율}) — {혜택}`

---

## 품질 게이트

```text
[자동] dedup → 검증 → seo-enrich → 임시저장
[사람] Telegram 30초 체크 → 승인/거절
```

`config/editorial-checklist.txt`  
프롬프트: AI 상투구 금지, 표 1개+, 문단 구조 랜덤화

---

## 측정·월 리뷰 (15분)

1. GSC 상위 쿼리 10개
2. `seo-keywords.json`·watchlist 업데이트
3. 클릭 0 유형 비율 축소

| 기간 | 목표 |
|---|---|
| 1~3개월 | 색인, 일 10~50 PV |
| 3~6개월 | 롱테일 1~3페이지 |
| 6개월+ | 주식 대표 키워드 1~2개 |

---

## 완료 기준

- [ ] GSC + 네이버 등록
- [ ] `seo-keywords.json` 작성
- [ ] `seo-enrich.sh` 파이프라인 연결
- [ ] editorial-checklist 습관화

**다음:** [10-operations.md](./10-operations.md)
