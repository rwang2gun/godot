# Battle Prototype — Godot 4.6 Project

## Overview
FreeFlow HTML 프로토타입을 Godot 4.6(GDScript)으로 이관하는 프로젝트.
이관 계획서: `GODOT_Battle_Prototype.md`

## Tech Stack
- Engine: Godot 4.6 (Forward Plus)
- Language: GDScript
- Coordinate: Y-up, -Z forward (Three.js 원본은 +Z forward → 좌표 변환 필요, 상세는 계획서 참조)

## Project Structure
```
project.godot
scenes/          # .tscn 씬 파일
scripts/         # .gd 스크립트
  core/          # StateMachine, PoseSystem 등 코어
  characters/    # CharacterBase, EF, WM
  states/        # State 서브클래스 10종
  enemies/       # Goblin, GoblinSpearman
  camera/        # CameraRig
data/            # poses.gd (POSES 딕셔너리)
ui/              # HUD 관련
```

## Coding Conventions
- GDScript 4 스타일: snake_case (함수/변수), PascalCase (클래스/노드)
- 타입 힌트 사용: `var speed: float = 6.0`, `func foo(x: int) -> void:`
- const는 UPPER_SNAKE_CASE: `const MAX_SPEED := 6.0`
- 시그널: past tense (`health_changed`, `enemy_died`)
- 들여쓰기: 탭 (Godot 기본)
- .gd.uid 파일은 Godot이 자동 생성 — 삭제하지 말 것

## Key Design Decisions
- Skeleton3D 사용하지 않음 — Node3D 계층 + rotation 직접 조작 (PoseSystem)
- Engine.time_scale 대신 delta 직접 조작 (캐릭터/적 독립 시간)
- 한 번에 1마리만 공격하는 AI Coordinator 패턴

## Git Rules
- `.godot/` 폴더 절대 커밋하지 않을 것
- `.claude/` 폴더 절대 커밋하지 않을 것
- 커밋 메시지: 한국어 OK, 간결하게

## Workflow

### 작업 시작 전
1. `GODOT_Battle_Prototype.md`의 Phase 체크리스트에서 다음 작업 확인
2. 관련 섹션(좌표계/포즈/스테이트 등)의 GDScript 예시 코드 숙지
3. 비슷한 작업이 이미 있으면 기존 코드 먼저 읽고 패턴 재사용

### 작업 진행 중
- 여러 단계로 나뉘는 작업은 TodoWrite로 트래킹
- 한 번에 하나의 Phase 항목만 진행 — 완료되면 다음으로
- 새 스크립트는 반드시 계획서의 폴더 구조(`scripts/core/`, `scripts/states/` 등)를 따를 것
  - Hook이 scripts/ 밖에 .gd 파일 생성을 막아줌

### Codex 검증
- 복잡한 로직(전투 시스템, 좌표 변환, State 이식, AI 등)은 Codex 검증 권장
- 작업 시작 전 "이 작업은 Codex 검증을 추천합니다"라고 알리고, 승인 후 진행
- 단순 구조 작업(폴더 정리, 빈 파일 생성 등)은 Codex 불필요
- 검증 시 반드시 `CODEX_CHECKLIST.md`의 항목을 프롬프트에 포함할 것

### 작업 완료 후
1. Godot 에디터에서 실행 테스트(내가 수동)
2. 문제 없으면 `GODOT_Battle_Prototype.md`의 해당 체크박스를 `[x]`로 업데이트
3. 커밋은 명시적 요청이 있을 때만. 메시지는 "Phase X: <작업명>" 형식

### Hook이 차단/경고한 경우
- `.gd 파일이 scripts/ 밖`: 경로가 정말 의도적인지 확인 후 계속
- `git commit이 .godot/ 또는 .claude/ 포함`: 반드시 `git reset HEAD <file>`로 제거 후 재시도
