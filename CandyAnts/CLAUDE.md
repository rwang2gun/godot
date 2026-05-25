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
- CRITICAL: gameplay phase와 직교한 장기 codex 협업(맵 에디터·에셋 폴리싱 등 툴링/리소스 파이프라인)은 `codex-worklog/<track>/`에 기록한다. 트리거: codex가 산출물을 돌려준 직후·해당 산출물을 커밋·반영하기 전. 흐름: 트랙별 `STATUS.md`(현재 상태·다음 작업·블로커 SoT) + 세션 단위 `YYYY-MM-DD-<topic>.md` 누적. 컨벤션 세부는 `codex-worklog/README.md` 참조. `phases/mvp/`·`worklog/`와 중복 기록 금지.
- CRITICAL: Phase 완료 직전(수동 검증 통과 후 · `execute.py complete` 직전) 반드시 `/codex:adversarial-review` 실행, 결과는 `phases/<task>/reviews/phaseNN-impl-review.md`에 보존
- CRITICAL: adversarial-review의 stage별 정책이 다르다 (2026-05-25 정책 갱신, 2026-05-09 기준 완화).
  - **Plan stage (Step 2~3, plan 리뷰)**: codex 리뷰에서 CRITICAL/HIGH 발견 시 **최대 2회까지 fix+재리뷰 허용**한다. 라운드 카운팅:
    - **Round 1** = 초기 codex 리뷰. HIGH 발견 시 plan 수정 → Round 2 codex 재리뷰.
    - **Round 2** = 1차 수정 후 재리뷰. HIGH 발견 시 plan 수정 → Round 3 codex 재리뷰.
    - **Round 3** = 2차 수정 후 재리뷰. **HIGH 1건이라도 나오면 즉시 중단**하고 사용자에게 보고. 사용자가 수정 방향·범위·취소 여부를 결정한다.
    - MEDIUM/LOW만 남으면 어느 라운드에서든 plan 내 처리 또는 명시 defer로 종결.
    - 자체 적대적 리뷰 사이클은 plan stage에는 적용하지 않는다 (impl stage 한정).
    - 매 라운드 stdout은 `phases/<task>/reviews/phaseNN-plan-review.md`에 `## Round N` 헤더로 누적.
    - 근거: 단일-shot 중단(2026-05-09 정책)은 사소한 HIGH 1건에 작업이 멈춰 효율이 낮고, 무제한 재리뷰(이전 game-flow plan v1~v5)는 라운드 폭증 + usage limit 소진. **2회 수정 + 1회 최종 검증 = 3 라운드 cap**으로 절충.
  - **Impl stage (Step 7, 구현 리뷰)**: 기존 정책 유지. **CRITICAL/HIGH가 1건이라도 나오면 반드시 수정**한다. defer·wontfix 금지. 수정 후 동일 인자로 `/codex:adversarial-review` **재실행**, verdict가 clean(needs-attention 해소)이 될 때까지 수정·재리뷰 루프를 반복. 매 회차의 stdout은 `phaseNN-impl-review.md`에 회차 헤더(`## Round 2`, `## Round 3` …)로 누적
- CRITICAL: **Impl stage codex 재리뷰 전 자체 적대적 리뷰 사이클** (impl stage에만 적용, 2026-05-09 정책 갱신). 최초 `/codex:adversarial-review` 1회 실행 후 finding이 나오면:
  1. 구현을 수정한다.
  2. **수정 결과물을 본인이 직접 적대적 리뷰**한다 — codex와 동일 기준(CRITICAL/HIGH/MEDIUM/LOW + hypothetical 위험 + cross-doc 일관성 + dead branch + circular SoT 등 구조적 위험까지 가혹하게).
  3. 자체 리뷰에서 CRITICAL/HIGH가 1건이라도 나오면 추가 수정 → 재자체리뷰. **자체 리뷰가 clean(HIGH 0건)이 될 때까지 반복.** 매 자체리뷰 stdout은 `phaseNN-impl-review.md`에 `## Self-Review Round N` 헤더로 누적.
  4. 자체 리뷰 clean 확인 후 비로소 codex 재리뷰 실행. codex가 새로 HIGH 발견하면 1번부터 다시.
  5. 매 codex 라운드 사이에 자체 리뷰 사이클 1회 이상 끼움. codex만 연달아 호출 금지(usage limit + 라운드 폭증 방지).
  6. **Plan stage에는 적용하지 않는다** — plan stage는 위 3-round cap 정책(Round 3 HIGH 시 STOP)만 따른다.
- CRITICAL: 사후(=phase 커밋 후) 리뷰에서 HIGH가 발견되면 즉시 후속 hot-fix 커밋(`fix: <요약> (phase NN sweep)`)으로 처리하고, 동일 impl-stage 루프(자체리뷰 → codex 재리뷰 → clean)까지 진행. 다음 phase 시작 금지. MEDIUM/LOW만 `phaseNN-deferred.md` 허용
- 작업 진행은 `python scripts/execute.py {task-name}`로 상태 관리. 세션 시작마다 한 번 `validate` 실행, phase 추가/삭제 시 `sync-status`로 동기화. Phase 메타(`active_revision`, post-MVP 범위 등)는 `phases/{task-name}/metadata.json`이 SoT — `CLAUDE.md`에 phase 개수를 하드코딩하지 않는다
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
- page_id 매핑은 phase가 추가/이름 변경될 때만 `notion-phase-ids.json` 갱신 (변경 빈도 낮음). 현재 phase 개수는 `phases/mvp/status.json` / `metadata.json`이 SoT — 여기엔 하드코딩하지 않는다
