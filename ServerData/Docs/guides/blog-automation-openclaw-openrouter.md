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
│  ├─ 승인 봇 (Telegram 권장)                                  │
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
| 1 | OpenClaw 설치 + OpenRouter + launchd | Phase 1 |
| 2 | VM RAM 2GB, 스케줄 분리 | Phase 2 |
| 3 | Tistory 2개 + 폴더·`blog.env` | Phase 3 |
| 4 | Telegram 승인 + Tistory 임시저장 | Phase 4 |
| 5 | OpenClaw 에이전트 4+1 | Phase 5 |
| 6 | 주식·핫딜 크롤 파이프라인 | Phase 6 |
| 7 | launchd 스케줄 등록 | Phase 7 |
| 8 | 0→100 체크리스트 따라 운영 | Phase 8 |

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
```

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
├── crawl-stock.sh
├── crawl-fmkorea-deals.sh
├── verify-coupang-price.sh
├── generate-draft-openclaw.sh   # OpenRouter 호출 래퍼
├── tistory-draft.sh
├── telegram-approval.sh
└── tistory-publish.sh
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
  → crawl-stock.sh → raw/{date}-{ticker}.json
  → OpenClaw stock-writer → drafts/{id}.html
  → 숫자 검증 스크립트 (JSON vs 본문)
  → tistory-draft.sh (published=0)
  → telegram-approval.sh
```

### 6-2. 핫딜 블로그 (에펨 완전 자동)

```text
cron 3h → crawl-fmkorea-deals.sh
  → 화제순/추천순 상위 N (제목·URL·조회수만, 본문 X)
  → 상품명 정규화
  → verify-coupang-price.sh (파트너스 API)
  → 가격 불일치/품절 → skip
  → OpenClaw deal-writer → HTML + 제휴 링크
  → 애드센스·제휴 문구 자동 삽입
  → tistory-draft + telegram 승인
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

## Phase 7 — 스케줄 (launchd, cron 대신 권장)

맥미니 cron FDA 이슈 → **launchd** 사용.

`~/Library/LaunchAgents/com.kimi.blog-stock.plist` — 평일 06:00  
`~/Library/LaunchAgents/com.kimi.blog-deal.plist` — 3시간 간격 StartInterval

또는 하나의 `blog-orchestrator.sh`에서 시간 분기.

**restic 03:00과 겹치지 않게** 이미 분리됨.

---

## Phase 8 — 구축 체크리스트 (0→100)

### 0~20: 기반

- [ ] OpenClaw 설치 + `openclaw doctor` OK
- [ ] OpenRouter 키 + 월 한도
- [ ] Telegram 봇 + chat_id
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

- [ ] Tistory 쿠키 갱신 루틴 (주 1회)
- [ ] OpenRouter 월 비용 리뷰
- [ ] Uptime Kuma: 블로그 URL 모니터
- [ ] Search Console 2개 등록
- [ ] 잘 된 키워드 → watchlist 반영

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

## Phase 10 — 스크립트 골격 예시

### `telegram-approval.sh` (개념)

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

*최종 업데이트: 사용자 확정 — Tistory, 승인 후, 에펨 완자동, 애드센스+쿠팡, 8GB, 분석형*
