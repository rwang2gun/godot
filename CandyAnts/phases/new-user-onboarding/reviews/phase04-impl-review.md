# Phase 4 — intro-card-infra · impl review

## 변경 요약
- **`scripts/core/StageRunner.gd`**: `@export auto_begin=true` 추가 + `_spawner.start()`를 `begin()`으로 분리(STAGE_GUIDE_PLAN §2.3 방식2). `_ready`는 노드 해석·ScoreSystem·candy hp·HUD·spawner config·spawn_finished connect·set_release_rate·`_time_left` 설정까지 하되 spawn은 시작하지 않는다. `auto_begin`이면 `_ready` 끝에서 즉시 `begin()`. `begin()`은 멱등(`_begun` 가드 = 정확히 1회 start). `_process`는 `not _begun` 시 early-return(타이머/종료 판정 정지). inspector `is_begun()`.
  - **CRITICAL ORDERING 보존**: spawn_finished connect는 `_ready`에, start는 `begin()`에 — connect ⊂ start 이전 관계 유지(degraded 동기 emit 가드 무손상).
- **`scripts/ui/StageIntroCard.gd` + `scenes/ui/StageIntroCard.tscn`** (신규): StageDialog 패턴 복제. `PROCESS_MODE_ALWAYS` + `_dismiss_token` generation guard + Motion.fade_in/caPop + CButton 시작/건너뛰기 + Esc(`_unhandled_input`). API: `show_intro(stage_data)`/`hide_intro()`/`is_showing()`/`shown_skill_ids()` + `intro_dismissed` 시그널. 내용은 placeholder(Phase 5 데이터 바인딩). `hide_intro`는 `is_node_ready()` 가드(부트 시 SceneFlow._reset이 _ready 전 호출 가능).
- **`scripts/core/SceneFlow.gd`**: `intro_card_path`·`show_intro_cards` export + `_intro_card`/`_pending_intro_stage`/`_test_force_intro`. `_intro_enabled()` = show_intro_cards ∧ 카드배선 ∧ (헤드리스 자동 스킵 | 테스트 강제). `load_stage`가 카드 게이트 시 add_child 전 `auto_begin=false` 설정 후 `_show_intro_card`, dismiss→`begin()`. `_unload_current_screen`에서 `_reset_intro_card`(전환 race 시 stale begin 차단).
- **`scenes/Main.tscn`**: GlobalUI에 StageIntroCard 인스턴스 + SceneFlow.intro_card_path 배선.
- **`scripts/core/Strings.gd`**: `guide.intro_title`·`guide.intro_body_placeholder`(Phase 4 placeholder 카피).
- **신규 테스트 3종**: StageRunnerBeginGateTest(게이트 전 spawn/timer 정지 → begin → 시작 + 멱등) / StageIntroCardShowTest(show→시작버튼/Esc→intro_dismissed 1회) / StageIntroCardHeadlessSkipTest(헤드리스 스킵 즉시 begin + _test_force_intro 게이트→dismiss→begin).

## 핵심 설계 결정
- **헤드리스 자동 스킵**(`DisplayServer.get_name()=="headless"`)이 "헤드리스/플레이테스트 스킵 플래그"의 구현. 기존 SceneFlow 구동 헤드리스 테스트(GameFlow/SceneFlow*/EscTest 등)가 **무수정으로** 즉시 begin → 회귀 0. 웹/데스크톱 빌드(비헤드리스)는 카드 노출.
- **헤드리스 테스트는 SceneFlow를 거치지 않고 Stage 씬 직접 로드** → auto_begin 기본 true → 종전과 동일 자동 시작. (Campaign* 전부 무변경 동작.)
- `_test_force_intro` seam으로 헤드리스에서도 카드 노출→게이트→dismiss→begin 경로를 자동 검증(비헤드리스 윈도우 실행 없이).

## 검증
- **신규 3 테스트 PASS** (phase verify command).
- **광범위 회귀 32/32 PASS, 0 회귀**:
  - 캠페인 클리어 S1~S9 9종 (saved 5/5 또는 정본 수치).
  - 음성 캠페인 NoClimber/NoBridge/NoSkill/NoBasher.
  - SceneFlow ScreenState/BootBypass/EmitContract/SwapNoStaleEmit/LastStagePredicate/StageScan.
  - StageDialog ShowResult/Dismiss/Esc, Pause StageFreeze/Assign/MenuSmoke.
  - StageRunner ReleaseRateAction/ToolbarDisable, HudInitialCandyHp, SfxRequestEmit.
  - 통합 TapTargetGlowIntegration(Phase 2/3), CarryFall, BridgeOverWater, SandMoundClimb, StickyStuckRelease, WaterHazardLossCarrying.
- **GameFlowTest Scenario B = 선재 실패**: `git stash`로 pristine HEAD에서도 동일 `await_signal timeout`(Stage09 3-스킬). 내 변경과 무관(핸드오프 메모의 full-suite 선재실패군). Scenario A는 PASS(begin 게이트 경유 정상).

## 수용 기준 점검
- `StageRunner.begin()`가 테스트에서 직접 호출 가능(카드 의존 없음). ✓ (StageRunnerBeginGateTest)
- 카드 표시 중 게임 정지(스폰·타이머 미진행), 닫으면 정확히 1회 시작. ✓ (BeginGate 멱등 + HeadlessSkip force-intro 게이트)

## Self-Review Round 1 (자체 적대적)
가혹 기준(CRITICAL/HIGH/MEDIUM/LOW + hypothetical + cross-doc + dead branch + circular SoT)로 점검:
- **degraded 동기 emit**: connect(_ready) ⊂ start(begin) 순서 유지 — `_spawner_finished` 영구 false 회귀 없음. (SfxRequestEmit/Campaign no_more_ants 음성 통과로 실증.)
- **카드 미배선/비-StageRunner 루트**: `_intro_card==null` 또는 `has_method("begin")` 거짓 → gate 안 함 → auto_begin 경로. `set("auto_begin",...)`는 gate 시(=begin 보유)만 호출. 안전.
- **전환 race**: 카드 표시 중 replay(Ctrl+R)/menu → `_unload_current_screen`→`_reset_intro_card`(disconnect one-shot + hide_intro + pending clear). dismiss의 generation token도 stale 봉쇄. `_on_intro_dismissed`는 `node==_current_stage_node` 재확인. 다중 가드로 stale begin 0.
- **부트 race**: SceneFlow._ready→_boot→go_to_title→_unload→_reset→hide_intro가 카드 _ready 전 호출 → `is_node_ready()` 가드로 no-op(부트 시 어차피 숨김). SCRIPT ERROR 제거 확인.
- **헤드리스 검출 견고성**: `DisplayServer.get_name()`은 `--headless`에서만 "headless", 실 플랫폼은 OS display server명. 웹/데스크톱 오검출 없음.
- **Esc double-consume**: 카드 비표시 시 `_unhandled_input` early-return → StageDialog/InputRouter Esc 경로 무간섭(StageDialogEscTest PASS로 실증).
- **dead/이중 SoT**: 신규 카테고리/배치 SoT 미도입(Phase 4 범위 밖). begin 게이트는 단일 진입점.
- **자체 판정: HIGH/CRITICAL 0.** → codex 리뷰 진행.

## Round 1 (codex adversarial-review)

Verdict: **needs-attention** (CRITICAL/HIGH 0, MEDIUM 1)

- **[medium] 인트로 카드 위로 pause 가능 — begin이 무관한 pause/menu 상태 뒤에 갇힘** (`Main.tscn`): `load_stage()`가 카드 표시 전에 `current_screen=STAGE`로 두고, `PauseMenu`는 `StageDialog`만 알고 `StageIntroCard`는 모름. 카드 표시 중 PAUSE_TOGGLE이 여전히 수용 → StepFrame이 `tree.paused` 토글 + PauseMenu가 카드 위 스택 → dismiss가 paused tree로 begin하거나 모달 중첩. 신규 테스트 미커버.
  - 권고: 카드를 StageDialog와 동일 모달/pause 게이트에 배선 + 카드 표시/dismiss 중 PAUSE 차단 + SceneFlow 구동 테스트로 pause-toggle 무효 + dismiss 정확히 1회 begin 검증.

## Round 1 수정 (codex MEDIUM 해소)

policy: impl stage는 CRITICAL/HIGH만 must-fix이나, 본 MEDIUM은 ① 수용기준("닫으면 깨끗하게 시작")과 직결 ② 타깃(초등학생) 모달 스택 민감 ③ cheap → **수정 채택**.
- **중앙 게이트 채택**(PauseMenu만 고치는 것보다 완전): `SceneFlow._show_intro_card`에서 `InputRouter.set_pause_actions_blocked(true)`, `_on_intro_dismissed`/`_reset_intro_card`(전환)에서 false. InputRouter가 PAUSE_TOGGLE/STEP_FRAME/RESTART_STAGE emit 자체를 막음 → StepFrame의 `tree.paused` 토글 + PauseMenu 표시 둘 다 봉쇄(둘 다 PAUSE_TOGGLE emit 의존). 카드 Esc는 `_unhandled_input`(action 아님)이라 무영향(PAUSE=Space32, STEP=period46, RESTART=Ctrl+R82 ≠ Esc 검증).
- **카드 backdrop(full-rect mouse STOP)**이 HUD PauseBtn 클릭 경로도 차단 → 키/패드 action만 벡터였고 그것을 게이트가 봉쇄 → 완전.
- **StageIntroCardHeadlessSkipTest force-intro 케이스 확장**: 카드 중 `are_pause_actions_blocked()==true` + tree 미pause + PauseMenu 미표시 단언, dismiss 후 `==false` + begin 단언.
- 검증: 신규 3 + Pause{MenuSmoke,Assign,StageFreeze} + StageDialogEsc + SceneFlowScreenState 전부 PASS. 0 회귀.

## Self-Review Round 2 (Round 1 fix 자체 적대적)
- **shared 플래그 StepFrame 충돌**: 카드 표시 중 STEP_FRAME도 차단 + stage begin 전이라 stepping 발생 불가 → StepFrame이 같은 플래그를 동시에 쓸 수 없음. 카드는 true→false로 자기 구간을 닫음 → 충돌/clobber 0.
- **플래그 leak**: dismiss(false) 외에도 외부 request_main_menu→`_unload`→`_reset_intro_card`가 `_pending != null` 시 false → 메뉴 전환 후 stuck 0.
- **idempotent**: 중복 false 무해. InputRouter null(유닛 카드 단독 테스트)이면 SceneFlow 미경유라 호출 안 됨 + null 가드.
- **HUD PauseBtn**: 카드 full-rect backdrop이 클릭 차단 → 비-action pause 경로도 봉쇄.
- **기존 회귀**: 카드는 신규 상태라 헤드리스(=기존 테스트)는 카드 미표시 → 플래그 미설정 → 무영향(Pause 회귀 PASS 실증).
- **자체 판정: HIGH/CRITICAL 0, R1 MEDIUM 근본 해소.** → codex 재리뷰.

## Round 2 (codex adversarial-review)

Verdict: **needs-attention** (CRITICAL/HIGH 0, MEDIUM 1 — R1 fix의 구조 취약)

- **[medium] in-flight StepFrame이 카드 pause-block을 clear** (`SceneFlow.gd`): R1 fix가 쓴 `set_pause_actions_blocked`는 StepFrame과 **공유 단일 bool**. interleaving: stepping 중(StepFrame block) → `PauseMenu._on_restart_pressed`가 request_replay **직접 emit**(InputRouter 우회) → SceneFlow가 새 stage+카드 로드(카드 block true) → 옛 StepFrame continuation이 `_release_gate()`로 false 기록 → 카드 표시 중 pause 재개방. last-writer-wins clobber.
  - 권고: 소유권 인식(keyed/ref-count) blocking으로 StepFrame이 자기 block만 해제하게 + interleaving 회귀 테스트.

## Round 2 수정 (codex MEDIUM 해소 — 구조적 = self-review 정책상 우선 처리)

- **소유권 분리(two independent bool)**: `InputRouter._pause_actions_blocked`(StepFrame 소유, `set_pause_actions_blocked`) + 신규 `_intro_pause_blocked`(인트로 소유, `set_intro_pause_blocked`). 게이트는 `_pause_blocked()=OR`. 모든 검사점(dispatch line 78 + b-button line 261 + `are_pause_actions_blocked()`)을 OR로 통일. StepFrame은 자기 bool만 토글 → 카드 block clobber 불가(역도 동일).
- **SceneFlow._set_intro_pause_block** → `set_intro_pause_blocked` 호출로 변경.
- **leak 방어**: `SceneFlow._exit_tree`가 카드 표시 중 teardown 시 인트로 게이트 해제(autoload 잔존 차단).
- **신규 테스트 IntroPauseBlockOwnershipTest**: 양방향 clobber 불가 단언(StepFrame release가 인트로 block 유지 + 역). phase verify에 추가(frontmatter+status.json).
- 검증: 신규 4(Ownership 포함) + StepFrame + InputRouter×3 + Pad{Restart,Input} + Pause×3 전부 PASS. 0 회귀.

## Self-Review Round 3 (Round 2 fix 자체 적대적)
- **양방향 clobber**: 두 bool 독립 저장 → StepFrame release(자기 bool false)가 인트로 bool 무영향, 역도 동일(IntroPauseBlockOwnershipTest 양방향 PASS 실증).
- **게이트 일관성**: dispatch·b-button·are_pause_actions_blocked 셋 다 `_pause_blocked()` OR 단일 SoT 경유 — 검사점 누락 0.
- **기존 회귀**: 헤드리스(=기존 테스트)는 인트로 bool 미설정 → OR == StepFrame bool → 동작 불변(StepFrame/InputRouter/Pad PASS 실증).
- **leak**: dismiss·reset·_exit_tree 3경로로 인트로 bool 해제. StepFrame bool은 StepFrame 소유 lifecycle. 교차 간섭 0.
- **hypothetical**: SceneFlow Main teardown mid-card → _exit_tree가 해제. run_test는 scene당 fresh process라 autoload 상태 cross-test leak 없음(추가 안전망).
- **자체 판정: HIGH/CRITICAL 0, R2 MEDIUM 근본 해소.** → codex 재리뷰.

## Round 3 (codex adversarial-review) — 종결

Verdict: **approve** (no material findings)

> No material R3 blocker found. The actual diff splits StepFrame and intro ownership, all inspected pause-affecting dispatch checkpoints use the OR gate, SceneFlow clears the intro-owned block on dismiss/reset/teardown, and the added ownership test covers both clobber directions.

**impl-stage 루프 종결**: codex R1(MED)→fix+self R2→codex R2(MED 구조)→fix+self R3→codex R3 **approve**. CRITICAL/HIGH 0 유지, MEDIUM 2건 모두 근본 수정(defer 없음). verdict clean 도달.
