# -*- coding: utf-8 -*-
"""
crewAI 기반 "앱 개발 조직" 정의.

조직 구성 (4명의 AI 에이전트):
  1. PM(기획자)      - 요구사항을 분석하고 기능 명세를 작성
  2. 아키텍트        - 기술 스택과 파일 구조를 설계
  3. 개발자          - 설계에 따라 실제 코드를 작성
  4. QA 리뷰어       - 코드를 검토하고 개선점을 정리

작업 흐름 (순차 프로세스):
  요구사항 → [PM] 기획서 → [아키텍트] 설계서 → [개발자] 코드 → [QA] 리뷰 보고서

각 단계의 산출물은 다음 단계 에이전트에게 자동으로 전달(context)되며,
최종 산출물은 격리된 프로젝트 브랜치(worktree) 안에만 저장됩니다.

메시지 전달(handoff) 추적:
  각 에이전트가 작업을 마칠 때마다 crewAI의 task_callback이 호출된다.
  이 시점에 "누가(agent) 무엇을(task) 만들어서 다음 사람에게 넘겼는지"를
  handoff_logger.py 가 <output_dir>/logs/handoff.md 파일에 사람이 읽기 쉬운
  형태로 기록한다. 실행이 끝난 뒤 이 파일을 열면 PM→아키텍트→개발자→QA로
  메시지가 전달되는 전체 과정을 순서대로 확인할 수 있다.
"""

from crewai import Agent, Crew, Process, Task

from handoff_logger import make_handoff_logger


def build_app_dev_crew(project_name: str, requirements: str, output_dir: str) -> Crew:
    """프로젝트 요구사항을 받아 앱 개발 크루(조직)를 구성해 반환한다.

    Args:
        project_name: 프로젝트 이름 (예: "todo-app")
        requirements: 사용자가 내린 프로젝트 명령/요구사항 (자연어)
        output_dir: 산출물이 저장될 디렉터리 (격리된 worktree 경로)
    """

    # ------------------------------------------------------------------
    # 1. 에이전트(조직 구성원) 정의
    # ------------------------------------------------------------------
    product_manager = Agent(
        role="프로덕트 매니저 (PM)",
        goal=(
            "사용자의 요구사항을 분석하여 명확하고 실행 가능한 "
            "기능 명세서를 작성한다."
        ),
        backstory=(
            "10년 경력의 소프트웨어 기획자. 모호한 요구사항에서 핵심 기능을 "
            "뽑아내고, 우선순위를 정하고, 개발팀이 바로 착수할 수 있는 "
            "명세서를 쓰는 데 능하다. 항상 한국어로 문서를 작성한다."
        ),
        verbose=True,
        allow_delegation=False,
    )

    architect = Agent(
        role="소프트웨어 아키텍트",
        goal=(
            "기능 명세를 바탕으로 기술 스택, 모듈 구조, 파일 구성을 "
            "설계한다. 과한 설계 없이 요구사항에 맞는 가장 단순한 구조를 택한다."
        ),
        backstory=(
            "스타트업과 대기업을 오가며 수십 개의 앱 아키텍처를 설계한 "
            "베테랑. '단순함이 최고의 설계'라는 철학을 가지고 있다. "
            "항상 한국어로 문서를 작성한다."
        ),
        verbose=True,
        allow_delegation=False,
    )

    developer = Agent(
        role="시니어 개발자",
        goal=(
            "설계 문서에 따라 동작하는 코드를 작성한다. "
            "실행 가능하고 읽기 쉬운 코드를 최우선으로 한다."
        ),
        backstory=(
            "풀스택 시니어 개발자. 설계 의도를 정확히 코드로 옮기며, "
            "주석과 문서화를 소홀히 하지 않는다. 코드 주석은 한국어로 단다."
        ),
        verbose=True,
        allow_delegation=False,
    )

    qa_reviewer = Agent(
        role="QA 리뷰어",
        goal=(
            "작성된 코드를 검토하여 버그, 누락된 요구사항, 개선점을 "
            "정리한 리뷰 보고서를 작성한다."
        ),
        backstory=(
            "꼼꼼하기로 소문난 QA 엔지니어. 요구사항 대비 구현 누락, "
            "엣지 케이스, 코드 품질 문제를 찾아내는 데 탁월하다. "
            "항상 한국어로 보고서를 작성한다."
        ),
        verbose=True,
        allow_delegation=False,
    )

    # ------------------------------------------------------------------
    # 2. 태스크(업무) 정의 — 산출물은 모두 output_dir(격리 브랜치) 안에 저장
    # ------------------------------------------------------------------
    plan_task = Task(
        description=(
            f"프로젝트 이름: {project_name}\n"
            f"사용자 요구사항:\n{requirements}\n\n"
            "위 요구사항을 분석하여 기능 명세서를 작성하라. "
            "핵심 기능 목록, 우선순위(필수/선택), 사용자 시나리오를 포함할 것."
        ),
        expected_output="마크다운 형식의 기능 명세서 (한국어)",
        agent=product_manager,
        output_file=f"{output_dir}/docs/01_기능명세서.md",
    )

    design_task = Task(
        description=(
            "PM이 작성한 기능 명세서를 바탕으로 기술 설계서를 작성하라. "
            "기술 스택 선정 이유, 모듈/파일 구조, 데이터 흐름을 포함할 것. "
            "요구사항 규모에 맞는 가장 단순한 구조를 택할 것."
        ),
        expected_output="마크다운 형식의 기술 설계서 (한국어)",
        agent=architect,
        context=[plan_task],
        output_file=f"{output_dir}/docs/02_기술설계서.md",
    )

    develop_task = Task(
        description=(
            "설계서에 따라 실제 코드를 작성하라. "
            "하나의 응답 안에 프로젝트의 핵심 파일들을 모두 포함하되, "
            "각 파일은 '### 파일: <경로>' 제목 아래 코드 블록으로 작성할 것. "
            "실행 방법도 마지막에 안내할 것."
        ),
        expected_output=(
            "파일별 코드 블록과 실행 방법이 포함된 마크다운 문서"
        ),
        agent=developer,
        context=[plan_task, design_task],
        output_file=f"{output_dir}/docs/03_구현코드.md",
    )

    review_task = Task(
        description=(
            "개발자가 작성한 코드를 기능 명세서·기술 설계서와 대조하여 리뷰하라. "
            "구현 누락, 설계와 다르게 구현된 부분, 잠재 버그, 개선 제안을 "
            "심각도(높음/중간/낮음)와 함께 정리할 것."
        ),
        expected_output="마크다운 형식의 코드 리뷰 보고서 (한국어)",
        agent=qa_reviewer,
        context=[plan_task, design_task, develop_task],
        output_file=f"{output_dir}/docs/04_리뷰보고서.md",
    )

    # ------------------------------------------------------------------
    # 3. 크루(조직) 구성 — 순차 프로세스: PM → 아키텍트 → 개발자 → QA
    # ------------------------------------------------------------------
    return Crew(
        agents=[product_manager, architect, developer, qa_reviewer],
        tasks=[plan_task, design_task, develop_task, review_task],
        process=Process.sequential,
        verbose=True,
        # 태스크가 끝날 때마다(=다음 에이전트에게 메시지가 넘어갈 때마다) 호출되어
        # 누가 무엇을 만들어 넘겼는지 output_dir/logs/handoff.md 에 기록한다.
        task_callback=make_handoff_logger(output_dir),
    )
