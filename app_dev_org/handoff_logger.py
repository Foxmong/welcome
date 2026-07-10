# -*- coding: utf-8 -*-
"""
에이전트 간 메시지 전달(handoff) 로거.

crewAI의 각 Task가 끝나면 다음 Task(다음 에이전트)에게 결과물이 `context`를
통해 자동으로 전달된다. 이 시점을 `task_callback`으로 가로채서
"누가 무엇을 만들어서 다음 사람에게 넘겼는지"를 사람이 읽기 쉬운 마크다운
파일로 남긴다.

실행이 끝난 뒤 <output_dir>/logs/handoff.md 를 열면, 4명의 에이전트 사이에
메시지가 전달된 전체 과정을 순서대로 확인할 수 있다.
"""

import datetime
from pathlib import Path
from typing import Callable


def _timestamp() -> str:
    return datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def make_handoff_logger(output_dir: str) -> Callable:
    """output_dir/logs/handoff.md 에 기록하는 task_callback 함수를 생성한다."""

    log_dir = Path(output_dir) / "logs"
    log_path = log_dir / "handoff.md"
    step_counter = {"n": 0}

    def log_handoff(task_output) -> None:
        log_dir.mkdir(parents=True, exist_ok=True)
        step_counter["n"] += 1
        step = step_counter["n"]

        agent_name = getattr(task_output, "agent", None) or "(알 수 없음)"
        task_name = getattr(task_output, "name", None) or "(이름 없음)"
        raw = getattr(task_output, "raw", "") or ""
        preview = raw.strip()
        if len(preview) > 800:
            preview = preview[:800] + "\n\n... (이하 생략, 전체 내용은 docs/ 폴더 참고) ..."

        # 미리보기 안에 코드블록(```)이 포함될 수 있으므로, 겹치지 않는
        # 구분자(~~~~)로 감싸서 마크다운이 깨지지 않게 한다.
        entry = (
            f"## {step}단계 완료 — {agent_name}\n\n"
            f"- 시각: {_timestamp()}\n"
            f"- 태스크: {task_name}\n"
            f"- 다음 단계로 전달되는 내용 미리보기:\n\n"
            f"~~~~\n{preview}\n~~~~\n\n"
            f"---\n\n"
        )

        # 최초 기록 시 헤더를 붙인다.
        if not log_path.exists():
            header = (
                "# 에이전트 메시지 전달(handoff) 로그\n\n"
                "이 파일은 PM → 아키텍트 → 개발자 → QA 순서로 작업이 넘어갈 때마다\n"
                "자동으로 기록됩니다. 위에서부터 순서대로 읽으면 전체 협업 과정을\n"
                "그대로 재현해볼 수 있습니다.\n\n---\n\n"
            )
            log_path.write_text(header, encoding="utf-8")

        with log_path.open("a", encoding="utf-8") as f:
            f.write(entry)

        # 콘솔에도 요약을 즉시 출력해, 실행 중에도 진행 상황을 바로 볼 수 있게 한다.
        print(f"\n[핸드오프 {step}] '{agent_name}' 작업 완료 → 다음 단계로 결과 전달됨")
        print(f"           (전체 내용: {log_path})\n")

    return log_handoff
