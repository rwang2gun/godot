---
description: docs/를 읽고 사용자와 정렬한 뒤 Phase로 쪼개 execute.py로 실행하는 원스톱 명령
allowed-tools: Bash, Read, Write, Edit, TodoWrite, Glob, Grep
---

# /harness — 원스톱 Phase 실행

`docs/`가 채워진 상태에서 작업 전체를 자동으로 진행한다.

## 인자
`$ARGUMENTS`로 task 이름이 주어지면 해당 task로 진행. 비어있으면 docs를 읽고 적절한 task 이름을 사용자에게 제안.

## 실행 흐름

### 1. docs/ 문서를 전부 읽는다 (자동)
순서대로 반드시 읽기:
- `docs/PRD.md` — 뭘 만드는지
- `docs/ARCHITECTURE.md` — 어떻게 만드는지
- `docs/ADR.md` — 왜 이렇게 만드는지
- `docs/UI_GUIDE.md` (있으면)

`docs/references/`는 추가 컨텍스트로만 참조, 강제 아님.

### 2. 사용자와 논의 (같이)
docs를 읽고 task 진행에 필요한 정보가 명확하지 않으면 물어본다:
- task의 정확한 범위 (예: "MVP 전체"인지 "Stage 1만"인지)
- 우선순위 충돌이 있을 때 결정
- 외부 의존성이나 환경 설정 필요 여부

답이 명확하면 추가 질문 없이 다음으로.

### 3. 구현 계획을 Phase로 쪼갠다 (자동)
사용자가 정한 task에 대해 Phase 분해:
- 각 Phase는 단독으로 검증 가능해야 함 (테스트 또는 수동 확인 가능)
- 각 Phase는 1~3시간 작업량 (너무 크지 않게)
- 첫 Phase는 항상 "셋업/스켈레톤" 성격 (의존성 무엇도 없도록)
- Phase 간 의존은 선형 — 순서대로 진행 가능해야 함

분해 결과는 사용자에게 보여주고 확인 받기.

### 4. Phase 파일 생성 (자동)
각 Phase를 다음 형식으로 저장:
```
phases/{task-name}/phaseNN-{slug}.md
phases/{task-name}/status.json
```

각 phase 파일 구조:
```markdown
---
name: {phase 이름}
duration_estimate: {예상 초}
verify: {선택 — 검증 명령}
---

# Phase {N}: {이름}

## 목표
{한 줄}

## 변경 대상
- {파일/씬 목록}

## 검증 방법
{어떻게 동작 확인할지}
```

`status.json`은 `python scripts/execute.py {task-name}` 첫 실행 시 자동 초기화.

### 5. execute.py 실행 (자동)
`python scripts/execute.py {task-name}`로 상태 확인 후 Phase 진행:
- `python scripts/execute.py {task-name} next` — 다음 pending Phase의 내용 출력
- 해당 Phase 작업 수행
- `python scripts/execute.py {task-name} complete {N}` — 완료 표시 + 자동 커밋
- 모든 Phase 완료까지 반복

각 Phase 완료 시 자동 커밋 (메시지: `phase {N}: {phase name}`).
모든 Phase 완료 시 status.json의 누적 시간으로 요약 출력.

## 중단/재개
중간에 멈춰도 status.json에 진행 상태가 보존됨. 다시 `/harness {task-name}`을 실행하면 현재 상태 표시 후 다음 Phase부터 재개.
