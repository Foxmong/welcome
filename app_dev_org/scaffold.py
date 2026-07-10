# -*- coding: utf-8 -*-
"""
B 모드(에이전트 단독 조직 모드)용 산출물 골격 생성기.

crewAI 없이 에이전트(Codex/Cursor 등)가 직접 4역할을 수행할 때,
절차를 빠뜨리지 않도록 산출물 템플릿과 체크리스트를 미리 만들어준다.
LLM API 키가 전혀 필요 없다.
"""

import datetime
from pathlib import Path

TEMPLATES = {
    "PROJECT_BRIEF.md": """\
# 프로젝트 개요

- 프로젝트 이름: {project_name}
- 생성 시각: {timestamp}
- 운영 모드: B (에이전트 단독 조직 모드)

## 사용자 요구사항 (원문)

{requirements}

## 진행 절차 (에이전트는 이 순서를 반드시 따를 것)

- [ ] 1단계 (PM): 요구사항 분석 → `docs/01_기능명세서.md` 작성
- [ ] 2단계 (아키텍트): 기술 설계 → `docs/02_기술설계서.md` 작성
- [ ] 3단계 (개발자): 코드 구현 → 실제 코드 파일 + `docs/03_구현노트.md` 작성
- [ ] 4단계 (QA): 검토 → `docs/04_리뷰보고서.md` 작성
- [ ] 각 단계 완료 시 `logs/handoff.md`에 기록
- [ ] 완료 후 `python <조직브랜치>/app_dev_org/main.py finish "{project_name}"` 또는 git commit
""",
    "docs/01_기능명세서.md": """\
# 기능 명세서 — 1단계 (PM)

> 작성 역할: 프로덕트 매니저(PM)
> 근거 자료: `PROJECT_BRIEF.md`의 사용자 요구사항
> 완료 후: `logs/handoff.md`에 1단계 기록을 추가하고 2단계(아키텍트)로 진행

## 핵심 기능 목록 (우선순위 포함)

(여기에 작성: 필수/선택 구분)

## 사용자 시나리오

(여기에 작성)

## 범위 제외 사항

(여기에 작성: 이번 버전에서 하지 않는 것)
""",
    "docs/02_기술설계서.md": """\
# 기술 설계서 — 2단계 (아키텍트)

> 작성 역할: 소프트웨어 아키텍트
> 근거 자료: `docs/01_기능명세서.md` (반드시 먼저 읽을 것)
> 원칙: 요구사항 규모에 맞는 가장 단순한 구조를 선택
> 완료 후: `logs/handoff.md`에 2단계 기록을 추가하고 3단계(개발자)로 진행

## 기술 스택과 선정 이유

(여기에 작성)

## 모듈 / 파일 구조

(여기에 작성)

## 데이터 흐름

(여기에 작성)
""",
    "docs/03_구현노트.md": """\
# 구현 노트 — 3단계 (개발자)

> 작성 역할: 시니어 개발자
> 근거 자료: `docs/01_기능명세서.md`, `docs/02_기술설계서.md`
> 코드는 이 문서가 아니라 **실제 코드 파일**로 이 폴더 안에 작성할 것
> 완료 후: `logs/handoff.md`에 3단계 기록을 추가하고 4단계(QA)로 진행

## 생성한 파일 목록

(여기에 작성: 파일 경로와 한 줄 설명)

## 실행 방법

(여기에 작성: 설치/실행 명령)

## 설계와 달라진 부분과 이유

(없으면 "없음")
""",
    "docs/04_리뷰보고서.md": """\
# 리뷰 보고서 — 4단계 (QA)

> 작성 역할: QA 리뷰어
> 근거 자료: `docs/01_기능명세서.md`, `docs/02_기술설계서.md`, 실제 코드
> 완료 후: `logs/handoff.md`에 4단계 기록을 추가하고 커밋으로 마무리

## 명세 대비 구현 확인

| 기능 | 구현 여부 | 비고 |
|------|-----------|------|
| (기능명) | 완료/누락/부분 | |

## 발견한 이슈 (심각도: 높음/중간/낮음)

(여기에 작성)

## 개선 제안

(여기에 작성)
""",
    "logs/handoff.md": """\
# 에이전트 메시지 전달(handoff) 로그

이 파일은 PM → 아키텍트 → 개발자 → QA 순서로 작업이 넘어갈 때마다
기록됩니다. B 모드에서는 각 단계를 마친 에이전트가 직접 아래 형식으로
추가하세요. 위에서부터 순서대로 읽으면 전체 협업 과정을 재현할 수 있습니다.

기록 형식:

    ## N단계 완료 — <역할 이름>
    - 시각: YYYY-MM-DD HH:MM
    - 다음 단계로 전달하는 핵심 내용: <요약>

---

""",
}


def scaffold_project(worktree_path: str | Path, project_name: str, requirements: str) -> list[str]:
    """격리된 프로젝트 폴더 안에 B 모드 산출물 골격을 만든다.

    Returns: 생성된 파일 경로 목록 (worktree 기준 상대경로)
    """
    root = Path(worktree_path)
    created = []
    context = {
        "project_name": project_name,
        "requirements": requirements.strip(),
        "timestamp": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
    }
    for rel_path, template in TEMPLATES.items():
        dest = root / rel_path
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(template.format(**context), encoding="utf-8")
        created.append(rel_path)
    return created
