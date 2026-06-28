# 01 — 기반·환경 구축

[← 섹터 목록](./README.md) · [다음: OpenClaw →](./02-openclaw-openrouter.md)

## 목표

맥미니 8GB에서 블로그 파이프라인이 돌아갈 **폴더·설정·스크립트**를 준비합니다.

## 사전 조건

- 맥미니 `kimi@192.168.0.100` SSH 접속 가능
- ServerData 마운트: `/Volumes/ServerData`
- 홈서버 VM·restic 이미 운영 중 ([00-HOME-SERVER-HANDOFF.md](../../00-HOME-SERVER-HANDOFF.md))

---

## Step 1 — VM RAM 2GB 축소

블로그·OpenClaw는 **맥에서** 돌립니다. VM은 Kuma+Tunnel만.

```bash
# 맥미니
VBoxManage controlvm centos-server poweroff
VBoxManage modifyvm centos-server --memory 2048
VBoxManage startvm centos-server --type headless
```

**확인:** Activity Monitor에서 메모리 여유 ~2GB 이상

---

## Step 2 — blog 폴더 구조

```bash
mkdir -p /Volumes/ServerData/Projects/blog/{stock,deals}/{raw,drafts,approved,published,logs}
mkdir -p /Volumes/ServerData/Projects/blog/config
```

```text
Projects/blog/
├── config/          blog.env, cookies, watchlist, seo-keywords
├── stock/           주식 raw, drafts, published
├── deals/           핫딜
└── logs/            pipeline.log, llm-budget, launchd
```

---

## Step 3 — 설정 마법사

```bash
cd /Volumes/ServerData/Docs/scripts/blog
chmod +x setup-blog-wizard.sh install-blog-scripts.sh
./setup-blog-wizard.sh
```

입력 항목:

| 변수 | 설명 |
|---|---|
| `TELEGRAM_BOT_TOKEN` | BotFather `/newbot` |
| `TELEGRAM_CHAT_ID` | wizard가 getUpdates로 자동 시도 |
| `TISTORY_STOCK_HOST` | 예: `my-stock.tistory.com` |
| `TISTORY_DEAL_HOST` | 예: `my-deal.tistory.com` |
| `OPENROUTER_API_KEY` | openrouter.ai |

생성 파일: `/Volumes/ServerData/Projects/blog/config/blog.env` (chmod 600)

추가 API 키 (나중에 vi로):

```bash
FINNHUB_API_KEY=...
DART_API_KEY=...
COUPANG_ACCESS_KEY=...
COUPANG_SECRET_KEY=...
```

---

## Step 4 — 스크립트 설치

```bash
./install-blog-scripts.sh
```

설치 위치: `~/scripts/blog/`  
복사되는 config: `deal-template.html`, `stock-watchlist.json`, `seo-keywords.json`, `editorial-checklist.txt`

**확인:**

```bash
ls -la ~/scripts/blog/
ls -la /Volumes/ServerData/Projects/blog/config/
```

---

## Step 5 — 스케줄 겹침 확인

| 시간 | 작업 | 충돌 방지 |
|---|---|---|
| 03:00 | restic | 블로그 크롤과 분리됨 |
| 05:30~22:00 | 블로그 launchd | restic 이후 |

---

## 완료 기준

- [ ] VM RAM 2048MB
- [ ] `blog.env` 존재, Telegram·OpenRouter 키 입력
- [ ] `~/scripts/blog/` 15개+ 스크립트
- [ ] `Projects/blog/` 하위 폴더 생성

## 문제 해결

| 증상 | 해결 |
|---|---|
| `bad interpreter ^M` | `sed -i '' 's/\r$//' ~/scripts/blog/*.sh` |
| ServerData 없음 | 디스크 마운트·재부팅 확인 |
| wizard chat_id 실패 | 봇에 `/start` 후 수동 입력 |

**다음:** [02-openclaw-openrouter.md](./02-openclaw-openrouter.md)
