# CandyAnts 레벨 재설계 — 작업 현황 / 다음 세션 핸드오프

작성: 2026-06-02 · 이 문서가 **남은 작업 / 진척의 1차 SoT**.

## 0. 한 줄 요약
캠페인 레벨을 처음부터 재설계 중. **스킬 정합성 "선행 정리"를 먼저** 하고 그 위에 9스테이지 캠페인을 저작하는 흐름.
**2026-06-02 세션 2 완료**: 미커밋 5+ 스레드(builder 대각·Strings 중앙화·Home retire·blocker 배지·기절) **분리 커밋**(e0f9f02~6771bb2) → **A2 기절(Stun) 구현·검증**(commit 1f2a162) → **S1 "첫 마실"을 stage01 락 슬롯에 통합 완료**(dev 초안 폴더 삭제, promotion).
**2026-06-02 세션 3**: ① **S2 "오르막" stage02 저작 — 커밋 `c8611e6`** (§3c). distributor floater 분배(사용자 결정 — rev2 §2 distributor 보류 철회, S2=3개념). 저작 중 버그 2건 수정: 기절 경계값(정확히 5칸≈239.x<240 → **6칸 교정**) + star_thresholds **내림차순→오름차순 교정**(S1·S2, S1 선재버그). ② **A1 운반자 통일 완료**(§4 A1) + **S3 "사탕 호수" stage03 저작**(§3d) — **미커밋**. 다음: **S4 "계단 공사"(builder)** → S5~S9.

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
- **보류 스킬**: `blocker`·`distributor` — 학습 스테이지 삭제로 미배치. ~~스테이지 추가 작업 시 재배치.~~ **개정(세션 3)**: `distributor`는 **S2 "오르막"에서 floater 분배 장치로 도입**(사용자 결정, §3c). `blocker`만 미배치 유지.
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

## 3c. 완료 — S2 "오르막" → stage02 락 슬롯 저작 (세션 3, 커밋 `c8611e6`)
HTML rev2 S2 시안(메사 토폴로지)대로 stage02 슬롯에 저작. 핸드오프 §5의 "옛 stage01 valley 출발점"은 **파일 구조 템플릿** 의미였고, 설계 본문("사탕 1칸↑ 등반 + 5칸 낙하")은 메사(올라갔다 내려옴)와 일치 → valley 아닌 메사로 저작.
- **테마**: 한 마리를 분배자로 정착시켜 무리 전체에 낙하산(floater)을 나눠준다. (사용자 결정: "floater 여럿 불필요 = distributor 분배")
- **기하(cell 48)**: 좌측 평지(표면 row10) + cols16~20 위 **6칸 메사**(표면 row4). Home(2,9)·Candy(18,3)·Camera(576,336)·Spawner(120,472.5) total8 + col11 `SettlementMarker`(552,496). 등반 6칸(climber)·복귀 낙하 6칸=288px(기절 임계 240 ≫). ⚠ **원래 5칸 설계였으나 경계값 결함으로 6칸 교정**(§6 gotcha).
- **메커니즘**: `distributor`+`floater`를 한 개미에 부여 → col11서 정착(`SettledState`, `set_blocker_active(false)`라 통행 방해 無) → 이후 지나가는 모든 개미에 `SettledState.TRANSFER_WHITELIST=[floater]` 전이. 배달 개미는 개별 climber만 부여하면 분배자에게서 floater를 받아 안전 강하.
- **파라미터** (`stage02.tres`): id=2 "오르막" / total_ants=8 / candy_hp=5 / 100s / available=[climber,floater,distributor] / inventory={climber:6, **floater:1**, distributor:1} / ★=**[0.5, 0.75, 1.0]**(오름차순) / release_rate=30. floater:1 = "개별 부여로는 부족 → 분배자를 만들어라"를 인벤토리로 텔레그래프.
- **테스트**: stale `Stage02HeadlessTest`(sand-bridge 무효) **폐기**(git rm) → `CampaignS2ClearTest`(분배자 floater 분배 → saved 5/5 PASS) + `CampaignS2NoFloaterTest`(climber만 → picks5/lost5/saved0, floater 식별성 + 6칸 경계 검증 PASS). 둘 다 `Stage02.tscn` instance.
- **검증(run_test.py 전부 PASS)**: S2 Clear·NoFloater / 회귀 22종(S1 Clear·NoClimber·GameFlow·StunFall·Hud×2·LayoutBuilder×2·Scoring×2·SaveData×7·SceneFlow×5).
- **배선**: SceneFlow slot2=Stage02.tscn 그대로, LAST_STAGE_ID=3 유지(S3=옛 MVP stage03). menu_layout 10슬롯·SaveData 언락 기존 유지.
- **⚠ 옛 stage02 "모래 다리"(sand_mound/builder) 내용은 덮어써짐** — git 이력(`58b0fbb` 직전 stage02.tres/layout/tscn)에서 복구 가능.

## 3d. 완료 — A1 운반자 통일 + S3 "사탕 호수" → stage03 락 슬롯 저작 (세션 3, 미커밋)
**A1 (선행 정리)**: `BridgeSkill.can_apply`를 builder처럼 **Walker/Carrying 허용** + `has_candy` 거부 제거. `WorkerState`는 has_candy 불변(주석 가드)이고 `return_to_walking()`이 has_candy면 CarryingState로 복원 → 운반 개미가 다리 놓고 운반 재개(데드락 無). `test_BridgeSkill.gd`는 빈 스텁이라 무영향. **검증**: bridge 8종(BridgeGapCross·OverWater·OverWaterStickyOverlap·RejectStageCell·FallAbort·FirstTickOffFloorAbort·GapTooLong·SandBridgeOverlap) 전부 PASS.

**S3 "사탕 호수" 저작** (HTML rev2 id:3 — bridge 평지 횡단 + water 즉사):
- **기하(cell 48)**: 좌 지면 cols0~8 + 우 지면 cols17~23 (표면 row10, body 11-13, bg 14-16). **갭 cols9~16**(8칸) 무지면 → 추락. Home(2,9)·Candy(21,9)·Camera(576,360)·Spawner(120,472.5) total6. **Water 8개**(row10, cols9~16) `(c*48+24, 504)` = (456~792, 504). Water 1개 = 1셀(48×48 shape).
- **메커니즘**: 첫 ant가 갭 직전 col8(x∈[384,432))서 bridge 적용 → `WorkerState("bridge")`가 8칸 수평 다리(cols9~16 row10) + 매 tile `deactivate_hazards_for_placement`로 그 셀 Water 비활성 → 다리 위 통행 안전. BRIDGE_MAX_LENGTH=8 = 갭 8칸 딱 맞음. 다리 영구 → 후속 ant 왕복.
- **water 저작 패턴**: `scenes/entities/hazards/Water.tscn` 인스턴스를 World 아래 셀별 배치. `HazardBase._ready`가 `await physics_frame` 후 `floor(global_position/cell_size)`로 셀 등록 → bridge가 그 셀 deactivate. layout tile_map엔 water 없음(Area2D 별물).
- **파라미터** (`stage03.tres`): id=3 "사탕 호수" / total_ants=6 / candy_hp=4 / 110s / available=[bridge] / inventory={bridge:5} / ★=[0.5,0.75,1.0](오름차순) / release_rate=30.
- **테스트**: stale `Stage03HeadlessTest`(옛 basher/blocker/alternate-spawn/cliff) **폐기**(git rm) → `CampaignS3ClearTest`(bridge→saved4/4 lost0 PASS) + `CampaignS3NoBridgeTest`(무스킬→picks0 no_more_ants, bridge 식별성 PASS). **`GameFlowTest` Scenario B 재작성**: 옛 basher@x528+blocker@x1248 클리어 → bridge@col8 클리어로 교체(테스트 핵심=마지막스테이지 Next-disabled+menu fallback 유지). PASS.
- **⚠ 폐기 부수효과**: Stage03HeadlessTest가 제공하던 **D-1(AntSpawner alternate spawn) / D-2(BlockerSkill carrying 거부) / D-3(blocker clear) 통합 커버리지 소멸**. 재설계 캠페인이 안 쓰는 기능(alternate spawn·blocker 보류)이라 deferred — blocker/alternate 재도입 시 standalone unit test 신설 권장(§4 D4).
- **⚠ 옛 stage03 "흙을 깎다"(basher) 내용 덮어써짐** — git 이력에서 복구 가능.

## 4. 남은 작업 (권장 순서)

### A. 선행 정리 — 코드/에셋 (캠페인 저작 전 필수)
- [x] **A1. builder/bridge 운반자 허용 통일** — **완료(세션 3, 미커밋)**. `BridgeSkill.can_apply` Walker/Carrying 허용 + has_candy 거부 제거. 상세 §3d. bridge 8종 회귀 PASS.
- [x] **A2. 기절(Stun) 메커니즘** — **완료(commit 1f2a162)**. `FallerState.enter()` 낙하 시작 y 기록 → 착지 시 `(착지y−시작y) >= 5×cell_size` & floater 미보유 → `DeadState`(신설 대신 **DeadState 재활용**). DeadState가 stun 애니 ~1초 재생 후 queue_free + 운반 시 candy_piece_lost(LostState 동일 회계). `Ant._cell_size`는 `_resolve_kill_bounds`에서 캐시, `stun_fall_threshold()`. `ant_stun` sfx id(P21 대기). floater 높이 무관 무효. 검증: `tests/StunFallTest`(5칸→기절+lost / 4칸→생존 / floater→생존 PASS).
- [x] **A3. 기절 스프라이트** — **완료(commit 1f2a162)**. `assets/sprites/characters/ant_pajama_girl/stun/`(PNG4) + AntFrames `stun` 애니(loop, speed6).
- [ ] **A4. (아트) stair 스프라이트 검토**: `cookie_stair_tile.png`가 대각 상승으로 잘 읽히는지. 충돌/로직은 정상.

### B. 에디터 / 데이터 (map-editor 트랙)
- [ ] **B1. 파괴 종류 브러시**: 레이아웃에 `earth`(digger·basher)/`plant`(cutter) 태그 저작. 현재 에디터는 solid/slope만.
- [ ] **B2. 해저드 배치 모드**: water(즉사)/sticky(감속) 셀.
- [ ] **B3. 흙 vs 쿠키(불괴) 시각 구분 확인**.

### C. 캠페인 저작
- [~] **C1. 9개 `stageNN.tres` + `stageNN_layout.tres`** 저작 (HTML 시안 기반), 스테이지별 플레이테스트로 인벤토리·시간·기하 튜닝. 특히 S3/S7/S10류 **복귀 경로**(왕복 제약) 정밀화. — **S1 stage01**(§3b), **S2 "오르막" stage02**(§3c), **S3 "사탕 호수" stage03**(§3d) 완료. **S4~S9 미착수**.
- [~] **C2. 진행 흐름 등록**: menu_layout 10슬롯·SaveData 언락(N-1 클리어)·"/30" denominator는 **이미 확보**. SceneFlow.STAGE_SCENES[1~3]·LAST_STAGE_ID=3 — 현재 캠페인 3스테이지(S1~S3) 완결 데모. **S4 저작 시 STAGE_SCENES[4] 추가 + LAST_STAGE_ID=4** 갱신 필요.
- [ ] **C3. blocker·distributor 재배치** + 무스킬 0번 온보딩 결정.

### D. 하우스키핑
- [x] **D1. builder 변경 커밋** — 완료(commit e0f9f02). 세션 2에서 builder/Strings/Home/Ant(blocker+stun)/S1+docs/theme 6커밋으로 분리.
- [x] **D2. stale 통합테스트 정리**: `Stage02HeadlessTest`(sand-bridge) + `Stage03HeadlessTest`(basher/blocker/cliff) **둘 다 폐기**(세션 3, git rm) — S2·S3 재저작으로 무효화. 대체: `CampaignS2/S3 Clear+Negative` 테스트.
- [ ] **D3. FloaterTraitTest 기존 실패 조사**: dev_stages/trait 스테이지에서 floater-only 개미가 낙하 미도달 → deadline. 기절 변경 무관(FallerState revert해도 실패 확인). 별도 조사 필요.
- [ ] **D4. (세션 3 신설) blocker/alternate-spawn 커버리지 보강**: `Stage03HeadlessTest` 폐기로 **D-1(AntSpawner spawn_direction_alternate) / D-2(BlockerSkill carrying 거부) / D-3(blocker clear) 통합 커버리지 소멸**. 둘 다 재설계 캠페인 미사용(blocker 보류·alternate 미사용)이라 defer. blocker/alternate 재도입 시 standalone unit test 신설.

## 5. 다음 세션 즉시 행동 (제안)
1. `python scripts/execute.py mvp validate` 1회(세션 시작 루틴) + `git log --oneline -8`로 baseline 확인. **세션 3: S2 커밋 `c8611e6`, 그 위에 A1+S3 미커밋 워킹트리**(커밋 시 §3d 변경 묶음). climb 애니 2→8프레임 아트는 별도 트랙(섞지 말 것).
2. **S4 "계단 공사" 저작** (builder 대각 상승). HTML rev2 id:4 grid: 좌 지면 + 우측 높은 단 + 그 앞 빈틈 → builder로 대각 계단 쌓아 등반(계단 양방향 보행 → 귀가 동일). stage04 슬롯 **신규**(현 stage04~ 슬롯 존재 확인 — 없으면 scenes/stages/Stage04.tscn + data 신규 + **SceneFlow.STAGE_SCENES[4] 추가 + LAST_STAGE_ID=4**). §3d 마이그레이션 패턴 답습. builder는 이미 대각화 완료(§3 commit e0f9f02). A1로 운반자도 builder 가능.
3. **S5~S9** 순차 (S5 사다리 / S6 digger / S7 basher / S8 cutter / S9 종합). S6+ 파괴계는 layout에 earth/plant 태그(B1) + water/sticky 해저드(B2) 저작 필요.
4. (선택) **기절 5칸 경계 결함 근본수정 여부 결정**(§6 gotcha) — 현재는 스테이지를 6칸으로 우회. 디자인 "5칸=기절" 의미를 살리려면 FallerState/WalkerState 측정 수정(코어 변경, 별도 테스트·리뷰).

## 6. Gotchas (다음 세션 주의)
- **⚠ 기절 5칸 경계 결함 (세션 3 발견)**: 기절 임계는 `fall_dist >= 5×cell_size`(=240px)인데, **기하학적 정확히 5칸 낙하는 기절을 발동 못 함**. 원인: `WalkerState.update`가 매 프레임 `velocity.y += gravity*delta` + `move_and_slide` 적용 → 개미가 ledge 이탈 후 같은 프레임에 off-floor가 되어 즉시 Faller 전이하는데, `FallerState.enter()`가 기록하는 `_fall_start_y`가 이미 중력 1프레임만큼 내려간 값 → 측정 fall_dist ≈ 239.x < 240 → 미발동. **실증**: 정확히 5칸 메사에서 floater 없는 개미 전원 생존(CampaignS2NoFloaterTest가 saved=5로 FAIL). **6칸(288px)으로 올리니 전원 기절(lost=5)**. → **레벨 저작 규칙: 기절을 의도한 낙하는 ≥6칸으로**. 디자인 "5칸=기절"을 살리려면 측정 로직 근본수정 필요(§5.4, 코어 변경이라 별도 작업).
- **⚠ star_thresholds는 오름차순 (세션 3 발견)**: 엔진 컨벤션은 `Scoring.STAR_THRESHOLDS=[0.50,0.80,0.95]` **오름차순**(`[1★최소비율, 2★, 3★]`, `compute_stars`는 `ratio>=threshold` 누적). HTML 시안 표기 `[1.0, 0.8, 0.6]`는 내림차순이라 **그대로 베끼면 `SaveData._is_clear_input_valid`가 거부**("malformed input" 경고 → 별점 미저장·attempts만 +1). **올바른 형식**: 3★=100/2★=80/1★=60이면 `[0.6, 0.8, 1.0]`. S1·S2 둘 다 내림차순 오저작이던 것을 세션 3에서 오름차순 교정(S1은 선재 버그).
- **검증은 `python scripts/run_test.py tests/Xxx.tscn`**(풀 프로젝트, autoload 활성). `godot --check-only --script`는 **autoload(EventBus) 부재로 의존 스크립트가 줄줄이 거짓 실패** → 단독 컴파일 체크 용도로 쓰지 말 것.
- Godot bin: `D:\Godot_v4.6.2-stable_win64_console.exe` (run_test.py가 자동 탐색).
- **water 해저드 저작(S3 이후)**: layout tile_map엔 water 없음 — `scenes/entities/hazards/Water.tscn`(Area2D, layer8/mask4, 48×48)를 **씬 World 아래 셀별 인스턴스**. `HazardBase._ready`가 `await physics_frame` 후 `floor(global_position/cell_size)`로 셀 등록. **표면행(예 row10) 1행이면 충분**(추락 개미 즉사 catch, dev 컨벤션). bridge tile이 `deactivate_hazards_for_placement(cell)`로 그 셀 water 끔 → 다리 위 안전. bridge 적용은 **갭 직전 마지막 지면 cell**(body_cell+(dir,+1)이 갭 첫 셀이어야 add_tile 성공)에서.
- `docs/LEVEL_DESIGN_PLAN.html`은 **gitignore(*.html)** — 커밋해도 안 올라감. 로컬 보존.
- **stage 슬롯 마이그레이션 패턴**(S2~S9 답습): ① `stageNN_layout.tres` 내용 이식(헤더 uid 유지) ② `stageNN.tres` 파라미터 ③ `StageNN.tscn` 엔티티 좌표(Home/Candy/Camera/Spawner)+hp+total ④ 지오메트리 하드코딩 테스트(GameFlowTest climber 좌표 등) 갱신 ⑤ 회귀(Hud/LayoutBuilder/GameFlow/SceneFlow). 경로 락이라 **파일명 유지·내용만 교체**.
- **세션 2 종료**: 8 커밋(`e0f9f02`~`58b0fbb`), HEAD=`58b0fbb`, 워킹트리 clean, 미push(로컬).
- **세션 3 진행**: ① S2 stage02 저작 + 버그2 → **커밋 `c8611e6`**. ② 그 위 **미커밋 워킹트리** = A1(BridgeSkill) + S3 stage03 저작(stage03.tres/layout/Stage03.tscn + Water8) + 신규 테스트(CampaignS3Clear/NoBridge) + stale 폐기(Stage03HeadlessTest 3파일) + GameFlowTest Scenario B bridge 재작성 + 본 문서. 커밋 시 `feat(level): S3 "사탕 호수" stage03 저작 + A1 운반자 통일` 권장. **climb 애니 2→8프레임 아트(AntFrames/climb_*.png/svg)는 병렬 트랙 — S3 커밋에 섞지 말 것**.
