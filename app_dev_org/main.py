# -*- coding: utf-8 -*-
"""
앱 개발 조직 실행 진입점 (CLI).

사용법:
  # [A 모드] 새 프로젝트 명령 (격리 브랜치 생성 → crewAI 조직 실행 → 결과 커밋)
  #          LLM API 키 필요
  python main.py new "todo-app" "간단한 할 일 관리 웹앱을 만들어줘. 추가/완료/삭제 기능 필요."

  # [B 모드] 격리 작업공간 + 산출물 템플릿만 생성 (API 키 불필요)
  #          이후 에이전트(Codex/Cursor)가 직접 4역할을 수행하며 템플릿을 채움
  python main.py prepare "todo-app" "간단한 할 일 관리 웹앱. 추가/완료/삭제 기능 필요."

  # [B 모드] 작업 완료 후 산출물을 프로젝트 브랜치에 커밋 (API 키 불필요)
  python main.py finish "todo-app"

  # 진행 중인 프로젝트 브랜치 목록 확인
  python main.py list

  # 프로젝트별 브랜치/작업폴더/베이스/최근 커밋 한눈에 보기
  python main.py status

  # 프로젝트 작업 폴더 정리 (브랜치는 보존)
  python main.py clean "todo-app"

  # 프로젝트를 조직 저장소와 물리적으로 분리된 새 저장소로 내보내기
  # (PR/머지를 하더라도 조직 브랜치에는 절대 영향을 줄 수 없게 만들고 싶을 때)
  python main.py export "todo-app" --new-repo "todo-app"          # gh CLI로 새 저장소 생성 후 push
  python main.py export "todo-app" --repo-url "<이미 만든 빈 저장소 URL>"

동작 순서 (new 명령):
  1. BranchManager 가 조직 브랜치에서 project/<이름> 브랜치를 분기하고,
     별도 폴더(worktree)에 체크아웃한다. → 조직 브랜치 완전 격리
  2. crewAI 조직(PM→아키텍트→개발자→QA)이 순차적으로 일하며
     산출물을 그 격리 폴더 안에만 저장한다.
  3. 산출물을 프로젝트 브랜치에 커밋한다. 조직 브랜치는 변경 0건.
"""

import os
import sys
from pathlib import Path

from dotenv import load_dotenv

from branch_manager import BranchManager

REPO_ROOT = Path(__file__).resolve().parent.parent


def _check_llm_key() -> None:
    """LLM API 키가 없으면 crewAI 실행 도중 긴 traceback 이 터진다.
    브랜치를 만들기 전에 먼저 확인해서 친절하게 안내한다."""
    known_keys = ["OPENAI_API_KEY", "ANTHROPIC_API_KEY", "GEMINI_API_KEY", "GOOGLE_API_KEY"]
    if not any(os.environ.get(k) for k in known_keys):
        print("LLM API 키가 설정되어 있지 않습니다.")
        print("app_dev_org/.env.example 을 .env 로 복사한 뒤 키를 입력하세요:")
        print("  cp .env.example .env")
        print("  (예: OPENAI_API_KEY=sk-... 또는 MODEL + ANTHROPIC_API_KEY)")
        sys.exit(1)


def cmd_new(project_name: str, requirements: str) -> None:
    _check_llm_key()
    from crew import build_app_dev_crew  # crewai 임포트가 느려서 키 확인 후에 로드

    manager = BranchManager(str(REPO_ROOT))
    print(f"[1/3] 격리된 프로젝트 브랜치 생성 중... (베이스: {manager.base_branch})")
    worktree = manager.create_project_workspace(project_name)
    print(f"      브랜치: project/{manager._slugify(project_name)}")
    print(f"      폴더:   {worktree}")

    print("[2/3] 앱 개발 조직(crew) 가동: PM → 아키텍트 → 개발자 → QA")
    crew = build_app_dev_crew(
        project_name=project_name,
        requirements=requirements,
        output_dir=str(worktree),
    )
    result = crew.kickoff()

    print("[3/3] 산출물을 프로젝트 브랜치에 커밋 중...")
    manager.commit_project(worktree, f"feat: {project_name} 초기 산출물 (crewAI 자동 생성)")

    print("\n===== 완료 =====")
    print(f"산출물 위치:        {worktree}/docs/")
    print(f"메시지 전달 로그:    {worktree}/logs/handoff.md")
    print("                    (PM→아키텍트→개발자→QA 순서로 무엇이 전달됐는지 기록됨)")
    print(f"최종 결과 요약:\n{result}")
    print("\n조직 브랜치는 전혀 수정되지 않았습니다. (git status 로 확인 가능)")


def cmd_prepare(project_name: str, requirements: str) -> None:
    """B 모드 1단계: API 키 없이 격리 작업공간과 산출물 템플릿을 만든다.

    안전 가드(new 와 동일)를 재사용하므로, 수동 git worktree 명령보다 안전하다.
    """
    from scaffold import scaffold_project

    manager = BranchManager(str(REPO_ROOT))
    print(f"[1/2] 격리된 프로젝트 브랜치 생성 중... (베이스: {manager.base_branch})")
    worktree = manager.create_project_workspace(project_name)
    print(f"      브랜치: project/{manager._slugify(project_name)}")
    print(f"      폴더:   {worktree}")

    print("[2/2] B 모드 산출물 템플릿 생성 중...")
    created = scaffold_project(worktree, project_name, requirements)
    manager.commit_project(worktree, f"chore: {project_name} 프로젝트 골격 생성 (B 모드)")

    print("\n===== 준비 완료 =====")
    print(f"작업 폴더: {worktree}")
    print("생성된 템플릿:")
    for path in created:
        print(f"  - {path}")
    print("\n다음 순서 (에이전트가 수행):")
    print(f"  1. {worktree}/PROJECT_BRIEF.md 의 요구사항과 체크리스트 확인")
    print("  2. PM → 아키텍트 → 개발자 → QA 순서로 docs/ 템플릿을 채우고 코드 작성")
    print("  3. 각 단계 완료 시 logs/handoff.md 에 기록")
    print(f'  4. 완료 후: python main.py finish "{project_name}"')


def cmd_finish(project_name: str) -> None:
    """B 모드 마무리: 산출물을 프로젝트 브랜치에 커밋한다 (API 키 불필요)."""
    manager = BranchManager(str(REPO_ROOT))
    slug = manager._slugify(project_name)
    worktree = manager.projects_root / slug
    if not worktree.exists():
        print(f"[중단] 작업 폴더가 없습니다: {worktree}")
        print('먼저 python main.py prepare "<프로젝트이름>" "<요구사항>" 을 실행하세요.')
        sys.exit(1)
    manager.commit_project(worktree, f"feat: {project_name} 산출물 (B 모드, 에이전트 단독 수행)")
    print(f"커밋 완료: project/{slug} 브랜치")
    print("조직 브랜치는 전혀 수정되지 않았습니다. (git status 로 확인 가능)")


def cmd_list() -> None:
    manager = BranchManager(str(REPO_ROOT))
    projects = manager.list_projects()
    if not projects:
        print("진행 중인 프로젝트 브랜치가 없습니다.")
    else:
        print("프로젝트 브랜치 목록:")
        for p in projects:
            print(f"  - {p}")


def cmd_status() -> None:
    manager = BranchManager(str(REPO_ROOT))
    report = manager.status_report()
    if not report:
        print("진행 중인 프로젝트가 없습니다.")
        return
    print(f"프로젝트 현황 ({len(report)}개):\n")
    for item in report:
        print(f"  {item['branch']}")
        print(f"    베이스 브랜치: {item['base_branch']}")
        print(f"    작업 폴더:     {item['worktree'] or '(정리됨 - 브랜치만 남음)'}")
        print(f"    최근 커밋:     {item['last_commit']}")
        print()


def cmd_clean(project_name: str) -> None:
    manager = BranchManager(str(REPO_ROOT))
    manager.remove_project_workspace(project_name)
    print(f"'{project_name}' 작업 폴더를 정리했습니다. (브랜치는 보존됨)")


def cmd_export(
    project_name: str,
    remote_url: str | None,
    new_repo_name: str | None,
    public: bool,
) -> None:
    manager = BranchManager(str(REPO_ROOT))
    print(f"'{project_name}' 프로젝트를 조직 저장소와 분리된 새 저장소로 내보내는 중...")
    target = manager.export_project(
        project_name,
        remote_url=remote_url,
        new_repo_name=new_repo_name,
        private=not public,
    )
    print(f"\n완료: {target}")
    print("이제 이 프로젝트는 조직 저장소와 물리적으로 다른 저장소에 있습니다.")
    print("이 프로젝트를 나중에 PR/머지해도 조직 저장소의 브랜치에는 절대 영향을 줄 수 없습니다.")
    print(f"(조직 저장소 쪽 project/{manager._slugify(project_name)} 브랜치는 백업용으로 남겨둬도 되고, 'python main.py clean' 으로 정리해도 됩니다.)")


def main() -> None:
    load_dotenv(Path(__file__).resolve().parent / ".env")

    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    command = sys.argv[1]
    if command == "new":
        if len(sys.argv) < 4:
            print('사용법: python main.py new "<프로젝트이름>" "<요구사항>"')
            sys.exit(1)
        try:
            cmd_new(sys.argv[2], sys.argv[3])
        except (RuntimeError, FileExistsError) as exc:
            print(f"\n[중단] {exc}")
            sys.exit(1)
    elif command == "prepare":
        if len(sys.argv) < 4:
            print('사용법: python main.py prepare "<프로젝트이름>" "<요구사항>"')
            sys.exit(1)
        try:
            cmd_prepare(sys.argv[2], sys.argv[3])
        except (RuntimeError, FileExistsError) as exc:
            print(f"\n[중단] {exc}")
            sys.exit(1)
    elif command == "finish":
        if len(sys.argv) < 3:
            print('사용법: python main.py finish "<프로젝트이름>"')
            sys.exit(1)
        cmd_finish(sys.argv[2])
    elif command == "list":
        cmd_list()
    elif command == "status":
        cmd_status()
    elif command == "clean":
        if len(sys.argv) < 3:
            print('사용법: python main.py clean "<프로젝트이름>"')
            sys.exit(1)
        cmd_clean(sys.argv[2])
    elif command == "export":
        if len(sys.argv) < 3:
            print('사용법: python main.py export "<프로젝트이름>" --new-repo "<저장소이름>" [--public]')
            print('        또는: python main.py export "<프로젝트이름>" --repo-url "<빈 저장소 URL>"')
            sys.exit(1)
        project_name = sys.argv[2]
        remote_url = None
        new_repo_name = None
        public = False
        rest = sys.argv[3:]
        i = 0
        while i < len(rest):
            if rest[i] == "--repo-url" and i + 1 < len(rest):
                remote_url = rest[i + 1]
                i += 2
            elif rest[i] == "--new-repo" and i + 1 < len(rest):
                new_repo_name = rest[i + 1]
                i += 2
            elif rest[i] == "--public":
                public = True
                i += 1
            else:
                i += 1
        cmd_export(project_name, remote_url, new_repo_name, public)
    else:
        print(f"알 수 없는 명령: {command}")
        print(__doc__)
        sys.exit(1)


if __name__ == "__main__":
    main()
