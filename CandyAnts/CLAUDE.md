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
- CRITICAL: Phase 완료 직전(수동 검증 통과 후 · `execute.py complete` 직전) 반드시 `/codex:adversarial-review` 실행, 결과는 `phases/<task>/reviews/phaseNN-impl-review.md`에 보존
- CRITICAL: adversarial-review에서 **CRITICAL/HIGH가 1건이라도 나오면 반드시 수정**한다. defer·wontfix 금지. 수정 후 동일 인자로 `/codex:adversarial-review` **재실행**, verdict가 clean(needs-attention 해소)이 될 때까지 수정·재리뷰 루프를 반복. 매 회차의 stdout은 `phaseNN-impl-review.md`에 회차 헤더(`## Round 2`, `## Round 3` …)로 누적
- CRITICAL: 사후(=phase 커밋 후) 리뷰에서 HIGH가 발견되면 즉시 후속 hot-fix 커밋(`fix: <요약> (phase NN sweep)`)으로 처리하고, 동일 루프(재리뷰 → clean)까지 진행. 다음 phase 시작 금지. MEDIUM/LOW만 `phaseNN-deferred.md` 허용
- 작업 진행은 `python scripts/execute.py {task-name}`로 상태 관리
- 헤드리스 테스트는 `python scripts/run_test.py <scene>` (예: `tests/Stage03HeadlessTest.tscn`). Godot 바이너리는 `GODOT_BIN` 환경변수 → `PATH` → 알려진 후보 순으로 자동 탐색. 새 머신/위치 사용 시 `scripts/run_test.py`의 `CANDIDATES` 갱신 또는 `GODOT_BIN` 지정
- 커밋 메시지: `phase {N}: {요약}` 형식 (Phase 단위) 또는 conventional commits (feat:, fix:, refactor:)
- Hook이 차단/경고하면 우회 금지, 의도 확인 후 정공법으로 처리

## Notion Phase DB 동기화

- **Phase DB**: https://www.notion.so/35bb23cf3720804db915f35fa9f04032 (data source `35bb23cf-3720-8023-8ff1-000bc1eb0d52`)
- **page_id 매핑 SoT**: `phases/mvp/notion-phase-ids.json` (phase 번호 → page_id / url / slug)
- **상태 옵션**: `시작 전` / `진행 중` / `완료`

### 동기화 시점 (CRITICAL)

1. **Phase 진입 시** (= `python scripts/execute.py {task} next` 실행 후 plan 작성 또는 구현 시작 직전):
   - `notion-phase-ids.json`에서 phase 번호로 `page_id` 조회
   - Notion MCP `notion-update-page` (`command: update_properties`)로 해당 페이지 `상태` → `진행 중`
2. **Phase 완료 직전** (= adversarial-review verdict가 clean이 되어 `python scripts/execute.py {task} complete N` 호출 **직전**):
   - 동일 `page_id`로 `상태` → `완료`
3. **Hot-fix sweep 커밋** (= 이미 완료된 phase의 사후 리뷰 HIGH 처리 중)도 Notion 상태는 `완료` 유지 (sweep 끝나도 별도 변경 없음). 단, sweep로 새 round가 추가되면 `요약`에 `(sweep N)` 등 짧은 메모 갱신 가능

### 자동화 가이드

- Notion MCP 호출 실패해도 작업 자체는 계속 진행 — Notion은 보조 트래커이고 1차 SoT는 `phases/mvp/status.json` + git
- 실패 시 사용자에게 1줄 보고 + 다음 시점에 보강 시도
- page_id 매핑은 phase가 추가/이름 변경될 때만 `notion-phase-ids.json` 갱신 (현재 22 phase 고정, 변경 빈도 낮음)
