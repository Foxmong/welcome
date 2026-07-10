# -*- coding: utf-8 -*-
"""
앱 개발 조직 실행 진입점 (CLI).

사용법:
  # 새 프로젝트 명령 (격리 브랜치 자동 생성 → 조직 실행 → 결과 커밋)
  python main.py new "todo-app" "간단한 할 일 관리 웹앱을 만들어줘. 추가/완료/삭제 기능 필요."

  # 진행 중인 프로젝트 브랜치 목록 확인
  python main.py list

  # 프로젝트 작업 폴더 정리 (브랜치는 보존)
  python main.py clean "todo-app"

동작 순서 (new 명령):
  1. BranchManager 가 조직 브랜치에서 project/<이름> 브랜치를 분기하고,
     별도 폴더(worktree)에 체크아웃한다. → 조직 브랜치 완전 격리
  2. crewAI 조직(PM→아키텍트→개발자→QA)이 순차적으로 일하며
     산출물을 그 격리 폴더 안에만 저장한다.
  3. 산출물을 프로젝트 브랜치에 커밋한다. 조직 브랜치는 변경 0건.
"""

import sys
from pathlib import Path

from dotenv import load_dotenv

from branch_manager import BranchManager
from crew import build_app_dev_crew

REPO_ROOT = Path(__file__).resolve().parent.parent


def cmd_new(project_name: str, requirements: str) -> None:
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


def cmd_list() -> None:
    manager = BranchManager(str(REPO_ROOT))
    projects = manager.list_projects()
    if not projects:
        print("진행 중인 프로젝트 브랜치가 없습니다.")
    else:
        print("프로젝트 브랜치 목록:")
        for p in projects:
            print(f"  - {p}")


def cmd_clean(project_name: str) -> None:
    manager = BranchManager(str(REPO_ROOT))
    manager.remove_project_workspace(project_name)
    print(f"'{project_name}' 작업 폴더를 정리했습니다. (브랜치는 보존됨)")


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
        cmd_new(sys.argv[2], sys.argv[3])
    elif command == "list":
        cmd_list()
    elif command == "clean":
        if len(sys.argv) < 3:
            print('사용법: python main.py clean "<프로젝트이름>"')
            sys.exit(1)
        cmd_clean(sys.argv[2])
    else:
        print(f"알 수 없는 명령: {command}")
        print(__doc__)
        sys.exit(1)


if __name__ == "__main__":
    main()
