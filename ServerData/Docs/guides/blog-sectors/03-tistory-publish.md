# 03 — Tistory·발행

[← 02 OpenClaw](./02-openclaw-openrouter.md) · [다음: Telegram →](./04-telegram-approval.md)

## 목표

Tistory 2개 개설, 쿠키·임시저장·승인 후 발행 파이프라인 연결.

> **주의:** Tistory 공식 Open API는 **2023년 종료**. `post.json` + 세션 쿠키 사용.

---

## Step 1 — 블로그 2개 개설

| 블로그 | 주제 | 카테고리 예 |
|---|---|---|
| 주식 | 국내·해외 분석 | 미국주식 / 국내주식 / ETF / 실적시즌 |
| 핫딜 | 할인 정보 | 쿠팡 / 네이버 / 생활할인 |

각 블로그:

1. [tistory.com](https://www.tistory.com) → 카카오 로그인 → 블로그 만들기
2. **관리 → 카테고리** 생성 → **카테고리 ID** 메모 (URL 또는 개발자도구)
3. `blog.env`에 호스트명 기록:

```bash
TISTORY_STOCK_HOST=your-stock.tistory.com
TISTORY_DEAL_HOST=your-deal.tistory.com
TISTORY_STOCK_CATEGORY_US=1234567
# ...
```

4. 블로그 설정 → 면책·제휴 문구 (고정 푸터)

---

## Step 2 — 쿠키 export (최초 1회)

1. Chrome에서 Tistory **관리자** 로그인
2. F12 → Application → Cookies → `*.tistory.com`
3. `TSSESSION`, `_T_ANO` 등 복사

`/Volumes/ServerData/Projects/blog/config/tistory-cookies.json`:

```json
{
  "your-stock.tistory.com": "TSSESSION=...; _T_ANO=...",
  "your-deal.tistory.com": "TSSESSION=...; ..."
}
```

```bash
chmod 600 /Volumes/ServerData/Projects/blog/config/tistory-cookies.json
```

---

## Step 3 — 쿠키 자동 검사

```bash
~/scripts/blog/tistory-cookie-check.sh --blog all
```

- 성공: 로그만
- 실패: Telegram `error` 알림 → 브라우저 재로그인 → JSON 갱신

launchd `com.kimi.blog-cookie-check` — 매일 05:30 (섹터 10에서 설치)

---

## Step 4 — post.json 임시저장 (구현 가이드)

`~/scripts/blog/tistory-draft.sh` (구축 시 작성):

```text
POST https://{host}.tistory.com/manage/post.json
Headers:
  Cookie: (tistory-cookies.json)
  Referer: https://{host}/manage/newpost
  User-Agent: Mozilla/5.0 ...
Body (JSON):
  id: "0"
  title: "..."
  content: "<html>..."
  contentType: "html"
  category: {카테고리ID}
  published: 0        ← 임시저장
  visibility: 20
  tag: "태그1,태그2"
```

**승인 후:** 동일 글 `published: 1` 또는 `tistory-publish.sh --approve`

---

## Step 5 — 수익화 신청

| 항목 | 블로그 | 비고 |
|---|---|---|
| 애드센스 | 주식 + 핫딜 | 심사 1~2주, 승인 후 스킨/본문 삽입 |
| 쿠팡 파트너스 | 핫딜 | API 키 → `blog.env` |

핫딜 본문 하단 (템플릿 자동):

```html
<p><small>이 포스팅은 쿠팡 파트너스 활동의 일환으로, 이에 따른 일정액의 수수료를 제공받습니다.</small></p>
```

주식 면책:

```html
<p><small>본 글은 투자 참고용이며, 투자 권유가 아닙니다.</small></p>
```

---

## Step 6 — 수동 발행 테스트

승인 플로우 연결 전, post.json 1회 수동 curl 또는 관리자 UI로 임시저장 확인.

---

## 완료 기준

- [ ] Tistory 2개 URL 확정
- [ ] `tistory-cookies.json` + `tistory-cookie-check.sh --blog all` OK
- [ ] 카테고리 ID `blog.env` 기록
- [ ] 임시저장 1건 성공 (수동 또는 `tistory-draft.sh`)

## 문제 해결

| 증상 | 해결 |
|---|---|
| 401 / 로그인 페이지 | 쿠키 갱신 |
| category 오류 | 카테고리 ID 재확인 |
| HTML 깨짐 | `contentType: html`, 이스케이프 확인 |

**다음:** [04-telegram-approval.md](./04-telegram-approval.md)
