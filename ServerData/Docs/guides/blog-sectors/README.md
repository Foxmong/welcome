# 블로그 자동화 — 섹터별 구축 가이드

> **마스터 전략:** [BLOG-AUTOMATION-MASTER.md](../../BLOG-AUTOMATION-MASTER.md)  
> **스크립트:** [scripts/blog/](../../scripts/blog/)

섹터별로 **순서대로** 진행하세요. 각 문서는 단계·명령어·완료 기준·문제 해결을 포함합니다.

| 순서 | 섹터 | 문서 | 예상 |
|---|---|---|---|
| 0 | 개요·순서 | [00-overview.md](./00-overview.md) | 10분 |
| 1 | 기반·환경 | [01-foundation.md](./01-foundation.md) | 1~2h |
| 2 | OpenClaw·OpenRouter | [02-openclaw-openrouter.md](./02-openclaw-openrouter.md) | 1h |
| 3 | Tistory·발행 | [03-tistory-publish.md](./03-tistory-publish.md) | 2h |
| 4 | Telegram·승인 | [04-telegram-approval.md](./04-telegram-approval.md) | 30분 |
| 5 | 주식 파이프라인 | [05-stock-pipeline.md](./05-stock-pipeline.md) | 3h+ |
| 6 | 핫딜 파이프라인 | [06-deal-pipeline.md](./06-deal-pipeline.md) | 3h+ |
| 7 | LLM·API 비용 | [07-llm-cost.md](./07-llm-cost.md) | 30분 |
| 8 | 실패 알림 | [08-failure-alerts.md](./08-failure-alerts.md) | 20분 |
| 9 | SEO·상위 노출 | [09-seo-ranking.md](./09-seo-ranking.md) | 1h |
| 10 | 운영·스케줄 | [10-operations.md](./10-operations.md) | 1h |

```text
[1 기반] → [2 OpenClaw] → [3 Tistory] → [4 Telegram]
                ↓
        [5 주식] + [6 핫딜]  (병렬 가능)
                ↓
    [7 비용] [8 알림] [9 SEO] [10 운영]
```
