# 04 — Telegram·승인 워크플로

[← 03 Tistory](./03-tistory-publish.md) · [다음: 주식 →](./05-stock-pipeline.md)

## 목표

초안 완료 시 Telegram 알림 → [승인]/[거절] 버튼 → 자동 발행·폐기.

---

## Step 1 — 봇 생성

1. Telegram에서 [@BotFather](https://t.me/BotFather)
2. `/newbot` → 이름·username
3. 토큰 복사 → `blog.env`의 `TELEGRAM_BOT_TOKEN`

---

## Step 2 — chat_id

```bash
# 봇에게 아무 메시지 전송 후
curl "https://api.telegram.org/bot<TOKEN>/getUpdates"
# result[].message.chat.id 확인
```

또는 `setup-blog-wizard.sh`가 자동 시도.

---

## Step 3 — 실패 알림 테스트

```bash
~/scripts/blog/blog-orchestrator.sh test-alert
```

Telegram에 info / warn / error 3건 수신 확인.

---

## Step 4 — 승인 요청 전송

초안 meta 파일 필요: `drafts/{id}.meta.json`

```json
{
  "title": "엔비디아 2026 Q1 실적 — EPS 정리",
  "summary": "3줄 요약...",
  "preview_url": "https://your-stock.tistory.com/manage/...",
  "draft_id": "20260615-nvda"
}
```

```bash
~/scripts/blog/telegram-approval.sh \
  --pipeline stock \
  --draft-id 20260615-nvda
```

메시지에 **30초 체크리스트** 포함 (숫자·가격·AI 냄새·이미지).

---

## Step 5 — 승인/거절 폴링

```bash
./install-blog-launchd.sh   # com.kimi.blog-telegram-poller 포함
```

또는 수동 1회:

```bash
~/scripts/blog/telegram-callback-poller.sh once
```

| 버튼 | 동작 |
|---|---|
| ✅ 승인 | `tistory-publish.sh --approve {id} --pipeline stock` |
| ❌ 거절 | drafts → logs/rejected 이동 |

---

## Step 6 — 승인 품질 게이트

`config/editorial-checklist.txt` 참고.

**주식:** 숫자·출처·투자권유 없음  
**핫딜:** 파트너스 링크·가격·제휴 문구

거절 후 1~2문장 수동 수정 → 재초안 (월 몇 건이면 충분).

---

## 완료 기준

- [ ] `test-alert` 3건 수신
- [ ] 승인 요청 메시지 + 인라인 버튼 표시
- [ ] 승인 클릭 → `tistory-publish.sh` 로그
- [ ] `launchctl list | grep telegram-poller` 등록

## 문제 해결

| 증상 | 해결 |
|---|---|
| 메시지 안 옴 | `TELEGRAM_CHAT_ID`, 봇 차단 해제 |
| 버튼 무반응 | poller launchd 상태, offset 파일 확인 |
| 알림 폭주 | `ALERT_COOLDOWN_SEC=3600` |

**다음:** [05-stock-pipeline.md](./05-stock-pipeline.md)
