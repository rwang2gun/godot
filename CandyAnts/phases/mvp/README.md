# MVP Task — Phase 표준 절차

이 task의 모든 phase는 동일한 7단계 절차를 따른다. 이 문서가 단일 SoT.

## 폴더 구조

```
phases/mvp/
├── README.md                        # 이 문서 (절차 명세)
├── status.json                      # execute.py 자동 관리
├── phaseNN-<slug>.md                # phase 정의 (frontmatter + 목표 + 변경 대상 + 검증)
├── plans/
│   └── phaseNN-plan.md              # phase 시작 시 작성 (구현 계획)
└── reviews/
    ├── phaseNN-review.md            # /codex:adversarial-review stdout (Step 2, plan 단계)
    ├── phaseNN-impl-review.md       # /codex:adversarial-review stdout (Step 7, impl 단계)
    └── phaseNN-deferred.md          # 미수정 이슈 기록 (있을 때만)
```

## Phase 표준 절차 (7단계)

### 1. 계획 작성 — `plans/phaseNN-plan.md`
다음 항목을 모두 채운다:
- **목표 1줄** (phase 정의 문서와 일치)
- **변경/추가 파일 목록** (씬, 스크립트, 데이터, 에셋)
- **씬 트리 구조** (노드 타입 + 핵심 export 변수)
- **시그널 흐름** (어떤 시그널이 어디서 발화 → 어디서 수신)
- **엣지 케이스** (구현 중 빠뜨리면 안 되는 시나리오 3개 이상)
- **검증 시나리오** (Godot 에디터에서 어떻게 동작 확인할지)

### 2. adversarial review 실행
plan 파일이 working-tree에 있는 상태에서, **데스크톱 플러그인의 슬래시 커맨드**로 실행:

```text
/codex:adversarial-review --wait "phase NN plan: <한 줄 포커스>"
/codex:adversarial-review --background "phase NN plan: <한 줄 포커스>"   # 변경이 클 때
```

> CLI(`node ... codex-companion.mjs`)로 직접 실행하지 않는다. Bash subprocess 경로는 Windows sandbox 권한 문제로 read-only git/Get-Content 호출이 `CreateProcessAsUserW exit -1`로 막힐 수 있어 (2026-05-10 phase 6 plan review에서 4회 반복 실패) 사용자가 데스크톱 Claude Code의 슬래시 커맨드로 트리거하는 것이 신뢰 가능한 경로.

리뷰는 working-tree 변경(plan 파일 + 그 시점 변경 파일)을 모두 본다.

### 3. 리뷰 결과 보존 — `reviews/phaseNN-review.md`
stdout을 그대로 저장. 헤더로 다음 추가:

```markdown
# Phase NN Adversarial Review

- **실행 시각**: YYYY-MM-DD HH:MM
- **포커스**: <CLI에 넣은 한 줄>
- **scope**: working-tree
- **base ref**: <git rev-parse HEAD 결과>

---

<stdout 그대로>
```

### 4. 이슈 분류 + 처리 (Plan stage)

> **Plan stage 정책 (2026-05-09 갱신)**: codex 리뷰에서 **CRITICAL/HIGH가 1건이라도 나오면 작업 즉시 중단 + 사용자 보고**. 자동 재리뷰 사이클 없음. 사용자가 수정 방향·범위·취소 여부 결정. 근거: plan stage 자동 재리뷰 사이클이 라운드 폭증을 유발 (이전 game-flow plan v1~v5 5라운드), 비효율 + usage limit 소진.

| Severity | Plan stage 처리 정책 |
|----------|----------|
| CRITICAL | **즉시 중단 → 사용자 보고**. 사용자가 수정 방향 결정 |
| HIGH     | **즉시 중단 → 사용자 보고**. 사용자가 수정 방향 결정 |
| MEDIUM   | 수정 권장. 미수정 시 deferred 기록 필수 |
| LOW      | 선택. 미수정 시 deferred 기록 권장 |

미수정 MEDIUM/LOW 이슈는 `reviews/phaseNN-deferred.md`에:

```markdown
# Phase NN Deferred Issues

## [SEVERITY] 이슈 한 줄 요약
- **원본 인용**: <리뷰에서 발췌>
- **결정**: defer | wontfix | future-phase
- **사유**: <왜 안 고치는지>
- **재검토 시점**: Phase X | Stage Y | never
```

> CRITICAL/HIGH를 deferred에 넣는 것은 **금지**. 반드시 수정 또는 사용자 결정 거친 후 진행.

### 5. 구현
갱신된 plan대로 진행. 파일/씬은 ARCHITECTURE의 폴더 구조 + 명명 규약(snake_case 함수, PascalCase 클래스, UPPER_SNAKE const) 준수.

### 6. 수동·자동 검증
- **헤드리스 자동**: `python scripts/run_test.py <scene>` (예: `tests/Stage03HeadlessTest.tscn`, `tests/BlockerOverlapTest.tscn`). 모든 회귀 씬은 PASS 필수.
- **에디터 수동**: Godot 에디터에서 phase 정의의 "검증 방법"대로 플레이 테스트.
- 검증 통과 못 하면 다음 단계로 가지 말고 구현/plan 수정.

### 7. 구현 리뷰 — `/codex:adversarial-review` + 자체 적대적 리뷰 사이클
수동 검증 통과 후, complete 커밋 직전 working-tree 상태에서 실행.
Step 2(plan 리뷰)와 달리 **실제 구현된 코드의 설계 결정·가정·트레이드오프를 challenge**한다.

```bash
/codex:adversarial-review --background "phase NN <slug>: <한 줄 포커스>"
/codex:adversarial-review --wait "<focus>"           # 변경이 1~2 파일로 작을 때만
```

> 이미 커밋된 phase를 사후 리뷰할 때만: `/codex:adversarial-review --base HEAD~1 --scope branch --background "<focus>"`

stdout을 `reviews/phaseNN-impl-review.md`에 저장. 헤더는 Step 3와 동일한 포맷(scope, base ref, head ref 명시).

#### 자체 적대적 리뷰 사이클 (CRITICAL — 2026-05-09 도입)

매 codex 라운드 사이에 **자체 적대적 리뷰**를 끼워넣는다. 목적: codex 라운드 폭증 방지(이전 phase 5 plan은 15+ 라운드 발생) + usage limit 보호 + cross-doc/dead-branch/circular-SoT 같은 구조적 위험을 codex 호출 전에 선제 차단.

**사이클**:
1. codex 1회 실행 → finding이 나오면 plan/구현 수정.
2. **수정 결과물을 본인이 직접 적대적 리뷰**한다. codex와 동일 기준:
   - CRITICAL / HIGH / MEDIUM / LOW 분류
   - hypothetical 위험("implementer가 이걸 보고 잘못할 수 있나") 포함
   - 추가로 codex가 약한 영역 가혹하게 점검: cross-doc 일관성, dead branch, circular SoT, fixture redundancy, 시간적 위험(다음 phase에서 첫 활성될 때 검증 0인 코드)
3. 자체 리뷰 stdout을 동일 review 파일에 `## Self-Review Round N` 헤더로 누적.
4. CRITICAL/HIGH가 1건이라도 있으면 추가 수정 → 자체 재리뷰. **자체 리뷰가 clean(HIGH 0건)이 될 때까지 반복.**
5. 자체 리뷰 clean 확인 후 비로소 codex 재리뷰 실행. codex가 새로 HIGH 발견하면 1번부터 다시.
6. **codex만 연달아 호출 금지** — 매 codex 라운드 사이에 자체 리뷰 사이클 ≥1회 필수.

#### 이슈 분류 정책 (Step 4와 동일하지만 Step 7은 더 엄격)
- **CRITICAL/HIGH**: **defer 금지**. 반드시 수정 → 자체 리뷰 사이클 → codex 재실행. verdict가 clean(needs-attention 해소)이 될 때까지 루프.
  - 매 회차 stdout은 `phaseNN-impl-review.md`에 누적 (`## Round N` = codex, `## Self-Review Round N` = 자체)
  - 사후(=phase 커밋 후) HIGH 발견 시 후속 hot-fix 커밋(`fix: <요약> (phase NN sweep)`)으로 처리
- **MEDIUM/LOW**: 미수정 시 `reviews/phaseNN-deferred.md`에 기록

> CRITICAL/HIGH가 남은 채로 Step 8로 넘어가는 것은 절대 금지.
> 사후 HIGH 발견 시 **다음 phase 시작도 금지** — 먼저 sweep 마무리.

#### Plan-stage(Step 2) 리뷰는 다른 정책 (2026-05-09 갱신)

Step 2(plan 리뷰)는 **자동 재리뷰 사이클을 돌리지 않는다**. codex 1회 실행 후:

- CRITICAL/HIGH 0건 → 그대로 Step 5(구현)로 진행
- CRITICAL/HIGH 1건 이상 → **즉시 작업 중단 + 사용자에게 보고**. 사용자가 수정 방향·범위·취소 여부 결정. 수정 후 사용자가 재리뷰 지시 시에만 codex 재실행

근거:
- plan stage 자동 재리뷰는 라운드 폭증을 유발 (이전 game-flow plan은 v1~v5 5라운드)
- plan은 코드와 달리 사용자 의도·우선순위와 직접 연결되어 자동 결정이 위험
- usage limit + 시간 비용

plan-stage review stdout은 `reviews/phaseNN-review.md`에 1회 라운드만 보존. 사용자 결정으로 재리뷰 시 `## Round 2` 추가.

> 자체 적대적 리뷰 사이클은 **impl stage(Step 7)에만 적용**. plan stage는 codex 1회만.

### 8. 완료 처리
```bash
python scripts/execute.py mvp complete N
```
자동 커밋 메시지: `phase N: <phase name>`. plans/reviews/codex-review/deferred 모두 함께 커밋된다.

## 중단/재개

`status.json`에 진행 상태가 보존됨. 재개 시:
```bash
python scripts/execute.py mvp        # 상태 확인
python scripts/execute.py mvp next   # 다음 pending phase 정의 출력
```

## Phase 목록 (요약)

> 2026-05-09 개정 v2: phase 5~12에 input(3) + UI(5)를 신설(atoms를 별도 phase로 분리). 기존 stage4~10 phase를 13~19로 시프트.
> 2026-05-09 개정 v3 (game-flow): phase 6에 `game-flow-foundation` 신규 삽입. 기존 6~19 → 7~20, post-MVP 20~22 → 21~23. 상세 근거: `docs/GAME_FLOW_PROPOSAL_V5.md`.
> 2026-05-18 개정 v4 (option-B v0.2 + §5.2 17 분할): phase 14~20을 stage 기반 → 메카닉 기반 7-phase로 재구성.
> 상세 근거: `docs/PHASE_14_OPTION_B_PROPOSAL.md` + `docs/PHASE_14_OPTION_B_MIGRATION_PLAN.md` + `phases/mvp/REVISION_2026-05-18-option-b.md`.
> 상세 근거: `docs/INPUT_PLAN.md`, `docs/UI_GUIDE.md`, `docs/GAME_FLOW_PROPOSAL_V5.md`, `docs/design_handoff/` (프로젝트 안 흡수됨), `docs/PHASE_14_OPTION_B_PROPOSAL.md`.

| # | 트랙 | 이름 | 핵심 산출물 |
|---|------|------|-------------|
| 1 | core | bootstrap | project.godot, 폴더 구조, Autoload 빈 셸 |
| 2 | core | stage1-core | Vertical Slice — Ant 6상태, Candy/Home, ScoreSystem, HUD |
| 3 | core | stage2-builder | SkillRegistry 활성화, SkillToolbar, WorkerState, Builder |
| 4 | core | stage3-blocker | Blocker 스킬 |
| 5 | input | input-action-foundation | InputRouter + InputMap + KB/Mouse 마이그레이션 |
| 6 | core | game-flow-foundation | Main/SceneFlow + EventBus request_* + StageResultOverlayStub + Dictionary payload + no_more_ants |
| 7 | input | input-pad-cursor | VirtualCursor + Pad 매핑 + 개미 스냅 |
| 8 | input | input-pause-step | pause 중 부여 + StepFrame + InputModeTracker |
| 9 | ui | ui-theme-assets | Theme 리소스 + 폰트 + SVG 에셋 임포트 + Tokens.gd |
| 10 | ui | ui-atoms-foundation | CButton/Chip/Counter/SkillSlot atoms + Motion 헬퍼 |
| 11 | ui | ui-hud-toolbar-replace | HUD/SkillToolbar 씬 교체 (atom 인스턴스화) |
| 12 | ui | ui-stage-dialog | StageDialog (win/loss) + 트랜지션 + 사운드 hook |
| 13 | ui | ui-title-menu | 타이틀 / 메인 메뉴 / 스테이지 셀렉트 + SaveData |
| 14 | mechanic (14a) | mechanic-adaptation-traits | Climber + Floater(민들레씨 보유 트레잇) |
| 15 | mechanic (14b) | mechanic-adaptation-settlement | Blocker + 민들레씨 분배자 + 정착 + 능력 전이 |
| 16 | mechanic | mechanic-creation | Sand-mound(수직) + Bridge(수평) 생성 메카닉 |
| 17 | mechanic | mechanic-hazard | Water + 끈끈이 + 사탕 손실 페일 룰 |
| 18 | mechanic (17a) | mechanic-destruction-earth | Basher + Digger (흙 지형 동적 파괴) |
| 19 | mechanic (17b) | mechanic-destruction-plant | Cutter + 식물 지형 신규 클래스 |
| 20 | polish | polish | Release Rate + 별 시스템 + 정산 UI + 사운드 hook + 피날레 (MVP 종료) |
| 21 | post-MVP | sound-bgm-sfx | 사운드 임포트 + 모달/카운터/스킬 SFX |
| 22 | post-MVP | input-touch | 터치 + 드래그앤드롭 + 루페 |
| 23 | post-MVP | input-advanced | Rewind + Preview + CommandWheel + Overlay |
