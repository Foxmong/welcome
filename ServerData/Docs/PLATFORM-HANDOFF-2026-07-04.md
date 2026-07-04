# 플랫폼 핸드오프 — 맥미니 홈서버 + 블로그 자동화

> **용도:** 다른 AI·플랫폼·담당자에게 현재까지 진행 상황을 한 번에 전달  
> **작성일:** 2026-07-04  
> **작업자:** kimi  
> **GitHub:** `Foxmong/welcome` (문서·스크립트는 feature 브랜치에 있음, `main`과 다름)

---

## 0. 새 세션용 프롬프트 (복사)

```text
맥미니 홈서버 + 블로그 자동화 이어서 진행.

필수 읽기 (맥미니 경로):
/Volumes/ServerData/Docs/PLATFORM-HANDOFF-2026-07-04.md  ← 이 파일 (최신 진행)
/Volumes/ServerData/Docs/BLOG-AUTOMATION-MASTER.md       ← 전략·아키텍처
/Volumes/ServerData/Docs/00-HOME-SERVER-HANDOFF.md       ← 인프라·VM·Tunnel

확정 설정:
- Tistory 2개: foxmong(주식), foxhat(핫딜), 승인 후 발행
- OpenClaw + OpenRouter, 맥미니 8GB, VM 2GB
- Telegram @Kimi0410_bot, Chat ID 8668829724
- 애드센스 + 쿠팡 파트너스 (미신청)

현재 Phase: A 인프라 ~70% — 쿠키·Telegram·launchd 완료, 카테고리 ID·OpenRouter·크롤러 미완
다음: foxhat 카테고리 ID → blog.env → OpenRouter 키 → tistory-draft.sh → 첫 임시저장
```

---

## 1. 한 페이지 요약

```text
[맥미니 macOS 8GB] kimi@100.127.117.23
  ├─ ServerData 2TB (/Volumes/ServerData)
  ├─ VirtualBox → CentOS VM (foxmong@100.69.135.104)
  ├─ Tailscale (외부 SSH/SFTP, 포트포워딩 없음)
  ├─ Cloudflare Tunnel → whoami.foxmong.cc (공개 헬스체크)
  └─ 블로그 자동화 (맥에서 실행, VM 아님)
       OpenClaw + ~/scripts/blog/* + Telegram 승인

[CentOS VM]
  Docker: Uptime Kuma :3001, cloudflared, whoami :8080
  SSHFS: /mnt/serverdata ← 맥미니 ServerData
```

| 영역 | 진행률 | 비고 |
|---|---|---|
| 홈서버 기반 (Tailscale, SSH, SMB, restic) | ✅ ~100% | 운영 안정화 완료 |
| VM (Docker, Kuma, SSHFS automount) | ✅ ~100% | |
| Cloudflare Tunnel | 🔧 ~60% | whoami ✅, status(Kuma) ⬜ |
| 블로그 자동화 Phase A | 🔧 ~70% | 쿠키·Telegram·launchd ✅ |
| 블로그 Phase B (크롤·발행 E2E) | ⬜ 0% | 스크립트 골격만 |

---

## 2. 접속 정보

### 맥미니 (macOS)

| 항목 | 값 |
|---|---|
| 호스트명 | kimiui-Macmini |
| 사용자 | **kimi** |
| 집 IP | 192.168.0.100 |
| Tailscale IP | **100.127.117.23** |
| SSH (집) | `ssh kimi@192.168.0.100` |
| SSH (밖) | `ssh kimi@100.127.117.23` |
| SFTP | `sftp kimi@100.127.117.23` |
| SMB | `smb://100.127.117.23/Shared` |

**Windows PC:** Tailscale 설치 → 같은 계정 로그인 → `ssh kimi@100.127.117.23`  
**회사 PC:** IT 정책상 개인 VPN/SSH 금지일 수 있음 → 개인 기기 권장

### CentOS VM

| 항목 | 값 |
|---|---|
| VM 이름 | centos-server |
| OS | CentOS Stream 10 (aarch64) |
| 사용자 | **foxmong** (`centos` 아님) |
| 집 IP | 192.168.0.113 |
| Tailscale IP | **100.69.135.104** |
| SSH (집) | `ssh foxmong@192.168.0.113` |
| SSH (밖) | `ssh foxmong@100.69.135.104` |
| 맥미니 경유 | `ssh -J kimi@100.127.117.23 foxmong@192.168.0.113` |
| Uptime Kuma | `http://100.69.135.104:3001` (Tailscale 필요) |

### 공개 URL (Tailscale 불필요)

| URL | 용도 | 상태 |
|---|---|---|
| `https://whoami.foxmong.cc` | Tunnel·VM·Docker 헬스체크 | ✅ 유지 권장 |
| `https://status.foxmong.cc` | Kuma 대시보드 공개 (Access) | ⬜ 미설정 |

---

## 3. 저장장치·경로

```text
/Volumes/ServerData/
├── Docs/                          ← 작업 문서 (맥미니 로컬, Git 아님 — 수동 복사)
├── Projects/blog/                 ← 블로그 데이터·설정
│   ├── config/
│   │   ├── blog.env               ← API 키, 호스트, Telegram (chmod 600)
│   │   └── tistory-cookies.json   ← Tistory 세션 쿠키 (chmod 600)
│   ├── stock/  deals/  logs/
├── LinuxVM/                       ← VirtualBox 디스크
└── Shared/                        ← SMB 공유

/Users/kimi/scripts/blog/          ← install-blog-scripts.sh 배포 후 실행 경로
/tmp/welcome-docs/                 ← GitHub clone 임시 (문서 복사용)
```

**문서 GitHub 동기화:** 맥미니 `/Volumes/ServerData/Docs`는 git repo가 아님.  
브랜치 `cursor/sshfs-automation-app-server-1fd4`에서 clone → `cp`로 Docs 갱신.

---

## 4. 홈서버 — 완료 항목

- [x] ServerData / ServerBackup 디스크 구성
- [x] Tailscale (맥미니 + VM)
- [x] SSH, SMB Shared
- [x] CentOS VM (VirtualBox, ARM64 — Guest Additions 불가, SSHFS 사용)
- [x] SSHFS `/mnt/serverdata` + systemd automount (`serverdata-sshfs.service`)
- [x] VM autostart (맥미니 부팅 시)
- [x] restic 백업 (03:00)
- [x] Docker + Uptime Kuma (`~/docker/uptime-kuma`, port 3001)
- [x] Kuma 모니터 5종 (맥 SSH, Tailscale ping, VM SSH 172.17.0.1:22 등)
- [x] Cloudflare Tunnel `home-server` + `whoami.foxmong.cc`
- [x] VM RAM **2048MB** (`VBoxManage modifyvm centos-server --memory 2048`)

### 홈서버 — 미완

- [ ] `status.foxmong.cc` + Cloudflare Access → Kuma 공개
- [ ] Tunnel 토큰 rotate
- [ ] Gitea (`git.foxmong.cc`)

---

## 5. 블로그 자동화 — 확정 전략

| 항목 | 선택 |
|---|---|
| 플랫폼 | Tistory × 2 (주식 / 핫딜) |
| 발행 | 승인 후 (초안 → Telegram → 승인 시 게시) |
| 에펨 크롤 | 완전 자동 |
| LLM | OpenRouter only |
| 수익 | 애드센스 + 쿠팡 파트너스 |
| 주식 톤 | 분석형 |
| 실행 위치 | **맥미니** (VM은 Kuma+Tunnel만) |

Tistory 공식 API **2023 종료** → `post.json` + 세션 쿠키 사용.

---

## 6. Tistory 블로그 — 현재 상태

### 블로그 목록 (카카오 계정 1개)

| blog.env 변수 | 호스트 | 블로그명 | 용도 |
|---|---|---|---|
| `TISTORY_STOCK_HOST` | **foxmong.tistory.com** | 여우의 테크 & 투자 | 주식 |
| `TISTORY_DEAL_HOST` | **foxhat.tistory.com** | 여우의 핫딜 정보 | 핫딜 |
| (미사용) | foxppy.tistory.com | 여우의 부동산 | 자동화 대상 아님 |

### foxmong 카테고리 ID (확정)

| 카테고리 | ID | blog.env 변수 (제안) |
|---|---|---|
| 미국주식 | **1367250** | `TISTORY_STOCK_CATEGORY_US=1367250` |
| 국내주식 | **1367251** | `TISTORY_STOCK_CATEGORY_KR=1367251` |
| ETF | **1367252** | `TISTORY_STOCK_CATEGORY_ETF=1367252` |
| 실적시즌 | **1367253** | `TISTORY_STOCK_CATEGORY_EARNINGS=1367253` |

> `blog.env`에 위 변수 **추가 필요** (아직 미반영 가능)

### foxhat 카테고리 (이름만 생성, ID 미추출)

| 카테고리 이름 | 주제 | ID |
|---|---|---|
| 쿠팡 | 주제 없음 | ⬜ 글쓰기 화면 `window.Config.categories`에서 확인 |
| 네이버 | 주제 없음 | ⬜ |
| 생활할인 | 주제 없음 | ⬜ |
| 핫딜 | 주제 없음 | ⬜ |

**카테고리 ID 확인법:** 관리 → 글쓰기 → F12 → `window.Config` → `blog.categories[].id`

### 쿠키 (`tistory-cookies.json`)

- [x] 파일 생성: `/Volumes/ServerData/Projects/blog/config/tistory-cookies.json`
- [x] 권한 `chmod 600`
- [x] `tistory-cookie-check.sh --blog all` 성공 (2026-06-28 09:02 UTC 로그)
- 키: `foxmong.tistory.com`, `foxhat.tistory.com` (blog.env 호스트와 일치)
- **보안:** 쿠키·토큰은 채팅/문서에 평문 기록 금지. 만료 시 Chrome 재로그인 → JSON 갱신

**쿠키 export 절차 (맥미니 Chrome):**  
F12 → Application → Cookies → `.tistory.com` → `TSSESSION`, `_T_ANO` (`.kakao.com` 것은 제외)

---

## 7. Telegram

| 항목 | 값 |
|---|---|
| 봇 | `@Kimi0410_bot` |
| Chat ID | **8668829724** |
| 용도 | 승인/거절 버튼 + 실패 알림 (info/warn/error) |
| 설정 파일 | `blog.env` → `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID` |

- [x] `blog-orchestrator.sh test-alert` — 3종 메시지 수신 확인
- [x] launchd `com.kimi.blog-telegram-poller` 등록

**토큰은 이 문서에 포함하지 않음.** `blog.env`에서만 관리.

---

## 8. OpenClaw

- [x] OpenClaw **2026.6.10** 설치 (`curl -fsSL https://openclaw.ai/install.sh`)
- 온보딩: Telegram 채널 Skip, 검색 Skip, 스킬 없음, Hatch later
- [ ] OpenRouter API 키 → OpenClaw config + `blog.env` 동시 설정
- [ ] `openclaw gateway status` 확인
- [ ] 스킬 등록 (stock-daily / deal-scan) — 미구현

---

## 9. 맥미니 블로그 스크립트 — 설치 상태

설치 경로: `~/scripts/blog/` (템플릿: `/Volumes/ServerData/Docs/scripts/blog/`)

| 스크립트 | 상태 | 역할 |
|---|---|---|
| `setup-blog-wizard.sh` | ✅ 실행됨 | blog.env 생성 |
| `install-blog-scripts.sh` | ✅ 실행됨 | 스크립트 배포 |
| `install-blog-launchd.sh` | ✅ 실행됨 | launchd 5종 |
| `blog-orchestrator.sh` | ✅ test-alert OK | 파이프라인 |
| `telegram-alert.sh` | ✅ | 실패 알림 |
| `telegram-callback-poller.sh` | ✅ 등록 | 승인 버튼 |
| `tistory-cookie-check.sh` | ✅ OK | 쿠키 검사 05:30 |
| `tistory-publish.sh` | 🔧 골격만 | post.json 본구현 필요 |
| `openrouter-call.sh` | ⬜ 키 필요 | LLM 호출 |
| `crawl-stock.sh` | ⬜ 미구현 | |
| `crawl-fmkorea-deals.sh` | ⬜ 미구현 | |
| `tistory-draft.sh` | ⬜ 미구현 | post.json 임시저장 |

### launchd 에이전트 (5종)

| Label | 스케줄 |
|---|---|
| `com.kimi.blog-stock` | 06:00 (주말 skip) |
| `com.kimi.blog-deal` | 09~21시 / 3h |
| `com.kimi.blog-telegram-poller` | 60초 |
| `com.kimi.blog-cookie-check` | 05:30 |
| `com.kimi.blog-llm-report` | 22:00 |

---

## 10. 해결한 오류 (참고)

| 증상 | 원인 | 해결 |
|---|---|---|
| GitHub docs 안 보임 | `main` 브랜치만 clone | feature 브랜치 clone → `/tmp/welcome-docs` |
| `blog.env` syntax error | vim swap 텍스트 오염 | `blog.env.example`에서 재생성 |
| Telegram 404 | URL에 `<>` 포함 / 토큰 폐기 | 토큰 재발급, URL 수정 |
| `tistory-cookies.json` 없음 | nano 저장 안 함 / JSON 문법 오류 | 전체 경로로 저장, `python3 -m json.tool` 검증 |
| `_T_ANO` 두 개 | `.tistory.com` vs `.kakao.com` | `.tistory.com` 것만 사용 |
| VM RAM 부족 | 8GB 맥미니 | VM 2048MB로 축소 |

---

## 11. 다음 작업 순서 (우선순위)

1. **foxhat 카테고리 ID** 추출 → `blog.env`에 stock/deal 카테고리 변수 추가
2. **OpenRouter API 키** → `blog.env` + OpenClaw
3. **`tistory-draft.sh`** post.json 임시저장 구현
4. **첫 수동 임시저장** 1건 (foxmong 또는 foxhat)
5. **Telegram 승인 플로우** E2E 1회
6. Finnhub / DART API 키 (주식)
7. 쿠팡 파트너스 API (핫딜)
8. `crawl-stock.sh`, `crawl-fmkorea-deals.sh` 구현
9. 애드센스·쿠팡 파트너스 신청
10. (선택) `status.foxmong.cc` Tunnel + Access

---

## 12. API·키 체크리스트

| 항목 | blog.env 변수 | 상태 |
|---|---|---|
| OpenRouter | `OPENROUTER_API_KEY` | ⬜ |
| Finnhub | `FINNHUB_API_KEY` | ⬜ |
| DART | `DART_API_KEY` | ⬜ |
| 쿠팡 파트너스 | `COUPANG_ACCESS_KEY`, `COUPANG_SECRET_KEY` | ⬜ |
| Telegram | `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID` | ✅ |
| Tistory 쿠키 | `tistory-cookies.json` | ✅ |

---

## 13. whoami 유지 여부

**유지 권장.**

| 목적 | 설명 |
|---|---|
| Tunnel E2E 검증 | Cloudflare → VM :8080 HTTPS |
| Tailscale 없이 헬스체크 | 회사 PC 등에서 브라우저만으로 확인 |
| Kuma 모니터 | `https://whoami.foxmong.cc` Up/Down |

민감 정보 노출 없음. `status.foxmong.cc`(Kuma 공개) 완료 후에도 헬스체크용으로 whoami 유지 가능.

---

## 14. 참고 문서 (맥미니 경로)

| 파일 | 내용 |
|---|---|
| `PLATFORM-HANDOFF-2026-07-04.md` | **이 파일** — 최신 진행 |
| `BLOG-AUTOMATION-MASTER.md` | 블로그 전략·아키텍처 |
| `00-HOME-SERVER-HANDOFF.md` | 홈서버 전체 |
| `guides/blog-sectors/` | 섹터 01~10 단계별 가이드 |
| `guides/cloudflare-tunnel.md` | Tunnel 설정 |
| `guides/tunnel-phase2-status-gitea.md` | status + Gitea |
| `scripts/blog/` | 블로그 스크립트 템플릿 |
| `setup-logs/` | 2026-06-11 ~ 06-14 작업 일지 |

---

## 15. GitHub

| 항목 | 값 |
|---|---|
| Repo | `Foxmong/welcome` |
| 문서·스크립트 브랜치 | `cursor/sshfs-automation-app-server-1fd4` |
| `main` | 구버전 (Python 파일 등, 블로그 docs 없음) |

맥미니 Docs 갱신:

```bash
cd /tmp && rm -rf welcome-docs
git clone -b cursor/sshfs-automation-app-server-1fd4 https://github.com/Foxmong/welcome.git welcome-docs
cp -R welcome-docs/ServerData/Docs/* /Volumes/ServerData/Docs/
cp -R welcome-docs/ServerData/Docs/scripts/blog/* /Volumes/ServerData/Docs/scripts/blog/
# 필요 시 install-blog-scripts.sh 재실행
```

---

## 16. 검증 명령 (맥미니)

```bash
# 쿠키
~/scripts/blog/tistory-cookie-check.sh --blog all
tail -3 /Volumes/ServerData/Projects/blog/logs/pipeline.log

# Telegram
~/scripts/blog/blog-orchestrator.sh test-alert

# blog.env 호스트
grep TISTORY /Volumes/ServerData/Projects/blog/config/blog.env

# launchd
launchctl list | grep com.kimi.blog

# OpenClaw
openclaw gateway status

# VM (맥미니에서)
ssh foxmong@192.168.0.113 "docker ps; curl -sf -o /dev/null -w '%{http_code}' http://127.0.0.1:3001/"
```

---

*이 문서는 대화·setup-logs·마스터 문서를 기준으로 작성됨. 비밀값(쿠키, API 토큰)은 포함하지 않음.*
