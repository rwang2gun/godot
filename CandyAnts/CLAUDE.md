# 프로젝트: CandyAnts

## 기술 스택
- Godot 4.6, GDScript, **2D side-view**
- TileMap 기반 지형, CharacterBody2D 기반 개미, Area2D 트리거
- 좌표계: +X 오른쪽, **+Y 아래** (BattlePrototype의 3D Y-up과 다름)

## 아키텍처 규칙
- CRITICAL: 신규 스크립트는 반드시 `scripts/{core,ant,skills,world,ui}/` 하위에 작성
- CRITICAL: Area2D 트리거(Candy/Home/Hazard)의 `collision_mask`는 Ant Layer 3을 포함해야 함 — Ant의 mask가 아니라 Area2D 본인의 mask
- CRITICAL: ScoreSystem은 `original_hp / saved / in_transit / lost` **4-카운터 필수**, 단일 카운터 금지
- CRITICAL: 새 스킬 추가 시 `SkillRegistry.SKILL_SCRIPTS`에 preload 1줄 추가 (`_static_init` 자기등록 사용 금지)
- 자세한 설계: `docs/PRD.md`, `docs/ARCHITECTURE.md`, `docs/ADR.md`

## 개발 프로세스
- CRITICAL: Phase 시작 전 `docs/` 3개 문서(PRD/ARCHITECTURE/ADR) 모두 읽기
- CRITICAL: Stage N 빌드 시작 전 이전 Stage가 회귀 없이 동작하는지 확인
- CRITICAL: 한 Phase 완료 후에만 커밋, Phase 중간 커밋 금지
- 작업 진행은 `python scripts/execute.py {task-name}`로 상태 관리
- 커밋 메시지: `phase {N}: {요약}` 형식 (Phase 단위) 또는 conventional commits (feat:, fix:, refactor:)
- Hook이 차단/경고하면 우회 금지, 의도 확인 후 정공법으로 처리
