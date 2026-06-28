# 08 — 실패 알림·에스컬레이션

[← 07 LLM 비용](./07-llm-cost.md) · [다음: SEO →](./09-seo-ranking.md)

## 목표

AI·크롤·발행 실패 시 Telegram 알림. critical 시 파이프라인 자동 일시정지.

---

## 흐름

```text
단계 실행
  → 실패 → 재시도 3회 (30초 간격)
  → 3회 실패 → telegram-alert.sh
  → critical → pause-{stock|deal}.flag
```

---

## 심각도

| level | 예시 | 동작 |
|---|---|---|
| info | 초안 준비, LLM 리포트 | 알림만 |
| warn | 가격 불일치, LLM 상한 | 계속 |
| error | LLM 3회 실패, 숫자 검증 실패 | 건 중단 |
| critical | 크롤 연속 실패 | **pause** |

---

## 설정 (`blog.env`)

```bash
ALERT_ENABLED=1
ALERT_COOLDOWN_SEC=3600
ALERT_MAX_RETRIES=3
ALERT_RETRY_DELAY_SEC=30
```

동일 원인 1시간 내 1회만 알림.

---

## 단계별 매핑

| 파이프라인 | 단계 | 실패 시 |
|---|---|---|
| stock | crawl | error → pause |
| stock | draft-writer | error → pause |
| stock | validate | error → 폐기 |
| deal | crawl | error → pause |
| deal | verify-price | warn → skip |
| system | openclaw | critical |

---

## 명령어

```bash
# 테스트
~/scripts/blog/blog-orchestrator.sh test-alert

# 수동 알림
~/scripts/blog/telegram-alert.sh \
  --severity error --pipeline stock --step draft-writer \
  --reason "OpenRouter 429" --context "NVDA"

# 로그
tail -50 /Volumes/ServerData/Projects/blog/logs/pipeline.log

# 파이프라인 재개
rm /Volumes/ServerData/Projects/blog/config/pause-stock.flag
rm /Volumes/ServerData/Projects/blog/config/pause-deal.flag
```

---

## 스크립트에서 사용

```bash
source ~/scripts/blog/pipeline-common.sh
retry_command stock crawl "Finnhub" -- ./crawl-stock.sh NVDA
notify_failure "error" "stock" "validate" "숫자 불일치"
pause_pipeline stock
```

---

## 완료 기준

- [ ] `test-alert` 3건 수신
- [ ] `pipeline.log` JSON 기록
- [ ] pause 플래그 생성·삭제 확인

**다음:** [09-seo-ranking.md](./09-seo-ranking.md)
