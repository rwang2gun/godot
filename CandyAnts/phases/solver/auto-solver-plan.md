---
name: auto-solver
duration_estimate: 28800
verify: python scripts/run_test.py tests/DeterminismReplayTest.tscn && python scripts/run_test.py tests/PlanReplayHarnessTest.tscn && python scripts/run_plan.py --selftest
large_change_ok: false
sot: phases/solver/auto-solver-plan.md
sot_aux: [scripts/core/StageRunner.gd, scripts/core/SceneFlow.gd, scripts/core/ScoreSystem.gd, scripts/ant/Ant.gd, scripts/world/Home.gd, scripts/ui/SkillToolbar.gd, scripts/core/SkillRegistry.gd, scripts/run_test.py, tests/CampaignS11ClearTest.gd]
---

# 트랙: 스테이지 자동 솔버 (auto-solver)

## 목적
스테이지를 **자동으로 풀어내는 솔버**를 만들어 (1) 레벨의 클리어 가능 여부를 기계적으로 검증하고 (2) 이후 자동 레벨 디자인(풀이 가능성·최소 스킬·난이도 지표 산출)에 재사용한다. 게임플레이 phase와 직교한 **툴링 트랙**이며, 산출 코드는 Godot 컨벤션대로 `scripts/`·`tests/`·`tools/`에 살고, 트레일은 `codex-worklog/solver/STATUS.md`에 누적한다(이 문서는 plan SoT).

## 핵심 결정 (사용자 정렬 2026-06-18)
- **D1 · 시뮬레이션 코어 = 실제 엔진 인-더-루프.** 별도 경량 모델을 재구현하지 않고 **진짜 Godot 게임을 헤드리스로 돌려** 시뮬한다. 충실도 100%(풀이 판정이 실제 게임과 어긋나지 않음), 스킬/상태 추가 시 자동 동기화. 속도는 트리거-추상화 행동공간으로 탐색량을 줄여 상쇄.
- **D2 · 빌드 순서 = 리플레이 하니스 먼저.** Phase 0(결정론 게이트) → Phase 1(데이터 기반 플랜-리플레이 하니스) → Phase 2(탐색 솔버) → Phase 3(레벨 디자인 활용). 각 단계가 단독 가치·검증 가능.
- **D3 · 행동공간 = 프레임-정확이 아니라 트리거-조건 단위.** 기존 `CampaignS11ClearTest`가 *"최전방 walker가 col20 도달 시 blocker"* 식으로 쓰인 그 추상을 일반화한다. 후보 플랜이 수십~수백 개로 떨어져 인-더-루프 탐색이 현실적이 된다.
- **D4 · 정답 기준(ground truth) = 솔버가 실제로 달성한 클리어** (사용자 결정 2026-06-18). 기존 드라이버·주석·레벨 데이터의 "이렇게 풀린다" 가정은 **신뢰하지 않는다.** 어떤 스테이지가 클리어 가능한지는 **솔버가 실제 인벤토리로 찾은 플랜을 무수정 게임 코드(`StageRunner._conclude_stage`/`ScoreSystem`)가 클리어로 판정**하느냐로만 결정한다. 순환이 아닌 이유: 클리어/실패 verdict를 하니스가 아니라 **게임 본체가 emit**(인-더-루프)하므로, 하니스가 "클리어"를 보고하면 그건 플레이어가 실제 달성 가능한 클리어다.

## 진단 결과 (조사 2026-06-18, 코드 인용)
- **로직 결정론적**: 게임플레이 스크립트에 `randf/randi/RandomNumberGenerator/randomize` 사용 0건. 같은 행동을 같은 (고정-delta) 프레임에 넣으면 결과 동일.
- **결정론 누수 = 게임플레이 시계 전수**(Round 1 HIGH-1 반영, "grace 1곳"은 오판): 스폰 grace 벽시계(`scripts/ant/Ant.gd:141-144`, `scripts/world/Home.gd:34,85-87`) **+** 스폰 `Timer`(`scripts/core/AntSpawner.gd:22-35,43-52`) **+** 리스폰 `Timer`(`scripts/world/Home.gd:60-72`) **+** 스테이지 타임아웃 `_process(delta)`(`scripts/core/StageRunner.gd:160-185`). 솔버 결정론 모드에서 이들 전부를 **물리-프레임/고정-delta 기준으로 통일** 필요(Phase 0).
- **무관(확인만)**: `scripts/world/PlantDebris.gd`의 `randf_range`는 식물 절단 시 **시각 파편 전용**(충돌·게임로직 비참여 확인 대상). `scripts/input/InputRouter.gd:135`·`scripts/core/SfxPlayer.gd:103`의 벽시계는 입력 디바운스·오디오 스로틀 — 솔버는 입력을 우회하고 헤드리스는 무음이라 결과 무관.
- **이동은 delta-time 적분** (`WalkerState.update`: `velocity.y += gravity * delta`). 헤드리스 `--fixed-fps 60`이면 delta가 1/60로 고정 → 재현 가능.
- **클리어 판정**: `StageRunner._conclude_stage`가 `Scoring.compute_stars(saved, original_hp) >= 1`이면 `EventBus.stage_cleared.emit(result)`, 아니면 `stage_failed`. result dict = `{cleared, saved, lost, original_hp, score, time_left, reason}`.
- **스킬 적용 경로**: `SkillToolbar._apply_skill(id, ant)` = `SkillRegistry.get_skill(id).new()` → `can_apply(ant)` 재검사 → `apply(ant)` → `_inventory[id] -= 1`. 설치형(leaf_jump/표지판)은 `_place_*(world)` 경로. **하니스는 이 경로를 재사용**해 인벤토리·유효성 규칙을 그대로 탄다.
- **헤드리스 하니스 기존재**: `scripts/run_test.py`가 `godot --headless --path . --quit-after N <scene>` 실행, 테스트 씬이 `get_tree().quit(code)`로 결과 코드 반환. `CANDYANTS_SAVE_PATH` 환경변수로 세이브 격리 → **병렬 실행 안전**.

---

## Phase 0 — 결정론 + 속도 게이트 (선결, 게임코드 소량 수정)

### 목표
같은 입력이면 항상 같은 결과임을 **per-frame로 보증**하고, 헤드리스가 실시간보다 **충분히 빠른지 측정**한다. 둘 중 하나라도 실패하면 이후 단계 진입 금지(특히 속도 미달 시 인-더-루프 아키텍처 재검토).

### 작업
1. **게임플레이 시계 전수 인벤토리 + 결정론 모드** (HIGH-1): 스폰 grace(`Ant.gd:141-144`/`Home.gd:34,85-87`), 스폰 `Timer`(`AntSpawner.gd:22-35,43-52`), 리스폰 `Timer`(`Home.gd:60-72`), 스테이지 타임아웃 `_process(delta)`(`StageRunner.gd:160-185`)을 모두 식별. 솔버 결정론 모드에서 **물리-프레임/고정-delta 기준으로 통일** — delta는 `--fixed-fps 60`로 1/60 고정.
   - **Timer 결정론 명시** (R2-HIGH-3): 현 `Timer`들은 `process_callback`·`ignore_time_scale` 미설정이라 **기본 idle 콜백 + time_scale 영향**(Godot 4.6 Timer 기본값). 솔버 모드에서 스폰/리스폰 Timer를 **`Timer.TIMER_PROCESS_PHYSICS`로 설정**(고정-delta physics 틱)하거나, Timer 게이팅을 **frame-count 게이팅으로 대체**해 idle-delta·time_scale 변동을 제거. 스테이지 타임아웃도 `_process(delta)` 누적 대신 **frame-count(`deadline_frames`)** 로 판정. 어느 쪽이든 인-게임 기본 동작 불변을 회귀로 입증.
2. **grace 의미 결정 = 물리-프레임 카운트** (HIGH-2): grace를 `Engine.get_physics_frames()` 델타(또는 StageRunner 주입 sim-frame)로 비교. `spawn_grace_seconds × 60` 환산. **프레임 카운트는 `Engine.time_scale` 불변**이므로, time_scale을 바꾸는 기존 테스트(`GameFlowTest.gd:52-56`, `StageRunnerBeginGateTest.gd:12-14`)에서 실효 grace가 달라지지 않는지 재확인하고 필요 시 기대값 조정.
3. **속도 측정 게이트** (CRITICAL-2): `--fixed-fps`(언캡) 헤드리스에서 한 스테이지를 끝까지 돌릴 때 **벽시계 frames/sec**를 실측·기록(`STATUS.md`). 기존 `GameFlowTest`가 `Engine.time_scale=8.0`으로 가속하는 사실(`GameFlowTest.gd:52-56`)은 기본 헤드리스가 실시간 페이싱일 수 있음을 시사 → `--fixed-fps`가 실제 언캡 가속을 주는지 검증. 목표: 한 롤아웃 ≤ 수 초. 미달 시 가속 메커니즘(`--fixed-fps` vs `time_scale` 상향 vs `physics_ticks_per_second` 상향) 비교 후 채택, 그래도 미달이면 **인-더-루프 가정 재검토 보고**(Phase 2 차단).
4. **PlantDebris randf 무영향 확인·문서화** (LOW-1): `PlantDebris.gd:3-5,27-42`가 충돌·점수 비참여(Sprite2D 파편 시각 전용) 명시 — 결정론 제외 근거를 게이트 테스트 주석/문서에 기록(코드 변경 0).
5. **게이트 테스트 `tests/DeterminismReplayTest`** (MEDIUM-2): 한 스테이지(예: Stage11)를 **동일 빈 플랜으로 2회** 실행 → **매 N프레임 개미 위치·상태 해시 + 종단 결과**가 완전 일치 단언(종단만 비교하지 않음 → `move_and_slide`/Area2D 순서 부동소수 비결정 조기 검출). in-process 2회 반복 선호.

### 수정 대상
- `scripts/ant/Ant.gd` (grace 프레임화 + `spawn_index` 노출 — MEDIUM-1), `scripts/world/Home.gd` (grace/리스폰 프레임화)
- `scripts/core/AntSpawner.gd` (스폰 타이밍 결정화 + ant에 `spawn_index` 기록), `scripts/core/StageRunner.gd` (타임아웃 프레임화 옵션)
- `scripts/run_test.py`/신규 `run_plan.py` (`--fixed-fps` 경로; 기본 동작 무변경, 옵트인)
- 신규 `tests/DeterminismReplayTest.{gd,tscn}`; 속도 측정치 `codex-worklog/solver/STATUS.md` 기록

### Acceptance
- `DeterminismReplayTest` PASS(per-frame 해시 일치).
- 속도 게이트: 측정 frames/sec + 한 롤아웃 시간 목표 충족(또는 미달 보고·아키텍처 재검토).
- 기존 `CampaignS11~S14ClearTest`·`GameFlowTest`·`StageRunnerBeginGateTest` 등 **전 회귀 그린 유지**(grace/timer 프레임화가 플레이 불변 입증, time_scale 테스트 포함).

---

## Phase 1 — 플랜 스키마 + 리플레이 하니스 (핵심 산출물)

### 목표
**플랜(데이터)** 을 받아 헤드리스로 재생하고 `cleared/saved/...`를 보고하는 범용 하니스. 손으로 짠 `CampaignSxx*.gd` 드라이버를 데이터로 대체할 수 있게 한다.

### 플랜 데이터 모델 (JSON — 솔버가 생성·소비하기 쉬움)
```json
{
  "stage_scene": "res://scenes/stages/Stage11.tscn",
  "deadline_frames": 16000,
  "require_saved_ge_hp": true,
  "actions": [
    { "trigger": {"kind": "ant_reaches_x", "x": 960.0, "select": "frontmost", "filter": {"state": "WalkerState", "y_min": 520.0}},
      "skill": "blocker", "target": "trigger_ant", "once": true }
  ]
}
```
- **trigger.kind**: `at_frame`(frame) / `ant_reaches_x`(x, dir) / `ant_at_cliff` / `ant_on_wall` / `active_ants_le`(n) / `picked_ge`(n). 최소셋부터, 확장 가능.
- **target / select**: `frontmost`(최대 x) / `backmost` / `nth_by_spawn`(i) / `closest_to_cell`(cell) / `trigger_ant`(트리거를 만족시킨 그 개미, instance_id로 고정). 설치형은 `cell` 지정.
- **selector 동률 tie-break** (MEDIUM-1): 모든 select는 1차 키(x 또는 거리) 동률 시 **`spawn_index` asc → `instance_id` asc**로 확정(CursorTargeting의 instance_id tie-break 관행 계승). 후보 개미 정체성이 reload·동률에 흔들리지 않음.
- **후보 스코프** (HIGH-3): 후보 개미 집합은 **활성 스테이지 루트 하위로 스코프**(`is_ancestor_of`) + `is_queued_for_deletion`/alive 필터. 전역 `get_nodes_in_group("ants")` 오염 차단 — `StageRunner.gd:238-250`·`CursorTargetingResolver.gd:59-73` 필터 재사용.
- **repeat** (HIGH-4): `"once"`(기본) | `"until_inventory_empty"` | `{"count": N}`. 반복형은 **per-ant 적용 이력(instance_id 집합)으로 중복 적용 차단** → S13의 *"blocker 후 이후 모든 walker에 climber를 인벤토리 소진까지"* 를 한 액션으로 표현.
- **filter**: 대상 후보를 `state`/`y_min`/`y_max`/`has_candy`로 제한(기존 드라이버의 `LOWER_Y`·`WalkerState` 검사 일반화).
- **fail 정책**: 인벤토리 0/`can_apply` 실패 시 해당 발동을 폐기할지(skip) 충족 때까지 재시도(retry)할지 액션 필드로 명시.

### `scripts/core/PlanRunner.gd` (씬 드라이버, GDScript) — MEDIUM-3
> 위치 확정: GDScript 드라이버는 `scripts/core/PlanRunner.gd`(CLAUDE.md `scripts/{core,...}` 규칙). `tools/solver/`는 **Python 전용**(Phase 2~3 오케스트레이터).
- 대상 스테이지 씬을 자식으로 인스턴스(또는 SceneFlow 경유) → `_physics_process`마다 미발동 액션의 트리거 평가(스코프·tie-break·repeat 규칙 적용) → 충족 시 **대상 개미 해석 → 인벤토리-충실 적용 경로**(아래) → `EventBus.stage_cleared/failed` 캐치 → 결과 dict.
- 종료: 클리어/실패/`deadline_frames` 초과. `require_saved_ge_hp`면 `saved>=original_hp`까지 요구(아니면 fail).
- 결과를 stdout JSON + 종료코드(0=요구충족, 1=미충족/deadline)로 노출.

### 스킬 적용 경로 = 인벤토리-충실 (CRITICAL-1)
- 하니스는 **인벤토리·`can_apply` 검사를 거치는 경로**로만 스킬을 적용한다. **`Skill.new().apply()` 직접 호출 금지**(인벤토리 우회 = 플레이어가 못 쓰는 풀이를 허용 → 솔버가 거짓 "클리어 가능"을 낼 위험).
- 구현 = **`scripts/core/SkillApplier.gd`를 SoT로 추출, SkillToolbar가 위임** (R2-MEDIUM-1): `SkillToolbar._apply_skill`/`_place_sign`/`_place_leaf_jump_pad`는 `_slots` UI 갱신·SFX·terrain 조회와 **엉켜 있어**(`scripts/ui/SkillToolbar.gd:304-317,325-379`) 헤드리스에서 그대로 호출 불가. 따라서 인벤토리 차감 + `can_apply` + 설치 유효성(SignPlacement) **순수 규칙**을 `SkillApplier`로 빼고, toolbar는 SkillApplier를 호출한 뒤 UI/SFX만 덧붙이도록 리팩터. 하니스/PlanRunner는 SkillApplier만 사용. 규칙 SoT가 1곳이 되어 toolbar와 하니스가 절대 갈라지지 않음.
- **대상 선택과 적용의 분리** (R2-MEDIUM-2): "어느 개미냐"는 PlanRunner의 **스코프 셀렉터**(활성 루트 + tie-break)가 정한다 — toolbar의 전역 `_find_closest_ant`(`SkillToolbar.gd:412-429`, 전역 `ants`)는 **재사용하지 않는다**. SkillApplier는 "이 개미에 이 스킬을 인벤토리 규칙대로 적용"만 담당.
- **인벤토리 밖 스킬은 적용 불가가 정상**: 예) `tests/CampaignS14ClearTest.gd:44-47`은 stage14 인벤토리(`data/stages/stage14.tres:14-17` = blocker/climber)에 없는 `FloaterSkill`을 직접 적용해 통과하지만, 그건 인벤토리를 우회한 것. 충실 경로는 인벤토리 밖 스킬을 거부한다. **이 드라이버/주석은 ground truth가 아니다(D4)** — stage14의 클리어 가능 여부는 실제 인벤토리로 솔버가 판정한다(주석 무시).

### `scripts/run_plan.py` (CLI 래퍼)
- 플랜 파일(들)을 받아 헤드리스(`--fixed-fps`)로 `PlanRunner` 실행, 결과 JSON 출력.
- `--selftest`: 골든 플랜을 돌려 기대 결과와 대조 (비순환, 아래).
- **배치 모드 + 정리 계약** (LOW-2): 한 프로세스에서 여러 플랜 순차 실행(씬 reload)해 godot startup 상각. 플랜 간 **스테이지 루트 remove+free, `EventBus` 시그널 연결 해제, SaveData 격리**(in-process 반복 시 결과 기록 억제 또는 임시경로 재설정) — `SceneFlow.gd:291-308` 언로드 로직 참조. 병렬은 다중 프로세스 + `CANDYANTS_SAVE_PATH` 격리. **상태 누수 0**을 `PlanReplayHarnessTest`에 단언.

### 하니스 정확성 검증 (D4 기반, 기존 드라이버 비참조)
- **정답 기준은 게임 본체의 클리어 판정**(D4). 하니스 selftest는 "기존 드라이버와 결과가 같은가"를 **묻지 않는다** — 드라이버·주석은 ground truth가 아니다.
- **Phase 1 메커니즘 검증 = 신규 손작성 골든 플랜**: 솔버가 아직 없으므로, 하니스가 *스킬을 옳은 개미에·옳은 타이밍에·인벤토리 규칙대로* 적용하는지 확인할 **소수의 손작성 플랜**을 **실제 인벤토리에 맞춰 새로** 작성(S11/S12/S13 등). 이는 메커니즘 점검 fixture일 뿐 레벨 설계 주장이 아니며 기존 드라이버를 복제하지 않는다. 기대값(클리어/실패)은 입력 플랜에 대한 **게임 verdict**를 단언(입력=플랜, 출력=무수정 게임 코드의 판정 → 비순환).
- **S14 특례 없음**: floater 주석 무시. stage14는 실제 인벤토리(blocker/climber)로 두고 **클리어 가능 여부는 Phase 2 솔버가 판정**. 풀리면 그 플랜이 정답, 안 풀리면 "현 인벤토리로 클리어 불가"가 정답(설계 재고 신호). 보류·defer 표시 불필요.
- negative(예: "blocker 없이 빈 플랜 → 실패")도 손작성 플랜으로 표현해 하니스가 실패를 옳게 보고하는지 확인.
- 기존 GDScript 드라이버는 **게임 회귀 테스트로 남기되**(삭제 안 함) **솔버 정답 기준으로는 참조하지 않는다**(상호 무간섭).

### 수정/신규 대상
- 신규 `scripts/core/PlanRunner.gd` (시뮬 드라이버, GDScript — 위치 확정)
- 신규 `scripts/core/SkillApplier.gd` (필요 시 — 인벤토리·can_apply 충실 적용 래퍼, toolbar와 규칙 공유)
- 신규 `scripts/run_plan.py`
- 신규 `tests/PlanReplayHarnessTest.{gd,tscn}` (알려진 플랜→알려진 결과 + 배치 상태누수 0)
- 신규 `data/solutions/stage11~13.solution.json` (손작성 메커니즘 골든 + negative 플랜)
- 신규 `codex-worklog/solver/STATUS.md` (트랙 SoT 시작)

### Acceptance
- `PlanReplayHarnessTest` PASS(+ 배치 상태누수 0). `run_plan.py --selftest`로 **손작성 메커니즘 골든**(S11/S12/S13 + negative)이 게임 verdict대로(클리어/실패).
- 트리거-추상 플랜이 결정론 게이트 위에서 **반복 실행 시 동일 결과**.

---

## Phase 2 — 탐색 솔버

### 목표
스테이지를 입력하면 **풀이 플랜을 탐색**해 출력(없으면 "탐색범위 내 미해결").

### 설계
- **행동공간 enumeration**: 스테이지 `available_skills` + `skill_inventory`에서 트리거-추상 후보 액션을 생성(스킬종류 × 대상 select × 트리거 후보 격자). 트리거 후보는 지형 랜드마크(벽 앞/낭떠러지/물 직전 x좌표)에서 도출 → 폭발 억제.
- **탐색 전략(1차)**: greedy + rollout 또는 beam search. 휴리스틱: 경로 진척(개미 최대 x/목표 근접)·candy 픽업 수·안전 낙하·잔여 인벤토리. 각 후보 플랜은 Phase 1 하니스로 실평가(인-더-루프).
- **병렬 평가**: 다중 헤드리스 프로세스(`CANDYANTS_SAVE_PATH` 격리)로 후보 플랜 동시 채점.
- **예산/종료**: 최대 rollout 수·시간 cap. 결정성을 위해 탐색 순서 고정(난수 미사용 또는 시드 고정).

### 산출
- 신규 `tools/solver/solve.py` (탐색 오케스트레이터, Phase 1 `run_plan.py` 호출).
- 출력: 풀이 플랜 JSON + 별점/`saved`, 또는 미해결 리포트(탐색 통계).

### Acceptance
- 솔버가 **무힌트로** 각 스테이지를 실제 인벤토리로 평가 → 클리어 가능하면 유효 플랜 산출(하니스 재생으로 게임 verdict가 클리어), 불가능하면 "현 인벤토리로 클리어 불가" 리포트. **이 솔버 결과가 곧 그 스테이지의 클리어 가능 여부 정답**(D4).
- S11~S14 전부 동일 잣대로 처리(S14도 특례 없이 blocker/climber로 판정). 솔버가 못 푸는 스테이지는 설계 재고 신호로 보고.

---

## Phase 3 — 레벨 디자인 활용 (솔버 소비자)

### 목표
생성/편집된 레벨에 솔버를 돌려 **품질·난이도 리포트** 산출.

### 산출
- `tools/solver/audit_level.py`: 입력 layout/stage → (a) 풀이 존재? (b) 최소 스킬 수·종류 (c) 잉여 인벤토리(설계 의도보다 헐거운가) (d) 트리비얼(스킬 0개 빈 플랜으로 클리어 — 의도치 않은 무난이도) 여부 → 지표 dict.
- 레벨툴 애드온·웹 에디터 연동은 **후순위(별도 트랙)**.

### Acceptance
- 기존 스테이지(예: Stage01 트리비얼/Stage12 blocker-필수)에 대해 리포트가 직관과 일치(트리비얼 검출·필수 스킬 식별).

---

## 검증 방법 (verify 프론트매터)
1. **결정론**: `DeterminismReplayTest`(per-frame 해시 2회 동일).
2. **하니스**: `PlanReplayHarnessTest` + `run_plan.py --selftest`(손작성 메커니즘 골든 + negative → 게임 verdict 대조). 기존 드라이버 비참조.
3. **기존 회귀 무파손**: Phase 0 후 `CampaignS11~S14ClearTest`·`GameFlowTest`·`StageRunnerBeginGateTest`·매니페스트/언락 테스트 전부 그린(grace/Timer 프레임화·SkillApplier 리팩터에도 게임 플레이 불변 — 이들은 게임 회귀 테스트이지 솔버 정답 기준이 아님).
4. **솔버(Phase 2)**: 각 스테이지를 실제 인벤토리로 평가 → 클리어 플랜 또는 "불가" 리포트(= 클리어 가능 여부 정답, D4).
5. **수동 확인**: 솔버가 낸 플랜을 게임에서 재생(선택)으로 눈으로 클리어 확인.

## 회귀 주의 (사전 식별)
- **grace/timer 의미 불변 (Phase 0 최대 리스크, HIGH-1/2)**: 프레임화가 실효 grace·스폰 간격을 바꾸면 개미 위치·Home 흡수 타이밍이 달라져 기존 ClearTest가 깨진다. 모든 게임플레이 시계를 `초 × 60` 프레임으로 정확 환산하고, **프레임 카운트는 time_scale 불변**임을 이용해 가속 테스트(GameFlowTest·StageRunnerBeginGateTest) 영향 재확인. Phase 0 acceptance에 **기존 회귀 전 그린** 포함.
- **속도 가정 (CRITICAL-2)**: 인-더-루프 전체가 "헤드리스가 실시간보다 빠르다"에 의존. 기존 테스트의 `time_scale=8.0`은 기본 페이싱이 실시간일 수 있다는 신호 → Phase 0 속도 게이트 미충족 시 Phase 2 차단·아키텍처 재검토.
- **스킬 적용은 인벤토리-충실 경로 (CRITICAL-1)**: `Skill.new().apply()` 직접 호출 금지. 기존 드라이버는 인벤토리를 우회(예: S14가 미보유 floater 적용) → 하니스는 `SkillApplier`로 정합. **드라이버·주석은 ground truth 아님(D4)** — S14도 특례 없이 실제 인벤토리로 솔버가 클리어 가능 여부 판정.
- **셀렉터 결정성 (HIGH-3/MEDIUM-1)**: 후보는 활성 스테이지 루트 스코프 + `(x, spawn_index, instance_id)` tie-break. 전역 `ants` 그룹 직접 순회 금지.
- **드라이버 병행**: Phase 1은 기존 GDScript 드라이버를 삭제하지 않음(마이그레이션은 별도 sweep defer) — 회귀 안전망 유지.
- **결정론 잔여 리스크 (MEDIUM-2)**: `move_and_slide`/Area2D 순서가 부동소수 비결정성을 띠면 per-frame 해시 게이트가 잡아낸다(게이트가 곧 안전장치). 잡히면 Phase 0에서 원인 격리 후 진행.
- **저장 위치**: GDScript 드라이버 `scripts/core/PlanRunner.gd`(+필요시 `SkillApplier.gd`). Python 오케스트레이터 `tools/solver/`. 골든 플랜 fixture `data/solutions/`. 트랙 트레일 `codex-worklog/solver/STATUS.md`.
