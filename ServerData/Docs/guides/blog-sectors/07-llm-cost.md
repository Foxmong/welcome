# 07 — LLM·API 비용 관리

[← 06 핫딜](./06-deal-pipeline.md) · [다음: 실패 알림 →](./08-failure-alerts.md)

## 목표

OpenRouter 비용을 **월 $5~15** 수준으로 유지하면서 주식 분석 품질(sonnet) 유지.

---

## 원칙

> LLM은 **글 쓰기**에만. 필터·검증·중복·SEO 메타는 **스크립트**.

---

## 모델·상한표

| 단계 | 모델 | env 변수 | 상한 |
|---|---|---|---|
| 필터 | flash | `BLOG_MODEL_FILTER` | stock 일 3 |
| 아웃라인 | haiku | `BLOG_MODEL_OUTLINE` | 포함 |
| 주식 본문 | **sonnet** | `BLOG_MODEL_STOCK` | **일 3** |
| 심층 | sonnet | + `STOCK_DEEP=1` | **주 2** |
| 핫딜 소개 | flash | `BLOG_MODEL_DEAL` | deal 일 8 |
| 발행 메타 | haiku | `BLOG_MODEL_PUBLISH` | 거의 없음 |

`blog.env`:

```bash
STOCK_LLM_DAILY_MAX=3
DEAL_LLM_DAILY_MAX=8
STOCK_LLM_DEEP_WEEKLY_MAX=2
LLM_CACHE_TTL_HOURS=24
LLM_MAX_TOKENS=2048
```

---

## LLM 호출 전 무료 필터

| # | 필터 | 스크립트 |
|---|---|---|
| 1 | 중복 제목 | `content-dedup.sh` |
| 2 | 일일 상한 | `llm-budget.sh check` |
| 3 | 쿠팡 가격 불일치 | `verify-coupang-price.sh` |
| 4 | 주말 주식 | `blog-orchestrator.sh` skip |
| 5 | 24h 캐시 | `openrouter-call.sh --cache-key` |

---

## 사용법

```bash
# 상한 확인
~/scripts/blog/llm-budget.sh status

# 호출 전
~/scripts/blog/llm-budget.sh check stock || exit 0

# 호출 (자동 record)
~/scripts/blog/openrouter-call.sh --task stock --pipeline stock ...

# 일일 리포트 (22:00 launchd)
~/scripts/blog/llm-budget.sh report
```

상한 초과 시: `warn` 알림 + 해당 건 skip (다음날 자동 재개)

---

## OpenRouter 대시보드

1. **Limits** — 월 $20 등 soft cap
2. Usage — 주간 확인
3. `llm-budget.sh report`와 교차 검증

---

## 비용 시나리오

| 패턴 | 월 호출 | 대략 |
|---|---|---|
| 상한 준수 | ~210 | $5~15 |
| 전량 sonnet | 500+ | $50+ |

---

## 완료 기준

- [ ] `blog.env` 상한 설정
- [ ] OpenRouter Limits 설정
- [ ] `llm-budget.sh status` 동작
- [ ] 22:00 리포트 launchd 등록

**다음:** [08-failure-alerts.md](./08-failure-alerts.md)
