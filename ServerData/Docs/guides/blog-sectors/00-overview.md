# 00 — 개요·구축 순서

[← 섹터 목록](./README.md) · [마스터](../../BLOG-AUTOMATION-MASTER.md)

## 목표

Tistory 주식·핫딜 블로그 2개에 대해 **초안 자동 생성 → Telegram 승인 → 발행** 파이프라인을 맥미니 8GB에서 24/7 운영.

## 확정 설정

| 항목 | 값 |
|---|---|
| 플랫폼 | Tistory × 2 |
| 발행 | 승인 후 |
| 에펨 | 완전 자동 |
| LLM | OpenRouter only |
| 수익 | 애드센스 + 쿠팡 파트너스 |
| 주식 톤 | 분석형 |

## 섹터 진행 순서

### Phase A — 인프라 (필수 선행)

1. **[01-foundation](./01-foundation.md)** — VM 2GB, 폴더, wizard, 스크립트 설치
2. **[02-openclaw-openrouter](./02-openclaw-openrouter.md)** — OpenClaw + API 키
3. **[03-tistory-publish](./03-tistory-publish.md)** — 블로그 2개, 쿠키, post.json
4. **[04-telegram-approval](./04-telegram-approval.md)** — 봇, 승인 버튼, 폴링

**완료 기준:** `test-alert` 수신 + Tistory 임시저장 1회 + Telegram 승인 1회

### Phase B — 콘텐츠 파이프라인

5. **[05-stock-pipeline](./05-stock-pipeline.md)** — Finnhub/DART, 분석 초안
6. **[06-deal-pipeline](./06-deal-pipeline.md)** — 에펨, 쿠팡 API, 템플릿

**완료 기준:** 주식·핫딜 각 승인 발행 1편 이상

### Phase C — 운영·최적화

7. **[07-llm-cost](./07-llm-cost.md)** — 일일 상한, 캐시
8. **[08-failure-alerts](./08-failure-alerts.md)** — 에스컬레이션
9. **[09-seo-ranking](./09-seo-ranking.md)** — GSC, 롱테일
10. **[10-operations](./10-operations.md)** — launchd, 월 점검

## 직접 해야 하는 것 (4가지)

1. Tistory 2개 카카오 개설
2. 쿠키 최초 export
3. 애드센스·쿠팡 파트너스 신청
4. Telegram 승인/거절 클릭

## 미구현 (섹터 가이드 따라 구현)

- `crawl-stock.sh`, `crawl-fmkorea-deals.sh`, `verify-coupang-price.sh`
- `tistory-draft.sh` post.json 본구현
- OpenClaw 스킬 등록

## 새 세션 프롬프트

```text
/Volumes/ServerData/Docs/BLOG-AUTOMATION-MASTER.md
/Volumes/ServerData/Docs/guides/blog-sectors/README.md
위 문서 기준으로 블로그 자동화 섹터 [N] 진행해줘.
```
