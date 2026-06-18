# auto-solver — Plan Stage Adversarial Review

> 정책: CLAUDE.md plan stage — CRITICAL/HIGH 발견 시 최대 2회 수정+재리뷰(3-round cap).
> `/codex:adversarial-review`는 disable-model-invocation이라 `codex exec -s read-only`(gpt-5.5)로 동등 구동.

## Round 1 — codex exec read-only (2026-06-18)

## Verdict: needs-attention

### CRITICAL

[CRITICAL-1] Stage14 골든 리플레이가 `SkillToolbar` 경로로 불가능 -> Stage14에 floater를 넣거나 "toolbar 재생이 CampaignS14ClearTest를 재현한다"는 주장을 철회.
근거: `tests/CampaignS14ClearTest.gd:44-48`이 `FloaterSkill`을 직접 생성·적용. 그러나 `data/stages/stage14.tres:14-17`은 `blocker`·`climber`만 노출. `SkillToolbar._apply_skill`은 인벤토리/슬롯에 없는 스킬을 거부(`scripts/ui/SkillToolbar.gd:304-308`).

[CRITICAL-2] 탐색 처리량 미검증 + 현 증거는 반대 방향 -> Phase 2 전에 측정된 "초당 롤아웃" 게이트 추가.
근거: `scripts/run_test.py:97-103`은 `--headless --quit-after`만 쓰고 `--fixed-fps` 없음. `run_test.py:20`은 18000프레임을 벽시계 안전 타임아웃으로 취급. 기존 장시간 테스트는 `Engine.time_scale = 8.0`으로 명시 가속(`tests/GameFlowTest.gd:52-56`) — 인-더-루프 수백 롤아웃의 위험 신호.

### HIGH

[HIGH-1] "시간 의존은 grace뿐"은 거짓 -> 모든 Timer/delta 게임플레이 시계를 인벤토리하고 솔버 의미 정의.
근거: 스폰 `Timer`(`scripts/core/AntSpawner.gd:22-35,43-52`), 리스폰 `Timer`(`scripts/world/Home.gd:60-72`), 스테이지 타임아웃 `_process(delta)`(`scripts/core/StageRunner.gd:160-185`).

[HIGH-2] grace 프레임화가 가속 테스트 거동을 바꿀 수 있음 -> grace를 벽시계/스케일sim/물리프레임 중 무엇으로 할지 결정 후 테스트 갱신.
근거: 현 grace는 벽시계(`Ant.gd:141-144`, `Home.gd:34,85-87`). 다수 테스트가 `Engine.time_scale` 변경(`GameFlowTest.gd:52-56`, `StageRunnerBeginGateTest.gd:12-14`).

[HIGH-3] 전역 `ants` 그룹은 reload 간 오염 known-issue -> PlanRunner 셀렉터는 활성 스테이지 루트로 스코프 + tie-break 정의.
근거: StageRunner가 이미 오염을 문서화하고 `_spawn_parent.is_ancestor_of`로 필터(`StageRunner.gd:238-250`). CursorTargetingResolver도 동일(`scripts/ui/CursorTargetingResolver.gd:59-73`). 플랜 셀렉터(`auto-solver-plan.md:71-72`)는 미명시.

[HIGH-4] S13 "이후 모든 walker에 climber"가 액션 스키마로 표현 불가 -> repeat/for-each/count-until-inventory 의미 추가.
근거: `CampaignS13ClearTest`가 blocker 후 매 프레임 비-blocker walker마다 climber를 `MAX_CLIMBERS`까지 반복(`tests/CampaignS13ClearTest.gd:56-76`). 플랜은 one-shot + 모호한 `once`만 정의(`auto-solver-plan.md:71-73`).

### MEDIUM

[MEDIUM-1] `frontmost`/`trigger_ant` 동률 시 정체성 불안정 -> `(x/y, spawn_index|instance_id)`로 정렬, spawn_index 노출.
근거: ant는 `_ready`에서 그룹 가입(`Ant.gd:141-145`), 스포너는 zero-based `spawn_index`를 ant에 저장 안 함(`AntSpawner.gd:63-70`). CursorTargeting은 `get_instance_id()` tie-break 사용(`scripts/input/CursorTargeting.gd:7-20`).

[MEDIUM-2] `move_and_slide()` 결정론은 단언일 뿐 증명 안 됨 -> Phase 0은 종단 결과가 아니라 위치 해시 리플레이 필요.
근거: walker/carrying/faller가 매 프레임 `move_and_slide()`(`WalkerState.gd:12-14`, `CarryingState.gd:15-18`, `FallerState.gd:29-35`). blocker 겹침은 물리-프레임 순서+Area2D 시그널 의존(`Ant.gd:766-793`).

[MEDIUM-3] PlanRunner 경로가 repo 규칙과 자가모순 -> GDScript는 `scripts/core/PlanRunner.gd`, `tools/solver/`는 Python 전용.
근거: CLAUDE.md:9가 신규 스크립트를 `scripts/{core,ant,skills,world,ui}/`로 강제. 플랜은 `scripts/world/` 또는 `tools/solver/`라 했다가 `scripts/core/` 후보라고 함(`auto-solver-plan.md:90-92,150`).

[MEDIUM-4] `run_plan.py --selftest`가 순환 게이트 -> 기존 독립 드라이버나 리뷰 확정 골든 결과와 대조하게.
근거: verify 프론트매터가 selftest를 포함(`auto-solver-plan.md:4`). 그러나 selftest 데이터는 같은 phase가 `data/solutions/stage11~14.solution.json`에서 생성(`auto-solver-plan.md:87-98`).

### LOW

[LOW-1] PlantDebris RNG은 올바르게 cosmetic이나 제외 이유를 문서에 기록.
근거: `PlantDebris.gd:3-5`가 충돌/점수 영향 0 명시. RNG은 Sprite2D 파편 offset/rotation/velocity만(`PlantDebris.gd:27-42`).

[LOW-2] 배치 in-process 리플레이의 정리 요구 누락 -> EventBus 연결해제·스테이지루트 제거·SaveData 격리 명시.
근거: SaveData가 매 결과마다 기록(`scripts/core/SaveData.gd:40-54`), `CANDYANTS_SAVE_PATH`는 `_ready`서 1회 읽음(`SaveData.gd:24-32`). SceneFlow는 stale 처리 방지 언로드 로직 보유(`SceneFlow.gd:291-308`).

---

### Round 1 대응 (plan 수정 완료, 2026-06-18)
- **C-1** → Phase 1 "스킬 적용 경로 + 골든 재현" 신설: 하니스는 인벤토리-충실 경로(toolbar 또는 동등 `SkillApplier` 래퍼), `Skill.new().apply()` 직접호출 금지. **S14 콘텐츠 불일치를 발견 결함으로 명시**(stage14 인벤토리에 floater 없음 → 충실 경로 재현 불가 = 정상). 콘텐츠 수정은 솔버 범위 밖 defer, S14 골든은 보류.
- **C-2** → Phase 0에 **속도 측정 게이트** 추가: `--fixed-fps` 헤드리스 frames/sec 실측, 한 롤아웃 ≤ 수 초 목표, 미달 시 가속 메커니즘 비교 후 채택·그래도 미달이면 인-더-루프 재검토 보고. Phase 2 진입 전 필수 게이트.
- **H-1** → Phase 0에 **게임플레이 시계 전수 인벤토리**(스폰/리스폰 Timer, 타임아웃 _process) + 결정론 모드(전부 물리-프레임/고정-delta 기준) 명시.
- **H-2** → grace = **물리-프레임 카운트**로 결정. time_scale 변경 테스트(GameFlowTest, StageRunnerBeginGateTest) 실효 grace 재확인·필요시 기대 조정을 Phase 0 acceptance에 포함.
- **H-3** → 셀렉터를 **활성 스테이지 루트 스코프**(`is_ancestor_of`) + alive/queued 필터로 명시(StageRunner·CursorTargetingResolver 재사용).
- **H-4** → 액션 스키마에 `repeat`(once|until_inventory_empty|{count}) + **per-ant 적용이력 dedupe** 추가(S13 표현).
- **M-1** → 모든 select에 `(x, spawn_index, instance_id)` tie-break 확정 + `Ant`에 `spawn_index` 노출(AntSpawner가 기록).
- **M-2** → DeterminismReplayTest를 **per-frame 위치/상태 해시 + 종단 결과** 일치로 강화.
- **M-3** → PlanRunner = `scripts/core/PlanRunner.gd`(GDScript), `tools/solver/`는 Python 전용으로 통일.
- **M-4** → selftest 비순환화: (1) 충실 표현 가능한 기존 드라이버(S11/S12/S13)와 **하니스 결과 == 드라이버 결과** 교차검증 + (2) 리뷰 확정 하드코딩 기대 대조.
- **M-5/LOW-2** → 배치 in-process 정리 계약(EventBus 해제·루트 free·SaveData 격리) 명시 + 누수 0 단언.
- **LOW-1** → PlantDebris cosmetic 제외 근거를 게이트 테스트 주석/문서에 기록.

## Round 2 — codex exec read-only (2026-06-18)

### Round-1 Status (codex 확인)
RESOLVED: C-2, H-1, H-3, H-4, M-2, M-3, LOW-1, LOW-2. PARTIAL: C-1, H-2, M-1, M-4.

## Verdict: needs-attention

### CRITICAL
None.

### HIGH

[R2-HIGH-1] selftest 교차검증이 거짓 실패 가능 — "기준점" 드라이버가 다른 규칙을 씀 -> 드라이버 재작성/정규화 전엔 드라이버 결과와 `==` 비교 금지.
근거: 플랜이 S11/12/13에 대해 하니스==드라이버를 요구(`auto-solver-plan.md:98-100`)하나, 드라이버는 전역 `ants` 순회 + `Skill.new().apply()` 직접호출(`tests/CampaignS11ClearTest.gd:40-55`, `S12:43-58`, `S13:40-75`). 하니스는 스코프+인벤토리-충실(`auto-solver-plan.md:88,76`) → 정당하게 갈라질 수 있음.

[R2-HIGH-2] S14가 defer이면서 동시에 acceptance/verify에 요구됨 — 모순 -> 콘텐츠 수정 전엔 Phase1/selftest/verify에서 S14 완전 제외(또는 콘텐츠 수정을 Phase1에 포함).
근거: S14 골든 보류(`auto-solver-plan.md:90,102,110`)인데 Phase1 acceptance·검증이 여전히 S11~S14(`auto-solver-plan.md:114,155,157`).

[R2-HIGH-3] Timer 결정론이 Godot 4.6 기준 미명시 — 현 Timer는 기본값 -> 솔버 모드에서 physics/frame-count 게이트 명시 또는 Timer 시계 금지.
근거: Timer가 `process_callback`/`ignore_time_scale` 미설정(`AntSpawner.gd:22-25`, `Home.gd:67-72`). Godot 4.6 Timer 기본 idle 콜백 + time_scale 영향.

### MEDIUM

[R2-MEDIUM-1] `SkillToolbar`를 그대로 헤드리스 재사용 불가 -> `SkillApplier`를 진짜 SoT로 두고 toolbar가 그것을 호출(역방향 아님).
근거: `_apply_skill`이 `_slots` UI 존재·위젯 갱신 의존(`SkillToolbar.gd:304-317`); `_place_*`도 `_slots`/`_inventory`/terrain/노드생성/SFX/슬롯갱신 사용(`SkillToolbar.gd:325-379`).

[R2-MEDIUM-2] toolbar 개미 선택은 전역 — 플랜은 toolbar 규칙 재사용이라 함 -> 솔버 타겟 선택에 `_find_closest_ant` 쓰지 말 것.
근거: toolbar가 전역 `ants`를 `is_alive()`만으로 수집(`SkillToolbar.gd:412-429`), 스코프 패턴(`CursorTargetingResolver.gd:59-73`)과 불일치.

### Round 2 대응 (plan 수정 완료, 2026-06-18)
- **R2-HIGH-1** → selftest 기준점을 **리뷰-확정 하드코딩 기대**로 단일화, 드라이버-동일성 `==` 비교 요구 삭제(드라이버는 무간섭 별도 회귀). 거짓 실패 제거.
- **R2-HIGH-2** → S14를 selftest·acceptance·verify·골든 fixture에서 **전부 제외**(범위=S11/12/13). Phase 2는 S14를 "solvability 검사"로만 활용(콘텐츠 결함 자동 검출 실증).
- **R2-HIGH-3** → Phase 0에 Timer 결정론 명시: 스폰/리스폰 Timer를 `TIMER_PROCESS_PHYSICS`로 설정 or frame-count 게이팅 대체, 타임아웃도 `deadline_frames`로.
- **R2-MEDIUM-1** → `SkillApplier.gd`를 규칙 SoT로 **추출**하고 toolbar가 위임하도록 리팩터 명시(역방향).
- **R2-MEDIUM-2** → 대상 선택(PlanRunner 스코프 셀렉터)과 적용(SkillApplier) 분리, `_find_closest_ant` 재사용 금지 명시.

## Round 3 — codex exec read-only (2026-06-18) — FINAL

### Round-2 Status (codex 확인)
R2-HIGH-1: RESOLVED — selftest가 리뷰-확정 하드코딩 기대 사용, 드라이버 동일성 비교 제거(`auto-solver-plan.md:99-103`).
R2-HIGH-2: RESOLVED — S14를 selftest/Phase1/verify에서 제외(`auto-solver-plan.md:103,115,157`; `stage14.tres:14-17` vs `CampaignS14ClearTest.gd:44-47`).
R2-HIGH-3: RESOLVED — Timer 기본값 명시 + physics Timer/frame-count 대체 + deadline_frames(`auto-solver-plan.md:38`).
R2-MEDIUM-1: RESOLVED — `SkillApplier.gd` SoT + toolbar 위임(`auto-solver-plan.md:90`, `SkillToolbar.gd:304-317,325-379`).
R2-MEDIUM-2: RESOLVED — 대상 선택/적용 분리 + `_find_closest_ant` 재사용 금지(`auto-solver-plan.md:91`, `SkillToolbar.gd:412`, `CursorTargetingResolver.gd:60-71`).

## Verdict: clean

### Findings
CRITICAL: None. HIGH: None. MEDIUM: None. LOW: None.

### 결론: plan stage 통과 (3-round cap 내 clean). 구현 진입 승인.
- **부수 발견(솔버 범위 밖)**: scene_id 14 콘텐츠 불일치 — `stage14.tres`(이름 "밑으로 밑으로", 인벤토리 blocker/climber)와 `CampaignS14ClearTest`(주석 "높은 곳에서", floater 직접 적용)가 어긋남.

## Post-approval 사용자 결정 (2026-06-18) — 정답 기준 단순화 (D4)
사용자 지시: **기존 드라이버·주석·데이터의 풀이 가정을 ground truth로 쓰지 말 것. 솔버가 실제로 달성한 클리어(무수정 게임 코드의 판정)를 정답으로 삼을 것.**
- plan에 **D4** 추가. selftest를 "드라이버 동일성/리뷰-확정 기대" → **신규 손작성 메커니즘 골든 + 게임 verdict 단언**으로 교체(R2-HIGH-1 잔재 완전 제거).
- **S14 특례 폐기**: floater 주석 무시, 실제 인벤토리(blocker/climber)로 솔버가 클리어 가능 여부 판정. defer·보류 표시 제거. (scene_id 14 콘텐츠 불일치는 솔버 결과가 자연히 드러냄.)
- 순환 우려 해소 근거: 클리어/실패 verdict는 하니스가 아니라 `StageRunner._conclude_stage`/`ScoreSystem`(게임 본체)가 emit → 인-더-루프 정합성 상속.

### Round 4 (확인) — codex exec read-only (2026-06-18)
초점: D4 정답 기준이 (1) 비순환인가 (2) plan에 일관 반영됐나 (3) 거짓 클리어 경로가 새로 생기나.
**Verdict: clean** — CRITICAL/HIGH/MEDIUM/LOW 전부 None. 클리어 verdict가 무수정 게임 코드(`StageRunner._conclude_stage`/`ScoreSystem`)에서 나오므로 하니스가 보고하는 클리어는 실엔진 클리어 = 비순환 확인. driver-parity/S14 defer 잔재 모순 없음.
(운영 노트: `codex exec`를 백그라운드 Bash로 돌릴 때 stdin EOF가 안 와 멈추는 현상 → `< /dev/null` 필요. cwd는 `cd .../CandyAnts &&`로 같은 명령에 고정.)

---

# 개정 (2026-06-18) — 생성 북극성 + D5~D9 + 3층 구조

> 계획을 레벨-생성 북극성으로 개정. 문서를 3층(비전 / 확정=D1~D7+Phase 1 / 로드맵=Phase 4~6)으로 분리.
> 리뷰 범위 = **확정 층만**(focus text로 못박음). codex가 Phase 4~6/생성 feasibility는 결함으로 보지 않음(스코핑 성공).

## Round 1 (codex `/codex:adversarial-review`, working-tree)
Verdict: **needs-attention** (확정 층 내 HIGH 2건; 로드맵/비전은 무지적)

- [high] Phase 1 acceptance가 실행 가능한 verify 게이트에 없음 (frontmatter:4)
  `verify`가 Phase 0 테스트(DeterminismReplay/SpawnSchedule)만 실행. 확정 층은 Phase 1 포함이고 본문은 PlanReplayHarnessTest·`run_plan.py --selftest`·자동동기화 회귀를 요구 → Phase 1 구현이 그것들을 증명 없이 문서 게이트를 통과 가능 = "확정 층 falsifiable acceptance" 주장 약화.
  권고: verify에 Phase 1 체크 복원, 또는 `verify_phase0`/`verify_phase1` 분리로 silent bypass 차단.
- [high] D7 자동동기화가 기존 하드코딩 스킬 지식을 마이그레이션 계약 밖에 둠 (D7)
  스킬 self-describing + `SkillRegistry` generic 열거를 말하면서, 기존 하드코딩 맵(`SkillRegistry.SKILL_SCRIPTS` preload 배열, `SkillAffordance.SKILL_CATEGORY` — 신규 스킬마다 수동 1줄)은 Phase 1 계약에 미포함 → 엔진/UI-affordance/솔버 열거 간 drift 가능 = D7 불변식 미확보.
  권고: `SkillAffordance`/수동 레지스트리를 per-skill 메타에 종속, 또는 **메타 누락/열거 불일치 시 실패하는 drift 테스트** 추가.

### 처리 (plan-stage: HIGH → 수정 → Round 2)
- 사실확인: `SkillRegistry.SKILL_SCRIPTS`·`SkillAffordance.SKILL_CATEGORY` 둘 다 수동 1줄 요구(assert로 누락 검출). 지적 정당.
- HIGH-1: frontmatter에 `verify_phase1` 분리(Phase 1 게이트 = PlanReplayHarnessTest + run_plan.py --selftest + 자동동기화 drift 테스트), Phase 1 Acceptance가 이를 게이트로 명시. `verify`(현재 실행가능)는 Phase 0 유지.
- HIGH-2: D7에 기존 하드코딩 맵 명시 + 정확한 불변식("솔버-side 불변, 단일 권위 뷰서 열거; 신규 스킬 = 레지스트리 등록 + 자기-완결 메타가 affordance 카테고리 포섭; drift 테스트가 완전성 보장"). Phase 1에 **스킬 메타 drift 가드 테스트** 추가.

## Round 2 (codex `/codex:adversarial-review`, working-tree)
Verdict: **needs-attention** (HIGH 1; D7 수정 수용·미재기)

- [high] `verify_phase1`이 기존 완료 플로우에 inert (frontmatter:4-5)
  `scripts/execute.py`는 `verify`만 파싱·실행(`parse_frontmatter` L220 / `complete` L809 `fm.get("verify")`). 커스텀 키 무시 → Phase 1을 PlanReplay/Drift/selftest 증명 없이 완료 표시 가능 = R1-HIGH-1이 키 이름만 바뀐 채 잔존.
  권고: `verify`에 Phase 1 게이트 되돌림, 또는 execute.py가 `verify_phase1` 파싱·실행 + 미강제 verify류 키 거부.

### 처리 (Round 2 → 수정 → Round 3)
- 사실확인: `parse_frontmatter` `verify`만 추출(L220), `complete` `fm.get("verify")`만 실행(L809). 지적 정당(이 트랙은 execute.py 태스크도 아니라 더 inert).
- 수정: **inert `verify_phase1` 제거.** 단일 `verify` 필드를 계약으로 — "단계 완료 = `verify`를 그 단계 게이트로 갱신하고 그린"(현재 Phase 0, Phase 1 완료 시 && 편입). Acceptance·검증방법·문서구조에 일관 반영, 별도 키 금지 명시. execute.py 변경 없이 실행 계약 일치(over-engineering 회피).

## Round 3 (codex `/codex:adversarial-review`, working-tree) — 최종
Verdict: **approve** — No material findings.
inert `verify_phase1` 부재 확인, 플랜이 프론트매터 `verify`를 유일 실행 게이트로 취급, Phase 1 완료 = 그 단일 `verify`에 PlanReplayHarnessTest·SkillMetadataDriftTest·`run_plan.py --selftest` 편입으로 명시됨.

### 종결 (plan-stage 3-round cap 내 clean)
R1 needs-attention(HIGH×2) → 수정 → R2 needs-attention(HIGH×1) → 수정 → **R3 approve**. 3-round cap 준수.
**스코핑 성과**: 3층 구조 + focus text로 codex가 Phase 4~6/생성 feasibility를 결함으로 보지 않음(북극성 유지하며 확정 층만 가혹 검증) — 사용자 우려("최종 목표가 리뷰 통과 방해") 해소.
