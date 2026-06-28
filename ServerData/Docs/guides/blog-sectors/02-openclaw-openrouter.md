# 02 — OpenClaw·OpenRouter

[← 01 기반](./01-foundation.md) · [다음: Tistory →](./03-tistory-publish.md)

## 목표

OpenClaw Gateway를 맥미니에서 24/7 실행하고, OpenRouter로 LLM 호출 준비.

---

## Step 1 — OpenClaw 설치

```bash
# 맥미니 터미널 (kimi)
curl -fsSL https://openclaw.ai/install.sh | bash
```

온보딩 선택:

| 단계 | 선택 |
|---|---|
| Install | QuickStart |
| LLM Provider | **OpenRouter** |
| API Key | `blog.env`의 키 |
| Base URL | `https://openrouter.ai/api/v1` |
| Agent name | `blog-orchestrator` |

---

## Step 2 — 데몬 (launchd)

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

`openclaw` 명령 없을 때:

```bash
export PATH="$(npm prefix -g)/bin:$PATH"
echo 'export PATH="$(npm prefix -g)/bin:$PATH"' >> ~/.zshrc
```

---

## Step 3 — OpenRouter Limits

1. [openrouter.ai](https://openrouter.ai) → Settings → **Limits**
2. 월 상한 설정 (권장: $20 soft cap)
3. `blog.env`와 동일 키 사용

---

## Step 4 — 모델 라우팅 (`blog.env`)

```bash
BLOG_MODEL_FILTER=google/gemini-2.0-flash-001
BLOG_MODEL_OUTLINE=anthropic/claude-3-haiku
BLOG_MODEL_STOCK=anthropic/claude-sonnet-4
BLOG_MODEL_DEAL=google/gemini-2.0-flash-001
BLOG_MODEL_PUBLISH=anthropic/claude-3-haiku

STOCK_LLM_DAILY_MAX=3
DEAL_LLM_DAILY_MAX=8
STOCK_LLM_DEEP_WEEKLY_MAX=2
LLM_CACHE_TTL_HOURS=24
```

---

## Step 5 — 스크립트 LLM 테스트

```bash
~/scripts/blog/llm-budget.sh status

~/scripts/blog/openrouter-call.sh \
  --task filter --pipeline stock \
  --cache-key test-once \
  --system "JSON만 출력" \
  --user "ticker: NVDA, reason: test" \
  --max-tokens 100
```

**확인:** 응답 출력 + `llm-budget.sh status`에 stock 1 증가

---

## Step 6 — 에이전트 역할 (OpenClaw 스킬 연동 시)

| 에이전트 | 역할 | 모델 |
|---|---|---|
| stock-researcher | 크롤 JSON | flash |
| stock-writer | 분석 HTML | sonnet |
| deal-scout | 에펨 크롤 | 스크립트 |
| deal-writer | 템플릿+소개 | flash |
| publisher | 임시저장+Telegram | haiku |

스킬 경로: `~/.openclaw/skills/` — `stock-daily-pipeline`, `deal-scan-pipeline` (구축 시 등록)

---

## 완료 기준

- [ ] `openclaw doctor` 통과
- [ ] `openclaw gateway status` running
- [ ] `openrouter-call.sh` 테스트 1회 성공
- [ ] OpenRouter Limits 설정

## 문제 해결

| 증상 | 해결 |
|---|---|
| 429 rate limit | `ALERT_RETRY_DELAY_SEC` 증가, 상한 확인 |
| API key invalid | `blog.env`와 OpenClaw 설정 일치 확인 |
| gateway down | `openclaw gateway install` 재실행 |

**다음:** [03-tistory-publish.md](./03-tistory-publish.md)
