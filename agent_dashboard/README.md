# 에이전트 현황 대시보드

내 Cursor 계정에서 지금 **어떤 Cloud Agent가 실행 중/대기/완료** 상태인지,
어떤 브랜치와 PR에서 작업했는지를 한 화면에서 보여주는 웹 대시보드입니다.

Cursor의 공개 [Cloud Agents API](https://cursor.com/docs/cloud-agent/api/endpoints)를
사용해 실시간으로 조회합니다.

## 중요한 한계 (꼭 읽어주세요)

- **Codex(OpenAI) 등 다른 도구의 에이전트는 표시되지 않습니다.** Codex는
  Cursor와 별개의 제품이라 외부에서 조회할 수 있는 공개 API가 없습니다.
  Codex 작업 현황은 ChatGPT/Codex 자체 UI에서 확인해야 합니다.
- 이 대시보드는 **"내 Cursor 계정의 Cloud Agent"만** 보여줍니다
  (로컬 Cursor 에디터에서 돌리는 일반 채팅/에이전트 세션은 포함되지 않음).
- Cursor 공개 API 응답에는 **사용 모델명이 포함되지 않습니다.** 상태·저장소·
  브랜치·PR·시간 정보만 제공됩니다.

## 화면에 보이는 정보

| 컬럼 | 설명 |
|------|------|
| 이름 | 에이전트 실행 시 부여된 이름 (클릭 시 Cursor 에이전트 페이지로 이동) |
| 상태 | 실행 중 / 대기 / 완료 / 오류 등 |
| 저장소 | 작업 대상 GitHub 저장소 |
| 브랜치 | 에이전트가 커밋을 쌓고 있는 브랜치 |
| PR | 생성된 Pull Request 링크 (있는 경우) |
| 마지막 업데이트 | 가장 최근 활동 시각 |

10~20초 간격(기본 15초)으로 자동 새로고침됩니다.

## 설치 및 실행

```bash
cd agent_dashboard
python3 -m venv ../.venv        # 이미 만들어져 있다면 생략
../.venv/bin/pip install -r requirements.txt

cp .env.example .env
```

`.env` 파일을 열어 `CURSOR_API_KEY`를 입력하세요.
API 키는 [Cursor Dashboard → Integrations](https://cursor.com/dashboard?tab=integrations)
에서 발급받을 수 있습니다. (모델 제공사 API 키가 아니라 **Cursor 자체 API 키**입니다.)

```bash
../.venv/bin/python app.py
```

브라우저에서 `http://localhost:5000` 에 접속하면 대시보드가 보입니다.

특정 저장소만 보고 싶다면 `.env`의 `CURSOR_DASHBOARD_REPO_FILTER`에
`owner/repo` 형태로 입력하세요 (비워두면 전체 저장소의 에이전트를 표시).

## 원격/클라우드 환경에서 접속하려면

Cloud Agent VM처럼 로컬호스트에 직접 접속하기 어려운 환경이라면,
포트 포워딩이 가능한 환경에서 `python app.py`를 실행하거나,
`app.run(host="0.0.0.0", port=5000)`으로 이미 열려 있으니
해당 VM의 5000번 포트를 외부에 노출하는 방식으로 접속하면 됩니다.

## 파일 구성

| 파일 | 설명 |
|------|------|
| `app.py` | Flask 서버. `/` (화면), `/api/agents` (JSON API) |
| `cursor_client.py` | Cursor Cloud Agents API(v1) 클라이언트 |
| `templates/index.html` | 대시보드 화면 (자동 새로고침 테이블) |
| `.env.example` | API 키 등 환경변수 템플릿 |
