# -*- coding: utf-8 -*-
"""
Cursor Cloud Agent 현황 대시보드.

내 계정의 모든 Cursor Cloud Agent(작업 중/유휴/완료 등)를
브랜치, PR, 상태와 함께 한 화면에서 볼 수 있는 웹 대시보드.

주의: Codex 등 다른 제품의 에이전트는 Cursor 공개 API에 노출되지 않으므로
      이 대시보드에는 표시되지 않습니다. (Codex 전용 UI에서 별도 확인 필요)

실행:
  pip install -r requirements.txt
  cp .env.example .env   # CURSOR_API_KEY 입력
  python app.py
  → http://localhost:5000 접속
"""

import os

from dotenv import load_dotenv
from flask import Flask, jsonify, render_template

from cursor_client import CursorApiError, CursorClient

load_dotenv(os.path.join(os.path.dirname(__file__), ".env"))

app = Flask(__name__)

REPO_FILTER = os.environ.get("CURSOR_DASHBOARD_REPO_FILTER") or None
REFRESH_SECONDS = int(os.environ.get("CURSOR_DASHBOARD_REFRESH_SECONDS", "15"))

# 대시보드에서 상태값을 한국어 뱃지로 보여주기 위한 매핑
STATUS_LABELS = {
    "ACTIVE": "실행 중",
    "RUNNING": "실행 중",
    "CREATING": "생성 중",
    "FINISHED": "완료",
    "IDLE": "대기",
    "ERROR": "오류",
    "CANCELLED": "취소됨",
    "EXPIRED": "만료",
}


@app.route("/")
def index():
    return render_template("index.html", refresh_seconds=REFRESH_SECONDS)


@app.route("/api/agents")
def api_agents():
    try:
        client = CursorClient()
        rows = client.list_agents(repo_filter=REPO_FILTER)
    except CursorApiError as exc:
        return jsonify({"error": str(exc)}), 400

    agents = [
        {
            "id": r.id,
            "name": r.name,
            "status": r.status,
            "statusLabel": STATUS_LABELS.get(r.status, r.status),
            "url": r.url,
            "repo": r.primary_repo,
            "branch": r.primary_branch,
            "prUrl": r.primary_pr_url,
            "createdAt": r.created_at,
            "updatedAt": r.updated_at,
        }
        for r in rows
    ]
    # 최근 업데이트 순으로 정렬
    agents.sort(key=lambda a: a["updatedAt"] or "", reverse=True)
    return jsonify({"agents": agents, "count": len(agents)})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
