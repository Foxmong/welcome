# -*- coding: utf-8 -*-
"""
Cursor Cloud Agents 공개 API(v1) 클라이언트.

문서: https://cursor.com/docs/cloud-agent/api/endpoints
인증: Authorization: Bearer <CURSOR_API_KEY>

공개 API 한계 (알아두어야 할 점):
  - 에이전트가 어떤 모델을 쓰는지는 v1 API 응답에 포함되어 있지 않다.
    (생성 시 모델을 "지정"할 수는 있지만, 조회 시에는 돌아오지 않음)
  - 브랜치/PR 정보는 "최신 실행(run)"을 따로 조회해야 얻을 수 있다.
"""

import os
from dataclasses import dataclass, field

import requests

API_BASE = "https://api.cursor.com"
DEFAULT_TIMEOUT = 10


class CursorApiError(RuntimeError):
    pass


@dataclass
class AgentRow:
    id: str
    name: str
    status: str
    url: str
    created_at: str | None
    updated_at: str | None
    repo_urls: list[str] = field(default_factory=list)
    branches: list[dict] = field(default_factory=list)  # [{repoUrl, branch, prUrl}]

    @property
    def primary_branch(self) -> str | None:
        return self.branches[0].get("branch") if self.branches else None

    @property
    def primary_pr_url(self) -> str | None:
        return self.branches[0].get("prUrl") if self.branches else None

    @property
    def primary_repo(self) -> str | None:
        if self.branches:
            return self.branches[0].get("repoUrl")
        return self.repo_urls[0] if self.repo_urls else None


class CursorClient:
    def __init__(self, api_key: str | None = None):
        self.api_key = api_key or os.environ.get("CURSOR_API_KEY")
        if not self.api_key:
            raise CursorApiError(
                "CURSOR_API_KEY 가 설정되지 않았습니다. "
                "https://cursor.com/dashboard?tab=integrations 에서 API 키를 발급받아 "
                ".env 파일에 넣어주세요."
            )

    def _get(self, path: str, params: dict | None = None) -> dict:
        resp = requests.get(
            f"{API_BASE}{path}",
            headers={"Authorization": f"Bearer {self.api_key}"},
            params=params,
            timeout=DEFAULT_TIMEOUT,
        )
        if resp.status_code == 401:
            raise CursorApiError("API 키가 유효하지 않습니다 (401 Unauthorized).")
        resp.raise_for_status()
        return resp.json()

    def list_agents_basic(self, limit: int = 100) -> list[dict]:
        """모든 에이전트의 기본 정보(id/name/status/url/시간)를 가져온다."""
        items: list[dict] = []
        cursor = None
        while True:
            params: dict = {"limit": min(limit, 100)}
            if cursor:
                params["cursor"] = cursor
            payload = self._get("/v1/agents", params=params)
            items.extend(payload.get("items", []))
            cursor = payload.get("nextCursor")
            if not cursor or len(items) >= limit:
                break
        return items[:limit]

    def get_agent_detail(self, agent_id: str) -> dict:
        return self._get(f"/v1/agents/{agent_id}")

    def get_run(self, agent_id: str, run_id: str) -> dict:
        return self._get(f"/v1/agents/{agent_id}/runs/{run_id}")

    def list_agents(self, limit: int = 100, repo_filter: str | None = None) -> list[AgentRow]:
        """대시보드에 표시할 형태로 에이전트 목록을 조립한다.

        기본 목록 조회 후, 각 에이전트의 저장소/브랜치/PR 정보를 보강하기 위해
        상세 조회와 최신 run 조회를 추가로 수행한다 (표시용 정보 보강 목적).
        """
        rows: list[AgentRow] = []
        for item in self.list_agents_basic(limit=limit):
            row = AgentRow(
                id=item.get("id", ""),
                name=item.get("name") or "(이름 없음)",
                status=item.get("status", "UNKNOWN"),
                url=item.get("url", ""),
                created_at=item.get("createdAt"),
                updated_at=item.get("updatedAt"),
            )

            try:
                detail = self.get_agent_detail(row.id)
                row.repo_urls = [r.get("url", "") for r in detail.get("repos", [])]
            except requests.RequestException:
                pass

            latest_run_id = item.get("latestRunId")
            if latest_run_id:
                try:
                    run = self.get_run(row.id, latest_run_id)
                    git_info = run.get("git") or {}
                    row.branches = git_info.get("branches", [])
                except requests.RequestException:
                    pass

            if repo_filter and repo_filter.lower() not in " ".join(
                row.repo_urls + [b.get("repoUrl", "") for b in row.branches]
            ).lower():
                continue

            rows.append(row)

        return rows
