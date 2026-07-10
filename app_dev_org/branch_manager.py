# -*- coding: utf-8 -*-
"""
프로젝트 브랜치 격리 관리자.

새 프로젝트를 시작할 때마다 `git worktree`를 사용해
조직(베이스) 브랜치와 완전히 격리된 프로젝트 브랜치를 만든다.

핵심 아이디어:
  - 브랜치 격리: 프로젝트마다 `project/<이름>` 브랜치를 새로 딴다.
  - 디렉터리 격리: worktree 덕분에 프로젝트 파일이 별도 폴더에 체크아웃되어,
    조직 브랜치의 작업 디렉터리는 파일 하나도 바뀌지 않는다.
  - 커밋 격리: 산출물 커밋은 프로젝트 브랜치에만 쌓인다.

즉, 조직 브랜치는 "읽기 전용 템플릿"처럼 보존되고,
모든 프로젝트 작업은 자기 브랜치/폴더 안에서만 일어난다.
"""

import re
import subprocess
from pathlib import Path


class BranchManager:
    def __init__(self, repo_root: str, base_branch: str | None = None):
        self.repo_root = Path(repo_root).resolve()
        # worktree 는 저장소 밖(형제 디렉터리)에 두어 조직 브랜치 폴더를 오염시키지 않는다.
        self.projects_root = self.repo_root.parent / f"{self.repo_root.name}-projects"
        self.base_branch = base_branch or self._current_branch()

    def _git(self, *args: str, cwd: Path | None = None) -> str:
        result = subprocess.run(
            ["git", *args],
            cwd=cwd or self.repo_root,
            capture_output=True,
            text=True,
            check=True,
        )
        return result.stdout.strip()

    def _current_branch(self) -> str:
        return self._git("rev-parse", "--abbrev-ref", "HEAD")

    @staticmethod
    def _slugify(name: str) -> str:
        """프로젝트 이름을 브랜치 이름에 쓸 수 있게 정리한다."""
        slug = re.sub(r"[^a-zA-Z0-9가-힣_-]+", "-", name.strip()).strip("-").lower()
        return slug or "project"

    def create_project_workspace(self, project_name: str) -> Path:
        """격리된 프로젝트 브랜치 + 작업 폴더(worktree)를 만들어 경로를 반환한다.

        - 브랜치: project/<이름>  (조직 브랜치에서 분기, 이후 완전 독립)
        - 폴더:   <저장소>-projects/<이름>/  (조직 브랜치 폴더와 물리적으로 분리)
        """
        slug = self._slugify(project_name)
        branch = f"project/{slug}"
        worktree_path = self.projects_root / slug

        if worktree_path.exists():
            raise FileExistsError(
                f"프로젝트 폴더가 이미 존재합니다: {worktree_path}\n"
                f"다른 이름을 쓰거나 remove_project_workspace()로 정리하세요."
            )

        self.projects_root.mkdir(parents=True, exist_ok=True)

        # 조직(베이스) 브랜치에서 새 프로젝트 브랜치를 분기해 별도 폴더에 체크아웃.
        # 이 시점 이후 조직 브랜치는 어떤 식으로도 수정되지 않는다.
        self._git(
            "worktree", "add",
            "-b", branch,
            str(worktree_path),
            self.base_branch,
        )
        return worktree_path

    def commit_project(self, worktree_path: Path, message: str) -> None:
        """프로젝트 브랜치에만 산출물을 커밋한다 (조직 브랜치는 영향 없음)."""
        self._git("add", "-A", cwd=worktree_path)
        status = self._git("status", "--porcelain", cwd=worktree_path)
        if status:
            self._git("commit", "-m", message, cwd=worktree_path)

    def remove_project_workspace(self, project_name: str, delete_branch: bool = False) -> None:
        """프로젝트 작업 폴더를 정리한다. 브랜치는 기본적으로 보존한다."""
        slug = self._slugify(project_name)
        worktree_path = self.projects_root / slug
        self._git("worktree", "remove", "--force", str(worktree_path))
        if delete_branch:
            self._git("branch", "-D", f"project/{slug}")

    def list_projects(self) -> list[str]:
        """현재 존재하는 프로젝트 브랜치 목록을 반환한다."""
        out = self._git("branch", "--list", "project/*", "--format=%(refname:short)")
        return [line for line in out.splitlines() if line]
