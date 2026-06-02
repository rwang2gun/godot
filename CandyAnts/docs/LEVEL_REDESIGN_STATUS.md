# CandyAnts 레벨 재설계 — 작업 현황 / 다음 세션 핸드오프

작성: 2026-06-02 · 이 문서가 **남은 작업 / 진척의 1차 SoT**.

## 0. 한 줄 요약
캠페인 레벨을 처음부터 재설계 중. **스킬 정합성 "선행 정리"를 먼저** 하고 그 위에 9스테이지 캠페인을 저작하는 흐름.
**2026-06-02 세션 2 완료**: 미커밋 5+ 스레드(builder 대각·Strings 중앙화·Home retire·blocker 배지·기절) **분리 커밋**(e0f9f02~6771bb2) → **A2 기절(Stun) 구현·검증**(commit 1f2a162) → **S1 "첫 마실"을 stage01 락 슬롯에 통합 완료**(dev 초안 폴더 삭제, promotion). 다음: **S2~S9 저작** + **A1 운반자 통일**.

## 1. 관련 문서
- **설계 시안**: `docs/LEVEL_DESIGN_PLAN.html` (rev2, 9스테이지, 그리드 시안 포함).
  - ⚠ `.gitignore`의 `*.html`에 걸려 **git 비추적 — 로컬 디스크에만 존재**. 브라우저로 열어 확인(`start docs\LEVEL_DESIGN_PLAN.html`).
  - 필요 시 추적하려면 `!docs/LEVEL_DESIGN_PLAN.html` 예외 추가 or md로 변환.
- 본 문서 `docs/LEVEL_REDESIGN_STATUS.md` (추적됨) — 진척/TODO SoT.

## 2. 확정 결정 (rev2)
- **9스테이지** (12에서 축소): 폭신착지·교차로·민들레 **삭제**.
- 곡선: **트레잇 기초(S1·S2) → 건설 3종(S3 bridge평지 / S4 builder대각 / S5 사다리수직) → 파괴 3종(S6 digger / S7 basher / S8 cutter) → 종합(S9)**.
- **S1 첫마실**: 중앙 1칸 분지 + 짧은 경로 → climber를 최소 동작으로 학습.
- **S2 오르막**: 사탕 1칸↑ → climber 등반 + **5칸 낙하 → floater** 동시 학습.
- **기절(Stun) 규칙**: 5칸+ 자유낙하 → `lost`. floater = **기절 완전 무효**. (스펙 §4-A2)
- **builder = 대각 상승**(완료), **bridge = 평지 유지**.
- **보류 스킬**: `blocker`·`distributor` — 학습 스테이지 삭제로 미배치. 스테이지 추가 작업 시 재배치.
- **무스킬 0번 온보딩**: S1이 바로 climber 요구 → 맨 앞 무스킬 스테이지 삽입 여부 추후 검토.

## 3. 완료 — builder 대각선화 (커밋 e0f9f02)
**변경:**
- `scripts/ant/states/WorkerState.gd` — `_place_one_tile`: 평지 → 대각 상승(`target=body+(dir,0)`, 이동 `+=(dir·cs, −cs)`, `dest_body=body+(dir,-1)` 점유 시 중단).
- `scripts/world/PlacementPreview.gd` — builder/bridge 분리, builder 대각 미리보기 + `_first_target_cell` 분기.
- 신규: `tests/BuilderDiagonalTest.{gd,tscn}`, `dev_stages/builder_diagonal/{BuilderDiagonalStage.tscn, builder_diagonal_test.tres, dev_builder_diagonal_layout.tres}`.

**검증 (`python scripts/run_test.py …`):**
- `tests/BuilderDiagonalTest.tscn` → PASS (`rise=128.0`=4칸, `tiles=4`). 평지였다면 rise≈0이라 식별력 확보.
- 회귀: `BridgeGapCrossTest` PASS(평지 무영향), `SandMoundClimbTest` PASS(공유파일 무영향).
- `Stage01.tscn` 헤드리스 부팅 → PlacementPreview 컴파일 에러 0.

## 3b. 완료 — S1 "첫 마실" → stage01 락 슬롯 통합 (promotion 완결, 세션 2)
사용자 결정("락 슬롯 덮어쓰기+확장")에 따라 dev 초안을 **stage01 락 슬롯에 내용 이식**(파일 경로 유지). dev 초안 폴더 `dev_stages/campaign_s1_first_outing/`는 **삭제**(중복 제거, git 이력 보존).
- **이식 위치**: `data/stages/stage01.tres`(id=1, "첫 마실") + `data/stage_layouts/stage01_layout.tres`(S1 지형, 헤더 uid 유지) + `scenes/stages/Stage01.tscn`(Home(120,480)/Candy(888,480) hp5/Camera(576,300)/Spawner(120,472.5) total8 + PlacementPreview 유지). SceneFlow.STAGE_SCENES[1]·menu_layout slot1 기존 유지.
- **테스트 repoint**: `tests/CampaignS1{Clear,NoClimber}Test.tscn` → `scenes/stages/Stage01.tscn` instance. `GameFlowTest` 시나리오 A climber 좌표를 옛 U핏(y>900,x900~1040) → 새 분지(y490~560,x336~528)로 갱신.
- **검증(run_test.py, 전부 PASS)**: CampaignS1ClearTest(saved5/5) · NoClimberTest(time_out) · CarryFallStateTest(분지 carry+fall) · HudInitialCandyHp(=5) · test_StageLayoutBuilder · GameFlowTest · SceneFlow 2종 · PadRestart · Cursor · Esc 2종 · PauseMenu.
- **기하(cell_size=48)**: 좌 lip(row10 col0~6) → 분지(row10 col7~10 빈칸, 바닥 row11) → 우 lip(row10 col11~23). home=(2,9), candy=(18,9). 분지 진입=1칸 낙하(안전), 탈출=1칸 벽 등반(climber 필수). 양방향이라 왕복도 같은 climber로 자기완결.
- **파라미터**: total_ants=8 / candy_hp=5 / 90s / available=climber+blocker / inventory=climber×8 + blocker×1 / star=[1.0, 0.8, 0.6] / release_rate=30. (2026-06-02 조정: climber 6→8=마리수, blocker×1 추가. blocker는 빈손 개미 가장자리 이탈 방지용 *도구* — 클리어는 조각 기반 `hp0+in_transit0` 유지, 손실-강제 규칙은 미도입(사용자 "도구만 제공" 결정).)
- **⚠ 옛 stage01 "오르막" 내용은 덮어써짐** — git 이력(`6771bb2` 직전 stage01.tres/layout)에서 복구 가능. rev2 §2의 **S2 "오르막"**(사탕 1칸↑ climber + 5칸 낙하 floater)은 옛 stage01을 출발점으로 재저작 권장.
- **남은 통합 작업**: S2~S9를 같은 방식(stage02~09 슬롯 덮어쓰기/확장)으로. menu_layout는 이미 10슬롯(1~3 available, 4~10 "준비 중") + "/30" denominator 확보. SceneFlow.LAST_STAGE_ID(현 3)는 슬롯 확장 시 갱신.

## 4. 남은 작업 (권장 순서)

### A. 선행 정리 — 코드/에셋 (캠페인 저작 전 필수)
- [ ] **A1. builder/bridge 운반자 허용 통일**: `BridgeSkill.can_apply`가 현재 `has_candy` 거부 + Walker만 → builder처럼 **Walker/Carrying 허용**으로 변경(작업 후 Walker 복귀라 데드락 無). 파괴·정지·하강계는 현행 거부 유지.
- [x] **A2. 기절(Stun) 메커니즘** — **완료(commit 1f2a162)**. `FallerState.enter()` 낙하 시작 y 기록 → 착지 시 `(착지y−시작y) >= 5×cell_size` & floater 미보유 → `DeadState`(신설 대신 **DeadState 재활용**). DeadState가 stun 애니 ~1초 재생 후 queue_free + 운반 시 candy_piece_lost(LostState 동일 회계). `Ant._cell_size`는 `_resolve_kill_bounds`에서 캐시, `stun_fall_threshold()`. `ant_stun` sfx id(P21 대기). floater 높이 무관 무효. 검증: `tests/StunFallTest`(5칸→기절+lost / 4칸→생존 / floater→생존 PASS).
- [x] **A3. 기절 스프라이트** — **완료(commit 1f2a162)**. `assets/sprites/characters/ant_pajama_girl/stun/`(PNG4) + AntFrames `stun` 애니(loop, speed6).
- [ ] **A4. (아트) stair 스프라이트 검토**: `cookie_stair_tile.png`가 대각 상승으로 잘 읽히는지. 충돌/로직은 정상.

### B. 에디터 / 데이터 (map-editor 트랙)
- [ ] **B1. 파괴 종류 브러시**: 레이아웃에 `earth`(digger·basher)/`plant`(cutter) 태그 저작. 현재 에디터는 solid/slope만.
- [ ] **B2. 해저드 배치 모드**: water(즉사)/sticky(감속) 셀.
- [ ] **B3. 흙 vs 쿠키(불괴) 시각 구분 확인**.

### C. 캠페인 저작
- [~] **C1. 9개 `stageNN.tres` + `stageNN_layout.tres`** 저작 (HTML 시안 기반), 스테이지별 플레이테스트로 인벤토리·시간·기하 튜닝. 특히 S3/S7/S10류 **복귀 경로**(왕복 제약) 정밀화. — **S1 "첫 마실" = stage01 슬롯 통합 완료**(§3b), **S2~S9 미착수**.
- [~] **C2. 진행 흐름 등록**: menu_layout 10슬롯·SaveData 언락(N-1 클리어)·"/30" denominator는 **이미 확보**. 슬롯 확장 시 SceneFlow.LAST_STAGE_ID·available 플래그만 갱신.
- [ ] **C3. blocker·distributor 재배치** + 무스킬 0번 온보딩 결정.

### D. 하우스키핑
- [x] **D1. builder 변경 커밋** — 완료(commit e0f9f02). 세션 2에서 builder/Strings/Home/Ant(blocker+stun)/S1+docs/theme 6커밋으로 분리.
- [ ] **D2. stale 통합테스트 정리**: `Stage02HeadlessTest`(+stage03?)가 16px 시절 좌표라 48px 3-tier 후 red. trigger 좌표 갱신 or 폐기. (builder 변경과 무관한 기존 문제)
- [ ] **D3. FloaterTraitTest 기존 실패 조사**: dev_stages/trait 스테이지에서 floater-only 개미가 낙하 미도달 → deadline. 기절 변경 무관(FallerState revert해도 실패 확인). 별도 조사 필요.

## 5. 다음 세션 즉시 행동 (제안)
1. `python scripts/execute.py mvp validate` 1회(세션 시작 루틴) + `git log --oneline -8`로 baseline 확인(**HEAD = `227d146`**, 워킹트리 clean).
2. **S2 "오르막" 저작** (다음 슬라이스 — A1 불필요, climber+floater만): 옛 stage01(git `227d146` 직전 = `6771bb2`의 stage01.tres/stage01_layout.tres)을 출발점으로 **stage02 슬롯**에 이식. 사탕 1칸↑ climber 등반 + **5칸 낙하→floater** 학습 → **이번 세션 기절(Stun) 메커니즘 연동 시연**. 절차는 §3b S1 사례 + §6 마이그레이션 패턴 답습. 같은 작업에서 `Stage02HeadlessTest`(D2 stale red)도 새 좌표로 정리.
3. **A1(운반자 통일)** — S3(bridge)·S4(builder) 저작 *전* 필요(S2엔 불필요). builder/bridge `can_apply`를 Walker/Carrying 허용으로.

## 6. Gotchas (다음 세션 주의)
- **검증은 `python scripts/run_test.py tests/Xxx.tscn`**(풀 프로젝트, autoload 활성). `godot --check-only --script`는 **autoload(EventBus) 부재로 의존 스크립트가 줄줄이 거짓 실패** → 단독 컴파일 체크 용도로 쓰지 말 것.
- Godot bin: `D:\Godot_v4.6.2-stable_win64_console.exe` (run_test.py가 자동 탐색).
- **stage02 통합테스트 red는 기존 stale** — builder 변경이 깬 게 아님.
- `docs/LEVEL_DESIGN_PLAN.html`은 **gitignore(*.html)** — 커밋해도 안 올라감. 로컬 보존.
- **stage 슬롯 마이그레이션 패턴**(S2~S9 답습): ① `stageNN_layout.tres` 내용 이식(헤더 uid 유지) ② `stageNN.tres` 파라미터 ③ `StageNN.tscn` 엔티티 좌표(Home/Candy/Camera/Spawner)+hp+total ④ 지오메트리 하드코딩 테스트(GameFlowTest climber 좌표 등) 갱신 ⑤ 회귀(Hud/LayoutBuilder/GameFlow/SceneFlow). 경로 락이라 **파일명 유지·내용만 교체**.
- **세션 2 종료 시점: 7 커밋 완료 (`e0f9f02`~`227d146`), 워킹트리 clean**. HEAD=`227d146`(S1 통합). 미push(로컬). 다음 세션은 여기서 직진.
