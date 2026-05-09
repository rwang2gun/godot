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
plan 파일이 working-tree에 있는 상태에서:

```bash
node "C:\Users\code1412\.claude\plugins\cache\openai-codex\codex\1.0.3\scripts\codex-companion.mjs" adversarial-review --wait "phase NN plan: <한 줄 포커스>"
```

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

### 4. 이슈 분류 + 처리

| Severity | 처리 정책 |
|----------|----------|
| CRITICAL | **반드시 수정**. plan 갱신 후 진행 |
| HIGH     | **반드시 수정**. plan 갱신 후 진행 |
| MEDIUM   | 수정 권장. 미수정 시 deferred 기록 필수 |
| LOW      | 선택. 미수정 시 deferred 기록 권장 |

미수정 이슈는 `reviews/phaseNN-deferred.md`에:

```markdown
# Phase NN Deferred Issues

## [SEVERITY] 이슈 한 줄 요약
- **원본 인용**: <리뷰에서 발췌>
- **결정**: defer | wontfix | future-phase
- **사유**: <왜 안 고치는지>
- **재검토 시점**: Phase X | Stage Y | never
```

> CRITICAL/HIGH를 deferred에 넣는 것은 **금지**. 반드시 수정 후 진행.

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

#### Plan-stage(Step 2) 리뷰에도 동일 사이클 적용
Step 2(plan 리뷰)도 위 사이클과 동일. plan-stage review는 `reviews/phaseNN-review.md`에 누적, codex 라운드와 자체 리뷰 라운드를 모두 보존.

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
> 상세 근거: `docs/INPUT_PLAN.md`, `docs/UI_GUIDE.md`, `docs/design_handoff/` (프로젝트 안 흡수됨).

| # | 트랙 | 이름 | 핵심 산출물 |
|---|------|------|-------------|
| 1 | core | bootstrap | project.godot, 폴더 구조, Autoload 빈 셸 |
| 2 | core | stage1-core | Vertical Slice — Ant 6상태, Candy/Home, ScoreSystem, HUD |
| 3 | core | stage2-builder | SkillRegistry 활성화, SkillToolbar, WorkerState, Builder |
| 4 | core | stage3-blocker | Blocker 스킬 |
| 5 | input | input-action-foundation | InputRouter + InputMap + KB/Mouse 마이그레이션 |
| 6 | input | input-pad-cursor | VirtualCursor + Pad 매핑 + 개미 스냅 |
| 7 | input | input-pause-step | pause 중 부여 + StepFrame + InputModeTracker |
| 8 | ui | ui-theme-assets | Theme 리소스 + 폰트 + SVG 에셋 임포트 + Tokens.gd |
| 9 | ui | ui-atoms-foundation | CButton/Chip/Counter/SkillSlot atoms + Motion 헬퍼 |
| 10 | ui | ui-hud-toolbar-replace | HUD/SkillToolbar 씬 교체 (atom 인스턴스화) |
| 11 | ui | ui-stage-dialog | StageDialog (win/loss) + 트랜지션 + 사운드 hook |
| 12 | ui | ui-title-menu | 타이틀 / 메인 메뉴 / 스테이지 셀렉트 + SaveData |
| 13 | stage | stage4-hazard-water | Hazard 시스템 + Water |
| 14 | stage | stage5-basher | TileMap 동적 파괴 + Basher |
| 15 | stage | stage6-digger | Digger (수직 굴착) |
| 16 | stage | stage7-miner | Miner (대각선 굴착) |
| 17 | stage | stage8-climber | 벽 감지 + Climber |
| 18 | stage | stage9-floater | 낙하 변형 + Floater |
| 19 | stage | stage10-bomber-polish | 원형 파괴 + Bomber + Release Rate 폴리싱 (MVP 종료) |
