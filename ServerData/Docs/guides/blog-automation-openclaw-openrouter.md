# 블로그 자동 발행 구축 가이드 (0→100)

> **OpenClaw 설치**부터 **Tistory 승인 발행**까지 전체 절차  
> **LLM:** OpenRouter only (로컬 모델 없음)  
> **맥미니:** RAM **8GB** + 홈서버 VM 동시 운영

---

## 확정 설정 (사용자 답변 반영)

| 항목 | 선택 |
|---|---|
| 플랫폼 | **Tistory** × 2 (주식 / 핫딜) |
| 발행 | **승인 후** (자동 초안 → 알림 → 승인 시 게시) |
| 에펨 크롤 | **완전 자동** (후보→검증→초안까지) |
| 수익 | **애드센스 + 쿠팡 파트너스** |
| 맥미니 RAM | **8GB** |
| 주식 톤 | **분석형** (팩트·지표·리스크 중심) |

---

## 0. 전체 아키텍처

```text
┌─────────────────────────────────────────────────────────────┐
│ 맥미니 8GB (kimi)                                            │
│  ├─ OpenClaw Gateway (launchd 24/7)                          │
│  ├─ 크롤러 (RSS/API/에펨) — launchd/cron                    │
│  ├─ OpenRouter (단계별 모델)                                 │
│  ├─ 승인 봇 (Telegram) + 실패 알림 (telegram-alert.sh)      │
│  └─ Tistory 발행 스크립트 (승인 후)                          │
│  VirtualBox VM 2~4GB — Uptime Kuma, Tunnel (블로그 X)       │
└─────────────────────────────────────────────────────────────┘
         │                              │
         ▼                              ▼
  ServerData/Projects/blog/     Tistory × 2
  (raw, drafts, logs)           stock.xxx.tistory.com
                                deal.xxx.tistory.com
```

**8GB 핵심:** OpenClaw·크롤은 **맥에서**, VM은 **가볍게** (아래 §2-4).

### 한눈에 보는 실행 순서

| 순서 | 작업 | 가이드 위치 |
|---|---|---|
| 0 | 구축 전 검토 | Phase 0 |
| 1 | OpenClaw 설치 + OpenRouter + launchd | Phase 1 |
| 2 | VM RAM 2GB, 스케줄 분리 | Phase 2 |
| 3 | Tistory 2개 + 폴더·`blog.env` | Phase 3 |
| 4 | Telegram 승인 + Tistory 임시저장 | Phase 4 |
| 4-B | **실패 알림·에스컬레이션** | Phase 4-B |
| 5 | OpenClaw 에이전트 4+1 | Phase 5 |
| 6 | 주식·핫딜 크롤 파이프라인 | Phase 6 |
| 7 | launchd 스케줄 등록 | Phase 7 |
| 8 | 0→100 체크리스트 따라 운영 | Phase 8 |
| 9 | 콘텐츠 비율·글자수 | Phase 9 |
| 10 | **상위 노출·검색 전략** | Phase 10 |

---

## Phase 0 — 구축 전 최종 검토 (2026-06-15)

구축 들어가기 전 설계 점검 결과입니다.

### 0-1. 보완 완료 항목

| 항목 | 이전 | 보완 |
|---|---|---|
| Phase 5 제목 누락 | 5-1만 존재 | Phase 5 헤더 복구 |
| AI 실패 알림 | 승인만 | Phase 4-B + `telegram-alert.sh` |
| API 비용 통제 | 모델만 지정 | 일일 상한·캐시·2단계 라우팅 (Phase 5-C) |
| 수동 작업 | 쿠키·launchd·승인 | 자동화 스크립트 (Phase 3-B) |
| 핫딜 LLM 낭비 | 전체 본문 생성 | 템플릿 + flash 1문단 |
| 중복 글 | 미정 | `content-dedup.sh` (LLM 전) |

### 0-2. 구축 전 사용자 확인 (최소)

| # | 작업 | 자동화 |
|---|---|---|
| 1 | Tistory 2개 **개설** (카카오) | ❌ 최초 1회만 |
| 2 | OpenRouter·Telegram·API 키 | ✅ `setup-blog-wizard.sh` |
| 3 | Tistory 쿠키 **최초 1회** export | ⚠️ 이후 자동 검사·알림 |
| 4 | 애드센스·쿠팡 파트너스 **신청** | ❌ 심사 대기 (승인 후 스크립트 삽입) |
| 5 | 스크립트·launchd 설치 | ✅ install 스크립트 2개 |
| 6 | **승인 버튼** 클릭 | ✅ Telegram 인라인 (폴링 자동) |

### 0-3. 리스크·완화

| 리스크 | 완화 |
|---|---|
| Tistory 비공식 API 변경 | 쿠키 검사 05:30 + 발행 전 재검사 |
| OpenRouter 비용 초과 | 일일 상한 + 22:00 리포트 |
| 에펨 IP 차단 | delay 2s+, pause 플래그 |
| 8GB 메모리 부족 | VM 2GB, LLM 시간 분산 |
| 분석 품질 저하 | sonnet은 주식 본문만, 실적일·심층만 deep |
| **AI 콘텐츠 검열·저노출** | 차별화 데이터·승인 게이트·롱테일 SEO (Phase 10) |

---

## Phase 1 — OpenClaw 설치 (맥미니)

### 1-1. 사전 준비

| 항목 | 내용 |
|---|---|
| 계정 | [OpenRouter](https://openrouter.ai) API 키 |
| 계정 | [Telegram Bot](https://t.me/BotFather) (승인 알림용, 권장) |
| 키 보관 | `~/.openclaw/` 또는 1Password — Git 금지 |

### 1-2. 설치 (공식 원라이너)

**맥미니 터미널 (kimi):**

```bash
curl -fsSL https://openclaw.ai/install.sh | bash
```

- Node 22+ 자동 설치
- 대화형 **onboarding** 시작

**온보딩 선택:**

| 단계 | 선택 |
|---|---|
| Install | QuickStart |
| LLM Provider | **OpenRouter** |
| API Key | OpenRouter 키 붙여넣기 |
| Base URL | `https://openrouter.ai/api/v1` |
| Agent name | `blog-orchestrator` (예) |

### 1-3. 백그라운드 24/7 (launchd)

```bash
openclaw onboard --install-daemon
# 또는
openclaw gateway install
```

확인:

```bash
openclaw --version
openclaw doctor
openclaw gateway status
```

### 1-4. OpenRouter 모델 기본값 (설정 파일)

`~/.openclaw/config` 또는 onboarding에서 환경변수 — 에이전트별로 나중에 분리.

```bash
# ~/.openclaw/env 또는 셸 프로필 (예시)
export OPENROUTER_API_KEY="sk-or-..."
export OPENROUTER_BASE_URL="https://openrouter.ai/api/v1"

# 단계별 (스크립트·스킬에서 사용)
export BLOG_MODEL_SUMMARY="google/gemini-2.0-flash-001"
export BLOG_MODEL_OUTLINE="anthropic/claude-3-haiku"
export BLOG_MODEL_STOCK="anthropic/claude-sonnet-4"
export BLOG_MODEL_DEAL="google/gemini-2.0-flash-001"
```

OpenRouter 대시보드 → **Limits** 월 상한 설정.

### 1-5. Telegram 승인 채널 연결

OpenClaw onboarding 또는 채널 설정에서 **Telegram** 연결.

- BotFather → `/newbot` → 토큰
- OpenClaw에 Telegram 토큰·본인 chat_id 등록
- 승인 메시지를 이 채널로 수신

`chat_id` 확인: 봇에게 메시지 보낸 뒤  
`https://api.telegram.org/bot<TOKEN>/getUpdates`

### 1-6. 문제 해결

```bash
# openclaw 명령 없음
export PATH="$(npm prefix -g)/bin:$PATH"
echo 'export PATH="$(npm prefix -g)/bin:$PATH"' >> ~/.zshrc

openclaw doctor
```

공식 문서: https://docs.openclaw.ai/install

---

## Phase 2 — 8GB RAM 운영 (필수)

| 구성 | RAM | 조치 |
|---|---|---|
| macOS | ~2GB | 절전 방지 유지 |
| VM centos-server | **4GB → 2GB 권장** | VirtualBox 설정에서 RAM 축소 |
| Docker (VM) | ~500MB | Kuma+cloudflared만 유지 |
| OpenClaw + 크롤 | ~1~2GB peak | **크롤·LLM 시간대 분산** |

**VBoxManage RAM 변경 (VM 종료 후):**

```bash
VBoxManage controlvm centos-server poweroff
VBoxManage modifyvm centos-server --memory 2048
VBoxManage startvm centos-server --type headless
```

**스케줄 분리 (겹침 방지):**

| 시간 | 작업 |
|---|---|
| 03:00 | restic 백업 |
| 06:00~07:00 | 주식 크롤+초안 |
| 08:00 | 승인 알림 (전날 밤 초안) |
| 09~21시 3h 간격 | 핫딜 크롤+초안 |
| 22:00 | 승인 대기 큐 정리 |

---

## Phase 3 — 폴더·블로그 기초

### 3-1. Tistory 2개 개설

| 블로그 | 주제 | 카테고리 예 |
|---|---|---|
| `stock-xxx` | 국내·해외 주식 분석 | 미국주식 / 국내주식 / ETF / 실적시즌 |
| `deal-xxx` | 핫딜 | 쿠팡 / 네이버 / 해외직구 / 생활할인 |

각 블로그:

- [ ] 카카오 로그인·도메인 연결
- [ ] 카테고리 ID 메모 (발행 스크립트용)
- [ ] **애드센스** 신청 (승인 후 스크립트 삽입)
- [ ] **쿠팡 파트너스** 가입 (핫딜 블로그)
- [ ] 고정 면책문·제휴 광고 표시 문구 (블로그 설정)

### 3-2. ServerData 폴더

```bash
mkdir -p /Volumes/ServerData/Projects/blog/{stock,deals}/{raw,drafts,approved,published,logs}
mkdir -p /Volumes/ServerData/Projects/blog/config
```

### 3-3. 설정 파일 `config/blog.env` (chmod 600)

```bash
# Tistory — 블로그 호스트 (예: xxx.tistory.com)
TISTORY_STOCK_HOST=your-stock.tistory.com
TISTORY_DEAL_HOST=your-deal.tistory.com
TISTORY_STOCK_CATEGORY_US=1234567
TISTORY_STOCK_CATEGORY_KR=1234568
# ... 카테고리 ID

# 쿠팡 파트너스
COUPANG_ACCESS_KEY=...
COUPANG_SECRET_KEY=...

# API
FINNHUB_API_KEY=...
DART_API_KEY=...
OPENROUTER_API_KEY=...

# Telegram
TELEGRAM_BOT_TOKEN=...
TELEGRAM_CHAT_ID=...

# 에펨 (완전 자동 — 요청 간격 준수)
FMKOREA_HOTDEAL_URL=https://...
CRAWL_DELAY_SEC=2

# LLM 비용 (blog.env.example 참고)
STOCK_LLM_DAILY_MAX=3
DEAL_LLM_DAILY_MAX=8
CONTENT_DEDUP_DAYS=7
```

---

## Phase 3-B — 수동 작업 자동화 매트릭스

| 작업 | 이전 | 지금 | 스크립트 |
|---|---|---|---|
| blog.env 작성 | 수동 vi | **마법사** | `setup-blog-wizard.sh` |
| Telegram chat_id | 수동 조회 | **자동 조회** | wizard 내 getUpdates |
| launchd 등록 | 수동 plist | **원클릭** | `install-blog-launchd.sh` |
| 승인/거절 처리 | 터미널 명령 | **Telegram 버튼** | `telegram-callback-poller.sh` |
| Tistory 쿠키 검사 | 발행 실패 후 | **매일 05:30** | `tistory-cookie-check.sh` |
| LLM 일일 리포트 | 없음 | **22:00 Telegram** | `llm-budget.sh report` |
| 중복 핫딜 필터 | 없음 | **크롤 직후** | `content-dedup.sh` |
| 면책·제휴 문구 | 수동 | **템플릿 자동** | `deal-template.html` |
| 실패 알림 | 없음 | **자동** | `telegram-alert.sh` |

**여전히 직접 해야 하는 것 (중요·최소):**

1. Tistory 블로그 2개 **최초 개설** (카카오 로그인)
2. 쿠키 **최초 1회** 브라우저 export → `config/tistory-cookies.json`
3. 애드센스·쿠팡 파트너스 **계정 신청** (심사)
4. Telegram에서 **승인/거절 버튼** (내용 검토 — 품질 게이트)

쿠키 최초 export 방법:

```bash
# Chrome 개발자도구 → Application → Cookies → tistory.com
# TSSESSION 등을 JSON으로 저장
# /Volumes/ServerData/Projects/blog/config/tistory-cookies.json
{
  "your-stock.tistory.com": "TSSESSION=...; _T_ANO=...",
  "your-deal.tistory.com": "TSSESSION=...; ..."
}
```

만료 시 Telegram 알림 → 브라우저에서 재로그인 → JSON 갱신 (월 1~2회 예상).

---

## Phase 4 — Tistory 발행 (승인 후)

> **주의:** Tistory 공식 Open API는 **2023년 종료**. 개인 자동화는 아래 중 택1.

### 방식 A — 임시저장 + 승인 후 발행 (권장)

1. 파이프라인이 HTML 초안 생성
2. `published: 0` (임시저장)으로 Tistory `post.json` 호출
3. Telegram: 제목·요약·**티스토리 미리보기 링크**·[승인]/[거절]
4. **승인** → 동일 글 `published: 1` 업데이트 또는 발행 API 재호출
5. **거절** → 로그만 남기고 삭제

### 방식 B — OpenClaw 브라우저 자동화

- Tistory 관리자 UI에 직접 붙여넣기·발행
- 쿠키 만료에 강함 → 주기적 로그인 필요

### post.json 핵심 (방식 A)

```text
POST https://{blog}.tistory.com/manage/post.json
Headers: Cookie (TSSESSION, _T_ANO...), Referer, User-Agent
Body JSON:
  id: "0"
  title, content (HTML), contentType: "html"
  category: {카테고리ID}
  published: 0   ← 승인 전 임시저장
  visibility: 20
  tag: "..."
```

**쿠키 갱신:** 주 1회 수동 로그인 후 쿠키 export → `config/tistory-cookies.json`  
또는 Playwright로 headless 로그인 (완전 자동화 시).

스크립트 위치 예: `/Users/kimi/scripts/blog/tistory-publish.sh`

### 승인 플로우 (Telegram)

```text
[주식 초안]
제목: 엔비디아 실적 분석 — 2026 Q1
요약: (3줄)
미리보기: https://your-stock.tistory.com/manage/...
[✅ 승인] [❌ 거절]

승인 → tistory-publish.sh --approve {draft_id}
거절 → archive
```

OpenClaw 스킬 또는 `approval-bot.py`가 callback 처리.

---

## Phase 4-B — 실패 알림·에스컬레이션 (필수)

> **승인 알림**과 별도로, AI·크롤·발행이 **실패할 때** Telegram으로 알림을 보냅니다.  
> 스크립트: [scripts/blog/](../scripts/blog/) → `install-blog-scripts.sh`로 맥미니에 설치

### 4-B-1. 알림 종류

| 심각도 | 예시 | 동작 |
|---|---|---|
| `info` | 초안 준비 완료, 건너뜀 로그 | 알림만 |
| `warn` | 가격 불일치·품절 skip, 재시도 중 | 알림, 파이프라인 계속 |
| `error` | LLM 3회 실패, 숫자 검증 실패, Tistory 401 | 알림 + 해당 건 중단 |
| `critical` | 크롤 연속 실패, OpenClaw gateway down | 알림 + **파이프라인 자동 일시정지** |

### 4-B-2. 실패 시 흐름

```text
단계 실행
  → 실패? → 재시도 (기본 3회, 30초 간격)
  → 3회 실패? → telegram-alert.sh (Telegram)
  → critical? → pause-{stock|deal}.flag 생성 → 이후 스케줄 skip + 알림

재개: rm /Volumes/ServerData/Projects/blog/config/pause-stock.flag
```

**중복 알림 방지:** 동일 원인은 `ALERT_COOLDOWN_SEC`(기본 3600초) 내 1회만 전송.

### 4-B-3. 단계별 알림 매핑

| 파이프라인 | 단계 | 실패 시 |
|---|---|---|
| stock | crawl | error → 재시도 → critical 시 pause |
| stock | draft-writer (OpenRouter) | error → 재시도 → pause |
| stock | validate (숫자 검증) | error → 초안 폐기 + 알림 (발행 안 함) |
| stock | tistory-draft | error → 알림, 수동 쿠키 갱신 |
| deal | crawl (에펨) | error → 재시도 → critical 시 pause |
| deal | verify-price | warn → skip + 알림 (정상) |
| deal | draft-writer | error → 재시도 → pause |
| system | openclaw gateway | critical → 즉시 알림 |

### 4-B-4. 설치·테스트 (맥미니)

```bash
cd /Volumes/ServerData/Docs/scripts/blog
chmod +x install-blog-scripts.sh
./install-blog-scripts.sh

vi /Volumes/ServerData/Projects/blog/config/blog.env
# TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID 설정

~/scripts/blog/blog-orchestrator.sh test-alert
# Telegram에 info/warn/error 테스트 3건 수신 확인
```

### 4-B-5. Telegram 메시지 예시

```text
🚨 블로그 자동화 알림
심각도: error
파이프라인: stock
단계: draft-writer
원인: OpenRouter 429 — NVDA Q1 draft failed after 3 attempts
상세: rate limit exceeded

조치: tail -50 /Volumes/ServerData/Projects/blog/logs/pipeline.log
```

### 4-B-6. 설정 (`blog.env`)

```bash
ALERT_ENABLED=1
ALERT_COOLDOWN_SEC=3600
ALERT_MAX_RETRIES=3
ALERT_RETRY_DELAY_SEC=30
```

로그: `/Volumes/ServerData/Projects/blog/logs/pipeline.log` (JSON lines)

---

## Phase 5 — OpenClaw 에이전트 구성

### 5-1. 에이전트 4+1

| 에이전트 | 역할 | 모델 |
|---|---|---|
| `stock-researcher` | RSS/API/DART 수집 → JSON | flash |
| `stock-writer` | **분석형** HTML 초안 | sonnet |
| `deal-scout` | 에펨 완전 자동 크롤 | (스크립트) + flash 요약 |
| `deal-writer` | 300~800자 + 제휴 링크 | flash |
| `publisher` | Tistory 임시저장 + Telegram | haiku |

**주식 톤 (분석형) 프롬프트 핵심:**

```text
- 투자 권유 금지 ("사세요/팔세요" X)
- 모든 숫자는 제공 JSON만 인용, 출처 URL 표기
- 구성: 요약 → 기업개요 → 재무/실적 표 → 모멘텀 → 리스크 → 시나리오(확률 표현) → 면책
- 문체: 분석 보고서, 감정 배제
```

### 5-2. OpenClaw 스킬/워크플로 등록

`~/.openclaw/skills/` 또는 문서화된 skill 경로에:

- `stock-daily-pipeline` — cron에서 `openclaw run stock-daily`
- `deal-scan-pipeline` — 3시간마다

각 스킬이 호출하는 **외부 스크립트:**

```text
/Users/kimi/scripts/blog/
├── pipeline-common.sh           # 재시도, 로그, notify_failure
├── telegram-alert.sh            # 실패·에스컬레이션 Telegram
├── blog-orchestrator.sh         # stock/deal 파이프라인 + 실패 처리
├── install-blog-scripts.sh      # 맥미니 설치
├── crawl-stock.sh
├── crawl-fmkorea-deals.sh
├── verify-coupang-price.sh
├── generate-draft-openclaw.sh   # OpenRouter 호출 래퍼
├── tistory-draft.sh
├── telegram-approval.sh
└── tistory-publish.sh
```

### 5-3. API 비용 절약 (품질 유지)

> **원칙:** LLM은 “글 쓰기”에만 쓰고, 필터·검증·중복은 **규칙/스크립트**로 처리.

#### 비용 절약 파이프라인

```text
[주식]
크롤(JSON) → flash 필터(후보 1개) → haiku 아웃라인(선택) → sonnet 본문(일 3회 상한)
           → 규칙 숫자검증 → 임시저장 → 승인

[핫딜]
에펨 크롤 → dedup(무료) → 쿠팡 API 검증(무료) → 템플릿 HTML
         → flash 소개 2문장만(캐시) → 임시저장 → 승인
```

#### 모델·상한 (기본값)

| 단계 | 모델 | 일/주 상한 | 비고 |
|---|---|---|---|
| 필터·dedup | flash | stock 3 / deal 8 | 후보 선별만 |
| 아웃라인 | haiku | 포함 | 짧은 JSON |
| 주식 본문 | **sonnet** | **일 3** | 분석형 품질 핵심 |
| 심층 분석 | sonnet | **주 2** | `STOCK_DEEP=1` 실적일만 |
| 핫딜 소개 | flash | deal 상한 공유 | max 200 토큰 |
| 발행 메타 | haiku | 거의 없음 | 스크립트 위주 |

#### LLM 호출 전 무료 필터 (반드시)

1. `content-dedup.sh` — 7일 내 유사 제목 skip
2. `llm-budget.sh check` — 상한 초과 시 skip + 알림
3. 쿠팡 가격 불일치 — LLM 호출 안 함
4. 주말 주식 — orchestrator skip
5. `LLM_CACHE_TTL_HOURS=24` — 동일 입력 재사용

#### 예상 비용 (참고)

| 시나리오 | 월 LLM 호출 | 대략 비용 |
|---|---|---|
| 보수적 (상한 준수) | 주식 ~60 + 핫딜 ~150 | **$5~15** |
| 상한 없이 전량 sonnet | 500+ | $50+ |

OpenRouter 대시보드 **Limits** + `llm-budget.sh report` 22:00 로 이중 관리.

#### 스크립트

```bash
~/scripts/blog/openrouter-call.sh --task stock --pipeline stock \
  --cache-key nvda-20260614 --system "..." --user "compact JSON only"

~/scripts/blog/llm-budget.sh status
~/scripts/blog/deal-template-render.sh --input raw/x.json --output drafts/x.html
```

---

## Phase 6 — 크롤링 (완전 자동)

### 6-1. 주식 블로그

| 소스 | 용도 | 주기 |
|---|---|---|
| Finnhub | 시세·실적 캘린더 | 일 1회 |
| DART Open API | 국내 공시 | 일 1회 |
| Yahoo Finance RSS | 해외 뉴스 | 6h |
| SEC EDGAR RSS | 미국 공시 | 일 1회 |

**종목 큐:** `config/stock-watchlist.json` (미국 70% / 국내 30% / ETF 10%)

**파이프라인:**

```text
cron → watchlist/실적일 트리거
  → retry crawl-stock.sh → raw/{date}-{ticker}.json
  → retry OpenClaw stock-writer → drafts/{id}.html
  → 숫자 검증 실패? → notify_failure(error) → 폐기
  → retry tistory-draft.sh (published=0)
  → telegram-approval.sh (성공 시)
  → 어느 단계든 3회 실패 → telegram-alert + pause-stock.flag
```

### 6-2. 핫딜 블로그 (에펨 완전 자동)

```text
cron 3h → retry crawl-fmkorea-deals.sh
  → 화제순/추천순 상위 N (제목·URL·조회수만, 본문 X)
  → 상품명 정규화
  → verify-coupang-price.sh (파트너스 API)
  → 가격 불일치/품절 → notify_failure(warn) + skip (파이프라인 계속)
  → retry OpenClaw deal-writer → HTML + 제휴 링크
  → 애드센스·제휴 문구 자동 삽입
  → tistory-draft + telegram 승인
  → 크롤 3회 연속 실패 → telegram-alert(critical) + pause-deal.flag
```

**에펨 크롤 규칙:**

- `CRAWL_DELAY_SEC=2` 이상
- User-Agent 명시
- robots.txt 확인
- **본문·이미지 재게시 금지** — 키워드만 추출

### 6-3. 수익 삽입

| 블로그 | 수익 |
|---|---|
| 주식 | **애드센스** (Tistory 스킨/본문 하단) |
| 핫딜 | **쿠팡 파트너스** 링크 본문 + **애드센스** |

핫딜 글 템플릿 하단:

```html
<p><small>이 포스팅은 쿠팡 파트너스 활동의 일환으로, 이에 따른 일정액의 수수료를 제공받습니다.</small></p>
```

주식 글 하단:

```html
<p><small>본 글은 투자 참고용이며, 투자 권유가 아닙니다. 투자 손실에 대한 책임은 본인에게 있습니다.</small></p>
```

---

## Phase 7 — 스케줄 (launchd 자동 설치)

맥미니 cron FDA 이슈 → **launchd** + `install-blog-launchd.sh`.

| launchd | 주기 | 역할 |
|---|---|---|
| `com.kimi.blog-stock` | 매일 06:00 (주말은 스크립트 skip) | 주식 파이프라인 |
| `com.kimi.blog-deal` | 3시간 | 핫딜 파이프라인 |
| `com.kimi.blog-telegram-poller` | 60초 | 승인/거절 버튼 |
| `com.kimi.blog-cookie-check` | 05:30 | Tistory 쿠키 검사 |
| `com.kimi.blog-llm-report` | 22:00 | LLM 사용량 리포트 |

```bash
~/scripts/blog/install-blog-launchd.sh
launchctl list | grep com.kimi.blog
```

**restic 03:00과 겹치지 않게** 이미 분리됨.

---

## Phase 8 — 구축 체크리스트 (0→100)

### 0~20: 기반

- [ ] Phase 0 검토 완료
- [ ] `setup-blog-wizard.sh` → blog.env
- [ ] `install-blog-scripts.sh` + `test-alert`
- [ ] `install-blog-launchd.sh`
- [ ] OpenClaw 설치 + `openclaw doctor` OK
- [ ] OpenRouter Limits 설정
- [ ] VM RAM 2GB로 조정 (8GB 맥)
- [ ] Tistory 2개 + 카테고리
- [ ] 애드센스·쿠팡 파트너스 신청
- [ ] `ServerData/Projects/blog/` 구조

### 20~50: 주식 MVP

- [ ] Finnhub + DART API 키
- [ ] `crawl-stock.sh` 동작
- [ ] stock-writer 분석형 초안 1편
- [ ] Tistory 임시저장 + Telegram 승인 1회
- [ ] 승인 후 발행 성공
- [ ] 주 3편 승인 발행 (수동 트리거)

### 50~70: 주식 자동화

- [ ] watchlist + 실적 캘린더 트리거
- [ ] 숫자 검증 스크립트
- [ ] launchd 평일 06:00
- [ ] 주 5~7편 승인 워크플로 안정화

### 70~90: 핫딜 자동화

- [ ] 쿠팡 파트너스 API 연동
- [ ] `crawl-fmkorea-deals.sh` 완전 자동
- [ ] 가격 2차 검증
- [ ] 하루 3~8건 승인 큐 (상한)
- [ ] 제휴·광고 문구 자동

### 90~100: 운영

- [ ] Tistory 쿠키 최초 export + `tistory-cookie-check.sh` OK
- [ ] OpenRouter Limits + `llm-budget.sh status` 확인
- [ ] Uptime Kuma: 블로그 URL 모니터
- [ ] Search Console + 네이버 서치어드바이저 등록
- [ ] `seo-keywords.json` + `seo-enrich.sh` 연동
- [ ] 잘 된 키워드 → watchlist 반영
- [ ] 실패 알림 cooldown·pause 플래그 동작 확인

---

## Phase 9 — 콘텐츠 전략 (확정)

### 주식 (분석형)

| 유형 | 비율 | 글자수 | 주기 |
|---|---|---|---|
| 종목 분석 | 40% | 1,800~5,000 | 주 2~3 |
| 실적·일정 | 30% | 800~2,000 | 주 1~2 |
| ETF·배당 | 20% | 1,800~3,000 | 주 1 |
| 심층 | 10% | 3,000~5,000 | 월 2~4 |

지역: 미국 70% / 국내 30% / ETF 10% (국내는 DART 데이터로 보강)

### 핫딜

| 유형 | 글자수 | 주기 |
|---|---|---|
| 일반 핫딜 | 300~800 | 하루 3~8 (승인 후) |
| 행사 정리 | 1,200~2,000 | 행사 주 1편 |

---

## Phase 10 — 상위 노출·검색 전략

> **질문:** AI 포스팅이면 티스토리·네이버·구글 **내부 검열**로 상위 노출이 안 될 수 있지 않나?  
> **답:** **그럴 수 있습니다.** 특히 얇은 반복 콘텐츠·대량 자동 발행은 노출·수익화 모두 불리합니다.  
> 자동화는 **초안 생산**까지이고, **노출은 차별화·SEO·승인 품질**로 보완하는 전략이 필요합니다.

### 10-1. 플랫폼별 리스크 (현실 인식)

| 플랫폼 | AI/저품질 콘텐츠 대응 | 우리에게 의미 |
|---|---|---|
| **Google** | Helpful Content, 스팸 정책 — 대량·가치 없는 글 감점 | 주식은 **독자 가치(숫자·출처)** 없으면 노출 어려움 |
| **네이버** | 티스토리 색인·품질 신호, 중복·얇은 글 저순위 | **네이버 웹마스터** 등록·롱테일 필수 |
| **티스토리** | 내부 추천·이웃보다 **검색 유입**이 핵심 | 카테고리·태그·제목 구조화 |
| **애드센스** | thin content·정책 위반 시 승인·노출 제한 | 면책·제휴 고지, 복붙 금지 |

**핵심:** “AI 썼다” 자체보다 **다른 글과 똑같고 가치 없는 글**이 문제입니다.  
우리 파이프라인의 **DART/Finnhub 숫자·쿠팡 가격 검증·승인 게이트**가 차별화 포인트입니다.

### 10-2. 블로그별 노출 전략

#### 주식 블로그 — “검색형 분석” (롱테일)

| 전략 | 내용 | 자동화 |
|---|---|---|
| **롱테일 제목** | `삼성전자 주가` ❌ → `삼성전자 2026 Q1 실적 EPS 컨센서스 비교` ✅ | 키워드 큐 `seo-keywords.json` |
| **실적 타이밍** | 실적 발표 **당일~48h** 글이 노출 유리 | watchlist `earnings_priority` |
| **독점 데이터 각** | 표·숫자는 **크롤 JSON만** — 일반 뉴스 요약과 차별 | 숫자 검증 스크립트 |
| **출처 명시** | Finnhub/DART/SEC 링크 필수 | 프롬프트 + 승인 체크리스트 |
| **발행 속도** | 주식 **일 2건 상한** (양보다 깊이) | `STOCK_LLM_DAILY_MAX=3` 이하 권장 |
| **내부 링크** | 같은 종목·섹터 과거 글 연결 | `seo-enrich.sh` 제안 |
| **갱신** | 실적 후 숫자 바뀌면 **글 업데이트** (신규보다 유리할 때 있음) | 수동 또는 추후 스크립트 |

#### 핫딜 블로그 — “속도형” (검색 보조)

| 전략 | 내용 | 자동화 |
|---|---|---|
| **속도** | 에펨→검증→초안 **3시간 주기** — 늦으면 의미 감소 | launchd deal |
| **검색보다 SNS·재방문** | 핫딜은 상위 키워드 경쟁 치열 → **구독·즐겨찾기**도 병행 | 티스토리 구독 유도 문구 |
| **가격 정확도** | 틀린 가격 = 이탈·신뢰 하락 | 쿠팡 API 2차 검증 |
| **중복 억제** | 같은 상품 7일 내 재게시 금지 | `content-dedup.sh` |
| **일 발행 상한** | **6건/일** 이하 (스팸 신호 방지) | `DEAL_PUBLISH_DAILY_MAX` |

### 10-3. AI 티 안 나게 (품질 게이트)

자동화만으로는 부족합니다. **승인 단계**에서 아래를 거칩니다.

```text
[자동] dedup → 숫자검증 → seo-enrich → 임시저장
[사람] Telegram 30초 체크 → 승인/거절
[선택] 거절 시 1~2문장 직접 수정 후 재발행 (월 몇 건이면 충분)
```

**프롬프트 규칙 (이미 반영·강화):**

- 문단 길이·소제목 구조를 글마다 **랜덤 시드**로 변경 (템플릿 고정 금지)
- 주식: 표 1개 이상, bullet 남용 금지
- 핫딜: 템플릿 HTML + **소개만** LLM — 본문 전체 생성 금지
- “결론적으로”“요약하면” 등 **AI 상투구 금지** 리스트 프롬프트에 추가

체크리스트: `config/editorial-checklist.txt`  
승인 메시지에 요약 체크 항목 표시 (`telegram-approval.sh`).

### 10-4. 기술 SEO (구축 시 1회 + 유지)

| 항목 | 작업 | 주기 |
|---|---|---|
| **Google Search Console** | 2개 블로그 URL 등록, sitemap 제출 | 최초 + 월 점검 |
| **네이버 서치어드바이저** | 사이트 등록, RSS/수집 요청 | 최초 |
| **티스토리** | 카테고리 정리, 블로그 설명·대표 이미지 | 최초 |
| **메타 설명** | 120~160자, 제목과 **다르게** | `seo-enrich.sh` 자동 |
| **태그** | 3~5개, 대표 키워드만 | `seo-enrich.sh` 자동 |
| **대표 이미지** | 글마다 1장 (차트 캡처·상품 공식 이미지) | 승인 전 수동 10초 |
| **URL 구조** | 티스토리 기본 slug — 제목에 키워드 포함 | 제목 설계 |

```bash
# 발행 파이프라인에 SEO 단계 삽입 (임시저장 전)
~/scripts/blog/seo-enrich.sh --pipeline stock --draft-id 20260614-nvda
```

### 10-5. 키워드·제목 공식

**주식 제목 템플릿 (롱테일):**

```text
{종목명} {이벤트} {연도} — {핵심 지표 1개} 분석
예: 엔비디아 2026 Q1 실적 — EPS·가이던스 정리
```

**핫딜 제목 템플릿:**

```text
{브랜드} {상품} {가격}원 ({할인율}) — {한 줄 혜택}
예: 삼성 EVO 1TB 89,900원 (28%) — 쿠팡 로켓와우
```

키워드 큐 예시: `config/seo-keywords.json.example` → `seo-keywords.json` 복사 후 수정.

### 10-6. 측정·피드백 루프

| 지표 | 도구 | 액션 |
|---|---|---|
| 노출·클릭 | Search Console | 클릭 있는 키워드 → watchlist·제목 패턴 반영 |
| 색인 여부 | GSC URL 검사 | 미색인 → 내부 링크·본문 길이 보강 |
| 순위 추적 | GSC 또는 수동 (주 1회) | 상위 10 키워드만 집중 |
| 이탈·체류 | 애드센스/티스토리 통계 | 짧은 글·틀린 가격 글 패턴 제거 |

**월 1회 리뷰 (15분):**

1. GSC 상위 쿼리 10개 export
2. `seo-keywords.json`·watchlist 업데이트
3. 클릭 0인 유형 글 비율 줄이기

### 10-7. 기대치 조정

| 기간 | 현실적 목표 |
|---|---|
| 1~3개월 | 색인·롱테일 **소량 유입** (일 10~50 PV) |
| 3~6개월 | 실적 시즌 글 **특정 쿼리 1~3페이지** |
| 6개월+ | 주식 1~2개 **대표 키워드** 안착, 핫딜은 **속도·재방문** |

상위 노출은 **보장되지 않습니다.** 자동화는 **후보를 빠르게 만들고**, SEO·승인으로 **걸러진 글만 쌓는** 구조입니다.

### 10-8. 체크리스트 (SEO)

- [ ] Search Console + 네이버 서치어드바이저 등록
- [ ] `seo-keywords.json` 블로그별 작성
- [ ] `seo-enrich.sh` 파이프라인 연결
- [ ] 승인 시 editorial-checklist 습관화
- [ ] 주식 일 2건·핫딜 일 6건 상한 준수
- [ ] 월 1회 GSC 키워드 리뷰

---

## Phase 11 — 스크립트 골격

템플릿: [scripts/blog/](../scripts/blog/) — 맥미니에 `install-blog-scripts.sh`로 배포

### `telegram-alert.sh` (실패 알림)

```bash
~/scripts/blog/telegram-alert.sh \
  --severity error --pipeline stock --step draft-writer \
  --reason "OpenRouter 429" --context "NVDA Q1 draft"
```

### `pipeline-common.sh` — 다른 스크립트에서 source

```bash
source ~/scripts/blog/pipeline-common.sh
retry_command stock crawl "Finnhub 수집" -- ./crawl-stock.sh NVDA
# 실패 시 자동 notify_failure + 재시도
```

### `seo-enrich.sh` (노출 메타 — LLM 비용 0)

```bash
~/scripts/blog/seo-enrich.sh --pipeline stock --draft-id 20260614-nvda
# → meta_description, tags, internal_link_suggestions 갱신
```

### `telegram-approval.sh` (승인 — 별도 구현)

```bash
#!/bin/bash
# drafts/{id}.meta.json 읽어 Telegram 전송
# 인라인 키보드: approve_{id} / reject_{id}
```

### `tistory-draft.sh` (개념)

```bash
#!/bin/bash
source /Volumes/ServerData/Projects/blog/config/blog.env
# Cookie from config/tistory-cookies.json
# POST post.json published=0
```

승인 시 `published=1` 또는 manage API 재호출.

---

## 문제 해결

| 증상 | 해결 |
|---|---|
| 맥 느림 | VM RAM 2GB, 크롤 시간 분산 |
| Tistory 401 | 쿠키 갱신 |
| post.json 실패 | Referer·category ID·HTML 이스케이프 확인 |
| OpenClaw gateway down | `openclaw gateway status` / launchd |
| 에펨 차단 | delay 증가, IP 밴 시 일시 중지 |
| 승인 안 옴 | Telegram chat_id·봇 토큰 |
| 실패 알림 안 옴 | `ALERT_ENABLED=1`, `blog-orchestrator.sh test-alert` |
| 알림 폭주 | `ALERT_COOLDOWN_SEC` 증가 (기본 3600) |
| 파이프라인 멈춤 | `config/pause-*.flag` 삭제 후 재실행 |
| LLM 상한 도달 | 정상 — 다음날 자동 재개 / `llm-budget.sh status` |
| Telegram 버튼 무반응 | `launchctl list | grep telegram-poller` |
| 검색 노출 없음 | Phase 10 — 롱테일·GSC·발행 상한·본문 차별화 |
| AI 느낌 강함 | 거절 후 1~2문장 수동 수정 / 프롬프트 상투구 금지 |

---

## 관련 문서

- [00-HOME-SERVER-HANDOFF.md](../00-HOME-SERVER-HANDOFF.md)
- [cloudflare-tunnel.md](./cloudflare-tunnel.md)
- OpenClaw: https://docs.openclaw.ai

---

## 맥미니 경로

```text
/Volumes/ServerData/Docs/guides/blog-automation-openclaw-openrouter.md
/Volumes/ServerData/Projects/blog/
/Users/kimi/scripts/blog/
```

*최종 업데이트: 상위 노출·검색 전략 (Phase 10) + seo-enrich*
