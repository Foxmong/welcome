# 블로그 자동화 — 마스터 전략·구축 문서

> **새 AI 세션은 이 파일만 읽으면 됩니다.** (2026-06-15 확정)  
> Tistory × 2 · OpenClaw + OpenRouter · 맥미니 8GB · 승인 후 발행

- **홈서버 핸드오프:** [00-HOME-SERVER-HANDOFF.md](./00-HOME-SERVER-HANDOFF.md)
- **섹터별 상세 구축:** [guides/blog-sectors/README.md](./guides/blog-sectors/README.md) ← **단계별 진행**
- **스크립트:** [scripts/blog/](./scripts/blog/)

---

## 0. 새 세션 프롬프트 (복사용)

```text
맥미니 블로그 자동화 이어서 진행.
/Volumes/ServerData/Docs/BLOG-AUTOMATION-MASTER.md 를 기준으로 현재 전략·상태 파악 후 작업해줘.

확정:
- Tistory 2개 (주식 분석형 / 핫딜), 승인 후 발행, 에펨 완전 자동
- OpenClaw + OpenRouter only, 맥미니 8GB, VM 2GB
- 애드센스 + 쿠팡 파트너스
- API 비용: 일일 상한·캐시·템플릿 (sonnet=주식 본문만)
- 실패 시 Telegram 에스컬레이션, SEO 롱테일·승인 품질 게이트

상태: 설계·스크립트 골격 완료, 구축 미시작
다음: setup-blog-wizard → install 스크립트 → OpenClaw 설치
```

---

## 1. 확정 설정 (사용자 답변)

| 항목 | 선택 |
|---|---|
| 플랫폼 | **Tistory** × 2 (주식 / 핫딜) |
| 발행 | **승인 후** (초안 자동 → Telegram → 승인 시 게시) |
| 에펨 크롤 | **완전 자동** |
| 수익 | **애드센스 + 쿠팡 파트너스** |
| 맥미니 RAM | **8GB** (VM **2GB** 권장) |
| 주식 톤 | **분석형** (팩트·지표·리스크, 투자 권유 금지) |
| LLM | **OpenRouter only** (로컬 모델 없음) |

---

## 2. 아키텍처

```text
┌─ 맥미니 8GB (kimi) ─────────────────────────────────────┐
│ OpenClaw Gateway (launchd)                                │
│ 크롤러 RSS/API/에펨 (launchd)                             │
│ OpenRouter — 단계별 모델 + 일일 상한                    │
│ Telegram — 승인 버튼 + 실패 알림                        │
│ ~/scripts/blog/* — 파이프라인 스크립트                    │
│ VM 2GB — Uptime Kuma + cloudflared only (블로그 X)       │
└──────────────────────────────────────────────────────────┘
         │                                    │
         ▼                                    ▼
/Volumes/ServerData/Projects/blog/    Tistory × 2
 stock/ deals/ config/ logs/           stock.xxx.tistory.com
                                       deal.xxx.tistory.com
```

**스케줄 (겹침 방지):**

| 시간 | 작업 |
|---|---|
| 03:00 | restic 백업 |
| 05:30 | Tistory 쿠키 검사 |
| 06:00 | 주식 파이프라인 (주말 skip) |
| 09~21시 / 3h | 핫딜 파이프라인 |
| 22:00 | LLM 사용량 Telegram 리포트 |
| 60초 | Telegram 승인/거절 폴링 |

---

## 3. 핵심 전략 요약

### 3-1. 파이프라인 (주식)

```text
크롤(Finnhub/DART/RSS) → flash 후보 필터 → sonnet 분석 본문(일 3회 상한)
  → 숫자 검증 → seo-enrich → Tistory 임시저장 → Telegram 승인 → 발행
실패: 재시도 3회 → telegram-alert → critical 시 pause-stock.flag
```

### 3-2. 파이프라인 (핫딜)

```text
에펨 크롤 → content-dedup(무료) → 쿠팡 API 가격검증
  → HTML 템플릿 + flash 소개 2문장 → seo-enrich → 임시저장 → 승인
가격 불일치: warn 알림 + skip (LLM 호출 없음)
```

### 3-3. API 비용 절약 (품질 유지)

| 단계 | 모델 | 상한 |
|---|---|---|
| 필터·dedup·검증 | 규칙/flash | stock 일 3 / deal 일 8 |
| 주식 본문 | **sonnet** | 일 3 |
| 심층(실적일) | sonnet | 주 2 |
| 핫딜 소개 | flash | max 200 토큰, 템플릿 나머지 |

**LLM 호출 전 무료 필터:** dedup · budget check · 가격검증 · 주말 주식 skip · 24h 캐시  
**예상 비용:** 상한 준수 시 월 **$5~15**

### 3-4. 실패 알림·에스컬레이션

| 심각도 | 동작 |
|---|---|
| warn | 알림, 파이프라인 계속 (가격 불일치 등) |
| error | 해당 건 중단 + 알림 |
| critical | `pause-{stock\|deal}.flag` + 알림 |

재개: `rm .../config/pause-stock.flag`  
중복 알림 방지: `ALERT_COOLDOWN_SEC=3600`

### 3-5. 상위 노출·SEO (AI 검열 대응)

**리스크:** AI·대량·얇은 반복 글은 Google/네이버/티스토리에서 저노출 가능.  
**대응:** “AI 사용”보다 **차별화·가치·승인 품질**이 핵심.

| 블로그 | 전략 |
|---|---|
| **주식** | 롱테일 제목, 실적 당일~48h, DART/Finnhub 숫자·출처, 일 2건 상한, 내부 링크 |
| **핫딜** | 속도(3h), 가격 정확도, 7일 dedup, 일 6건 상한 |

```text
[자동] dedup → 검증 → seo-enrich → 임시저장
[사람] Telegram 30초 체크 → 승인/거절 (품질 게이트)
```

**기술 SEO:** Search Console + 네이버 서치어드바이저 · `seo-enrich.sh` · `seo-keywords.json`  
**제목 공식:** `{종목} {연도} {이벤트} — {지표} 분석` / `{브랜드} {상품} {가격}원 ({할인율})`

**기대치:** 1~3개월 색인·소량 유입 → 3~6개월 롱테일 1~3페이지 (보장 없음)

### 3-6. 콘텐츠 비율

**주식:** 종목분석 40% · 실적 30% · ETF 20% · 심층 10% — 미국 70% / 국내 30% / ETF 10%  
**핫딜:** 300~800자, 하루 3~8건(승인 후)

**주식 프롬프트:** 숫자는 JSON만 · 출처 URL · 표 1개+ · AI 상투구 금지 · 면책 필수

---

## 4. 수동 vs 자동

| 작업 | 자동화 | 스크립트 |
|---|---|---|
| blog.env | ✅ | `setup-blog-wizard.sh` |
| Telegram chat_id | ✅ | wizard getUpdates |
| launchd | ✅ | `install-blog-launchd.sh` |
| 승인/거절 | ✅ 버튼 | `telegram-callback-poller.sh` |
| 쿠키 검사 | ✅ 05:30 | `tistory-cookie-check.sh` |
| 실패 알림 | ✅ | `telegram-alert.sh` |
| SEO 메타 | ✅ LLM 0원 | `seo-enrich.sh` |
| 중복 필터 | ✅ | `content-dedup.sh` |
| LLM 리포트 | ✅ 22:00 | `llm-budget.sh report` |

**직접 할 일 (최소 4가지):**

1. Tistory 2개 **최초 개설** (카카오)
2. 쿠키 **최초 1회** → `config/tistory-cookies.json`
3. 애드센스·쿠팡 파트너스 **신청**
4. Telegram **승인/거절** (내용 검토)

---

## 5. 구축 순서 (0→100)

> **상세 단계:** [guides/blog-sectors/](./guides/blog-sectors/) — 섹터 01~10

```bash
# 맥미니
cd /Volumes/ServerData/Docs/scripts/blog
./setup-blog-wizard.sh
./install-blog-scripts.sh
~/scripts/blog/blog-orchestrator.sh test-alert
./install-blog-launchd.sh

# OpenClaw
curl -fsSL https://openclaw.ai/install.sh | bash
openclaw onboard --install-daemon

# VM RAM 2GB
VBoxManage modifyvm centos-server --memory 2048
```

### 체크리스트

**0~20 기반:** wizard · install · launchd · OpenClaw · VM 2GB · Tistory 2개 · blog 폴더  
**20~50 주식 MVP:** Finnhub/DART · crawl · sonnet 초안 1편 · 승인 발행 1회  
**50~70 주식 자동:** watchlist · 숫자검증 · launchd 06:00  
**70~90 핫딜:** 쿠팡 API · 에펨 크롤 · dedup · 템플릿  
**90~100 운영:** GSC·네이버 · seo-keywords · 쿠키 루틴 · GSC 월 리뷰

---

## 6. Tistory 발행 (승인 후)

> Tistory 공식 API **2023 종료** → `post.json` + 쿠키 (비공식)

1. HTML 초안 → `published: 0` 임시저장  
2. Telegram [승인]/[거절]  
3. 승인 → `published: 1` (`tistory-publish.sh --approve`)

쿠키 JSON 예: `config/tistory-cookies.json` — 호스트별 `TSSESSION=...`

---

## 7. 스크립트 목록

템플릿: `ServerData/Docs/scripts/blog/` → 설치 후 `~/scripts/blog/`

| 스크립트 | 역할 |
|---|---|
| `setup-blog-wizard.sh` | blog.env 마법사 |
| `install-blog-scripts.sh` | 맥미니 배포 |
| `install-blog-launchd.sh` | launchd 5종 |
| `blog-orchestrator.sh` | stock/deal 파이프라인 |
| `pipeline-common.sh` | 재시도·로그·notify |
| `telegram-alert.sh` | 실패 알림 |
| `telegram-approval.sh` | 승인 요청 |
| `telegram-callback-poller.sh` | 버튼 처리 |
| `openrouter-call.sh` | LLM (예산·캐시) |
| `llm-budget.sh` | 일일 상한 |
| `content-dedup.sh` | 중복 필터 |
| `seo-enrich.sh` | 메타·태그·내부링크 |
| `deal-template-render.sh` | 핫딜 템플릿 |
| `tistory-cookie-check.sh` | 쿠키 검사 |
| `tistory-publish.sh` | 승인 후 발행 |

**설정:** `Projects/blog/config/blog.env` · `seo-keywords.json` · `stock-watchlist.json` · `editorial-checklist.txt` · `deal-template.html`

**launchd:** blog-stock · blog-deal · telegram-poller · cookie-check · llm-report

---

## 8. 경로

```text
/Volumes/ServerData/Docs/BLOG-AUTOMATION-MASTER.md     ← 이 파일
/Volumes/ServerData/Docs/scripts/blog/                 ← 스크립트 템플릿
/Volumes/ServerData/Projects/blog/                     ← 데이터·초안·로그
/Users/kimi/scripts/blog/                              ← 설치 후 실행 경로
```

---

## 9. 리스크·문제 해결

| 리스크/증상 | 해결 |
|---|---|
| Tistory 401 | 쿠키 갱신 (`tistory-cookies.json`) |
| OpenRouter 비용 | `llm-budget.sh status`, Limits 설정 |
| 파이프라인 멈춤 | `rm config/pause-*.flag` |
| 검색 노출 없음 | 롱테일·GSC·발행 상한·본문 차별화 (§3-5) |
| AI 느낌 | 거절 후 수동 수정, 상투구 금지 |
| 에펨 차단 | `CRAWL_DELAY_SEC` 증가 |
| Docker+SSHFS | 블로그는 맥에서 — VM Docker bind에 SSHFS 금지 |
| 8GB 느림 | VM 2GB, 03:00 백업과 크롤 시간 분리 |

---

## 10. 미구현 (구축 시 작업)

- [ ] `crawl-stock.sh` · `crawl-fmkorea-deals.sh` · `verify-coupang-price.sh`
- [ ] `tistory-draft.sh` post.json 본구현
- [ ] OpenClaw 스킬 등록 (stock-daily / deal-scan)
- [ ] Tistory 블로그 호스트명 확정
- [ ] 크롤러·발행 E2E 검증

---

## 11. 변경 이력

| 날짜 | 내용 |
|---|---|
| 2026-06-15 | 최초 전략 확정 (Tistory, 승인, 에펨, 8GB, 분석형) |
| 2026-06-15 | 실패 알림, API 비용 절약, 수동작업 자동화 |
| 2026-06-15 | 상위 노출·SEO 전략 |
| 2026-06-15 | **섹터별 상세 가이드** `guides/blog-sectors/` (GitHub) |

---

*맥미니 홈서버 전체: [00-HOME-SERVER-HANDOFF.md](./00-HOME-SERVER-HANDOFF.md)*
