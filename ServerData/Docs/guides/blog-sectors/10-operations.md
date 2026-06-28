# 10 — 운영·스케줄·점검

[← 09 SEO](./09-seo-ranking.md) · [섹터 목록](./README.md)

## 목표

launchd 24/7 운영, 일·주·월 점검 루틴 확립.

---

## Step 1 — launchd 일괄 설치

```bash
cd /Volumes/ServerData/Docs/scripts/blog
./install-blog-launchd.sh
launchctl list | grep com.kimi.blog
```

| Label | 주기 | 역할 |
|---|---|---|
| `com.kimi.blog-stock` | 06:00 매일 | 주식 (주말 skip) |
| `com.kimi.blog-deal` | 10800초 (3h) | 핫딜 |
| `com.kimi.blog-telegram-poller` | 60초 | 승인 버튼 |
| `com.kimi.blog-cookie-check` | 05:30 | 쿠키 검사 |
| `com.kimi.blog-llm-report` | 22:00 | LLM 리포트 |

로그:

```text
/Volumes/ServerData/Projects/blog/logs/launchd-*.log
/Volumes/ServerData/Projects/blog/logs/launchd-*.err
```

---

## Step 2 — 일일 점검 (5분)

```bash
# 파이프라인 로그
tail -20 /Volumes/ServerData/Projects/blog/logs/pipeline.log

# pause 플래그
ls /Volumes/ServerData/Projects/blog/config/pause-*.flag 2>/dev/null

# LLM 사용량
~/scripts/blog/llm-budget.sh status

# launchd
launchctl list | grep com.kimi.blog
```

Telegram에서 **승인 대기** 글 처리.

---

## Step 3 — 주간 점검 (15분)

- [ ] `tistory-cookie-check.sh --blog all`
- [ ] OpenRouter Usage vs `llm-budget` 비교
- [ ] Uptime Kuma에 블로그 URL 모니터 추가 (선택)
- [ ] 거절된 초안 패턴 검토 (`logs/rejected/`)

---

## Step 4 — 월간 점검 (30분)

- [ ] Search Console 상위 쿼리 → `seo-keywords.json` 반영
- [ ] watchlist 종목 조정
- [ ] 애드센스·파트너스 수익 확인
- [ ] 쿠키 갱신 필요 시 브라우저 export
- [ ] restic 백업에 `Projects/blog` 포함 확인

---

## Step 5 — 백업

`~/scripts/backup.sh`가 `Projects` 포함 시 blog.config·drafts 백업됨.  
`blog.env`·쿠키는 **민감** — Git 금지, restic만.

---

## 장애 대응 요약

| 증상 | 조치 |
|---|---|
| 파이프라인 멈춤 | `rm config/pause-*.flag` |
| Tistory 401 | 쿠키 JSON 갱신 |
| 알림 폭주 | `ALERT_COOLDOWN_SEC` 증가 |
| 맥 느림 | VM 2GB, 크롤 시간 확인 |
| 버튼 무반응 | telegram-poller launchd 재시작 |

```bash
launchctl bootout gui/$(id -u)/com.kimi.blog-telegram-poller
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.kimi.blog-telegram-poller.plist
```

---

## 0→100 최종 체크리스트

### 기반 (0~20)
- [ ] 섹터 01~04 완료
- [ ] OpenClaw + launchd

### 주식 MVP (20~50)
- [ ] 섹터 05 crawl + 초안 + 승인 1편

### 핫딜 (70~90)
- [ ] 섹터 06 E2E 1편

### 운영 (90~100)
- [ ] 섹터 07~10
- [ ] GSC·네이버
- [ ] 월 리뷰 1회 수행

---

## 참고

- **마스터:** [BLOG-AUTOMATION-MASTER.md](../../BLOG-AUTOMATION-MASTER.md)
- **홈서버:** [00-HOME-SERVER-HANDOFF.md](../../00-HOME-SERVER-HANDOFF.md)
- **스크립트:** [scripts/blog/](../../scripts/blog/)
