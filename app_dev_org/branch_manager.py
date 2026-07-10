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

주의 (중요): 위 격리는 "AI가 작업하는 동안" 자동으로 지켜지는 안전장치일 뿐,
`project/<이름>` 브랜치를 사람이 의도적으로 PR을 열어 조직 브랜치에 머지하면
그 시점부터는 당연히 조직 브랜치에 그 파일들이 반영된다 (머지란 원래 그런
행위이기 때문). 즉 이 시스템은 "실수로/자동으로 섞이는 것"을 막아주는 것이지,
"의도적인 머지"까지 막아주지는 않는다.

정말로 조직 저장소와 물리적으로 완전히 분리하고 싶다면(=애초에 머지할 대상
자체가 없게 만들고 싶다면) `export_project()`로 별도의 새 GitHub 저장소로
내보내면 된다. 그러면 프로젝트는 조직 저장소와 아예 다른 저장소에 있으므로
실수로 PR을 잘못 열어도 조직 브랜치에는 영향을 줄 수 없다.
"""

import json
import os
import re
import shutil
import subprocess
import tempfile
from pathlib import Path


class BranchManager:
    def __init__(self, repo_root: str, base_branch: str | None = None):
        self.repo_root = Path(repo_root).resolve()
        # worktree 는 .gitignore 처리된 전용 폴더에 두어
        # 조직 브랜치의 추적 파일을 오염시키지 않는다.
        self.projects_root = self.repo_root / ".projects"
        # 베이스 브랜치 우선순위:
        #   1) 명시적 인자  2) ORG_BASE_BRANCH 환경변수(.env)  3) 현재 브랜치
        # 조직이 main 에 자리잡은 뒤에는 .env 에 ORG_BASE_BRANCH=main 을 넣어두면
        # 어느 브랜치에서 실행하든 항상 main 에서 분기되어 안전하다.
        self.base_branch = (
            base_branch
            or os.environ.get("ORG_BASE_BRANCH")
            or self._current_branch()
        )

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
        - 폴더:   .projects/<이름>/  (gitignore 처리되어 조직 브랜치와 분리)
        """
        slug = self._slugify(project_name)
        branch = f"project/{slug}"
        worktree_path = self.projects_root / slug

        # 안전 가드 1: 프로젝트 브랜치 위에서 또 프로젝트를 분기하는 실수 방지.
        # (A앱 브랜치에서 B앱을 만들면 B에 A의 파일이 섞여 들어간다)
        if self.base_branch.startswith("project/"):
            raise RuntimeError(
                f"현재 베이스가 프로젝트 브랜치({self.base_branch})입니다.\n"
                f"새 프로젝트는 반드시 조직 브랜치(main)에서 분기해야 합니다.\n"
                f"해결: 조직 브랜치로 이동(git checkout main)하거나, "
                f".env 에 ORG_BASE_BRANCH=main 을 설정하세요."
            )

        # 안전 가드 2: 같은 이름의 브랜치/폴더가 이미 있으면 친절하게 안내.
        if worktree_path.exists():
            raise FileExistsError(
                f"프로젝트 폴더가 이미 존재합니다: {worktree_path}\n"
                f"다른 이름을 쓰거나, 'python main.py clean \"{project_name}\"' 으로 정리하세요."
            )
        existing = self._git("branch", "--list", branch)
        if existing:
            raise FileExistsError(
                f"'{branch}' 브랜치가 이미 존재합니다 (이전에 만든 프로젝트).\n"
                f"이어서 작업하려면: git worktree add .projects/{slug} {branch}\n"
                f"완전히 새로 시작하려면: git branch -D {branch} 후 다시 실행하세요."
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

        # export_project() 가 "이 프로젝트가 정확히 어느 브랜치에서 분기됐는지"를
        # 나중에도 알 수 있도록, worktree 밖(.projects/<이름>.meta.json)에 기록해둔다.
        # (worktree 안에 두면 커밋에 섞이므로 일부러 밖에 둔다.)
        self._write_meta(slug, {"base_branch": self.base_branch})
        return worktree_path

    def _meta_path(self, slug: str) -> Path:
        return self.projects_root / f"{slug}.meta.json"

    def _write_meta(self, slug: str, data: dict) -> None:
        self._meta_path(slug).write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")

    def _read_meta(self, slug: str) -> dict:
        path = self._meta_path(slug)
        if path.exists():
            return json.loads(path.read_text(encoding="utf-8"))
        return {}

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
        self._meta_path(slug).unlink(missing_ok=True)

    def list_projects(self) -> list[str]:
        """현재 존재하는 프로젝트 브랜치 목록을 반환한다."""
        out = self._git("branch", "--list", "project/*", "--format=%(refname:short)")
        return [line for line in out.splitlines() if line]

    def status_report(self) -> list[dict]:
        """프로젝트별 브랜치/작업폴더/베이스/최근 커밋을 한눈에 보여줄 자료를 만든다."""
        report = []
        for branch in self.list_projects():
            slug = branch.removeprefix("project/")
            worktree_path = self.projects_root / slug
            meta = self._read_meta(slug)
            last_commit = self._git("log", "-1", "--format=%h %s (%cr)", branch)
            report.append({
                "branch": branch,
                "worktree": str(worktree_path) if worktree_path.exists() else None,
                "base_branch": meta.get("base_branch", "(기록 없음)"),
                "last_commit": last_commit,
            })
        return report

    def export_project(
        self,
        project_name: str,
        remote_url: str | None = None,
        new_repo_name: str | None = None,
        private: bool = True,
    ) -> str:
        """프로젝트를 조직 저장소와 완전히 물리적으로 분리된 새 저장소로 내보낸다.

        `project/<이름>` 브랜치의 git 이력을 그대로 push하는 게 아니라,
        **분기 시점(base_branch) 이후 새로 추가/변경된 파일만** 골라
        완전히 새로운 git 저장소를 만든다 (org에서 물려받은 기존 파일은
        제외됨). 이렇게 하면:
          - 조직 브랜치의 파일/이력이 새 저장소에 전혀 섞이지 않는다.
          - 물리적으로 다른 저장소이므로, 나중에 누가 실수로 PR/머지를
            시도해도 조직 저장소의 브랜치에는 애초에 반영될 수 없다.

        Args:
            remote_url: 이미 만들어둔 빈 GitHub 저장소 URL. 지정하면 바로 push.
            new_repo_name: remote_url이 없을 때, `gh repo create`로 새로
                만들 저장소 이름 (로컬에 GitHub CLI `gh` 로그인이 필요).
            private: new_repo_name 사용 시 비공개 저장소로 만들지 여부.

        Returns:
            push된 원격 저장소의 URL 또는 이름.
        """
        if not remote_url and not new_repo_name:
            raise ValueError("remote_url 또는 new_repo_name 중 하나는 반드시 지정해야 합니다.")

        slug = self._slugify(project_name)
        worktree_path = self.projects_root / slug
        if not worktree_path.exists():
            raise FileNotFoundError(
                f"프로젝트 폴더가 없습니다: {worktree_path}\n"
                f"먼저 create_project_workspace()로 프로젝트를 만드세요."
            )

        meta = self._read_meta(slug)
        fork_base_branch = meta.get("base_branch", self.base_branch)

        # 분기 시점(base_branch) 대비 새로 생기거나 바뀐 파일만 골라낸다.
        # (--diff-filter=ACMR: 추가/복사/수정/이름변경만, 삭제된 파일은 제외)
        # -z: 한글 등 non-ASCII 파일명이 8진수로 escape되지 않도록 NUL 구분 사용.
        diff_output = self._git(
            "diff", "-z", "--name-only", "--diff-filter=ACMR",
            f"{fork_base_branch}...project/{slug}",
        )
        changed_files = [line for line in diff_output.split("\x00") if line]

        if not changed_files:
            raise ValueError(
                f"'{project_name}' 프로젝트에 새로 추가/변경된 파일이 없습니다. "
                f"(조직 브랜치 '{fork_base_branch}' 대비 diff 없음)"
            )

        export_dir = Path(tempfile.mkdtemp(prefix=f"export-{slug}-"))
        try:
            for rel_path in changed_files:
                src = worktree_path / rel_path
                if not src.exists():
                    continue  # 방어적 처리: 혹시 워크트리에서 이미 지워진 경우
                dest = export_dir / rel_path
                dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(src, dest)

            self._git("init", "-q", "-b", "main", cwd=export_dir)
            self._git("add", "-A", cwd=export_dir)
            self._git(
                "commit", "-q", "-m",
                f"feat: {project_name} 초기 버전 (조직 저장소에서 분리하여 내보냄)",
                cwd=export_dir,
            )

            if remote_url:
                self._git("remote", "add", "origin", remote_url, cwd=export_dir)
                self._git("push", "-u", "origin", "main", cwd=export_dir)
                return remote_url

            subprocess.run(
                [
                    "gh", "repo", "create", new_repo_name,
                    "--private" if private else "--public",
                    "--source", str(export_dir),
                    "--remote", "origin",
                    "--push",
                ],
                check=True,
                cwd=export_dir,
            )
            return new_repo_name
        finally:
            shutil.rmtree(export_dir, ignore_errors=True)
